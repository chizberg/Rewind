//
//  MapModelTests.swift
//  RewindTests
//
//  Scenario tests for the MapModel reducer: each test walks a realistic multi-step flow
//  (region changes, loads landing or hanging, location fixes, annotation selection, controls)
//  and checks state and map side effects after every step. Uses a fake RewindMap (no live
//  MKMapView) and a controllable annotations remote that can suspend a load until released.
//

import CoreLocation
import MapKit
@testable import Rewind
import Testing
import VGSL

@MainActor
struct MapModelTests {
  /// A burst of region changes inside the debounce window triggers exactly one load.
  @Test func regionChangeBurstCollapsesToOneLoad() async {
    let env = TestEnv()
    let model = env.makeModel()

    for i in 0..<5 {
      model(.external(.map(.regionChanged(env.region(latOffset: Double(i) * 0.01)))))
    }
    #expect(await eventually { env.remote.loadCount == 1 })
    await sleep(.milliseconds(250)) // ≥2× the 100ms debounce: confirm no extra load fires
    #expect(env.remote.loadCount == 1)
  }

  /// A second region change cancels the in-flight load (shared id `load_annotations`); only the
  /// second result lands, and the cancelled first raises no alert.
  @Test func secondRegionChangeCancelsFirstLoad() async {
    let env = TestEnv()
    env.remote.hangFirstCall = true
    let model = env.makeModel()

    model(.external(.map(.regionChanged(env.region(latOffset: 0)))))
    #expect(await eventually { env.remote.loadCount == 1 }) // first load started, hanging

    model(.external(.map(.regionChanged(env.region(latOffset: 5)))))
    #expect(await eventually { env.remote.loadCount == 2 }) // second load cancels the first

    #expect(await eventually { model.state.lastLoadedParams != nil })
    // The landed params are the second load's, never the (cancelled) first's.
    #expect(model.state.lastLoadedParams?.coordinates == env.remote.receivedParams[1].coordinates)
    #expect(model.state.lastLoadedParams?.coordinates != env.remote.receivedParams[0].coordinates)
    #expect(!env.presentedNonNilAlert) // cancellation is silent
  }

  /// Map loads at zoom 10 and previews assemble; zooming in keeps the old annotations and
  /// previews until the (suspended) response arrives, then replaces them wholesale; panning
  /// at the same zoom removes nothing and appends the new images.
  @Test func zoomChangeReplacesAnnotationsPanKeepsThem() async {
    let env = TestEnv()
    let model = env.makeModel()
    model(.external(.ui(.mapViewLoaded)))

    // 12 images in distinct cells (below the local-cluster threshold) + a server cluster
    let imagesA = (0..<12).map { img($0 + 1, cell: $0, 0, zoom: 10, year: 1900 + $0) }
    env.remote.response = (imagesA, [serverCluster(41)])
    model(.external(.map(.regionChanged(region(zoom: 10)))))
    #expect(await eventually { env.map.imageValues == Set(imagesA) })
    #expect(env.map.clusterValues == [serverCluster(41)])
    #expect(model.state.lastLoadedParams?.zoom == 10)

    // previews: the 10 newest by date + the view-as-list tail card; region images also
    // include the server cluster's preview (mock year 1894 → sorts last)
    #expect(await eventually { model.state.previews.count == 11 })
    #expect(model.state.previews.last == .viewAsList)
    #expect(model.state.previews.first?.image?.cid == 12)
    #expect(model.state.currentRegionImages ==
      (imagesA + [serverCluster(41).preview]).sorted(by: .dateDescending))

    // zoom in; while the response hangs, annotations and previews stay intact
    let imagesB = (0..<3).map { img($0 + 100, cell: $0, 0, zoom: 12, year: 2000 + $0) }
    env.remote.gateNextCall = true
    env.remote.response = (imagesB, [serverCluster(42)])
    model(.external(.map(.regionChanged(region(zoom: 12)))))
    #expect(await eventually { env.remote.loadCount == 2 })
    #expect(model.state.isLoading)
    await sleep(.milliseconds(250)) // past the updatePreviews debounce: isLoading must gate it
    #expect(env.map.imageValues == Set(imagesA))
    #expect(model.state.previews.count == 11)

    // the response lands: a zoom change replaces annotations wholesale
    env.remote.openGate()
    #expect(await eventually { env.map.imageValues == Set(imagesB) })
    #expect(env.map.clusterValues == [serverCluster(42)])
    #expect(await eventually {
      model.state.previews == (imagesB + [serverCluster(42).preview])
        .sorted(by: .dateDescending).map { .image($0) }
    })

    // pan at the same zoom: nothing is removed, new images append
    let imagesC = (0..<2).map { img($0 + 200, cell: $0 + 10, 5, zoom: 12, year: 2010 + $0) }
    env.remote.response = (imagesC, [])
    model(.external(.map(.regionChanged(
      region(zoom: 12, center: Coordinate(latitude: 1, longitude: 1)),
    ))))
    #expect(await eventually { env.map.imageValues == Set(imagesB + imagesC) })
    #expect(env.map.clusterValues == [serverCluster(42)])
    #expect(model.state.lastLoadedParams?.zoom == 12)
  }

  /// A server cluster whose preview shares its cid with a loose visible image contributes no
  /// second card: region images and previews dedupe by cid across annotation kinds.
  @Test func clusterPreviewSharingCidWithImageDedupes() async {
    let env = TestEnv()
    let model = env.makeModel()

    // 3 loose images; the server cluster's preview duplicates cid 2
    let images = (1...3).map { img($0, cell: $0, 0, zoom: 10, year: 1900 + $0) }
    env.remote.response = (images, [serverCluster(2)])
    model(.external(.map(.regionChanged(region(zoom: 10)))))

    #expect(await eventually { !model.state.previews.isEmpty })
    // 4 model values arrive (3 images + the cluster preview), 3 unique cids remain
    #expect(Set(model.state.currentRegionImages.map(\.cid)) == [1, 2, 3])
    #expect(model.state.previews.count == 3)
  }

  /// An empty reload (here: after a filter change clears the map) replaces stale preview cards
  /// with the single "no images" card rather than leaving the old strip or an empty one.
  @Test func emptyLoadShowsNoImagesCard() async {
    let env = TestEnv()
    let model = env.makeModel()

    env.remote.response = ([img(1, cell: 0, 0, zoom: 10, year: 1900)], [])
    model(.external(.map(.regionChanged(region(zoom: 10)))))
    #expect(await eventually { model.state.previews.map(\.image?.cid) == [1] })

    env.remote.response = ([], [])
    model(.external(.ui(.filtersChanged(ImageRequestFilters(imageKind: .painting)))))
    #expect(await eventually { model.state.previews == [.noImages] })
    #expect(model.state.currentRegionImages.isEmpty)
  }

  /// The first location fix recenters the map exactly once (zoom 15, not animated); later fixes
  /// only update state, and a nil-location update does not erase the known location.
  @Test func firstLocationRecentersMapOnce() async throws {
    let env = TestEnv()
    let model = env.makeModel()
    model(.external(.ui(.mapViewLoaded)))

    let first = CLLocation(latitude: 55.75, longitude: 37.61)
    model(.external(.newLocationState(
      LocationState(location: first, errorMessage: nil, isAccessGranted: true),
    )))
    let call = try #require(env.map.setRegionCalls.first)
    #expect(env.map.setRegionCalls.count == 1)
    #expect(call.region.center == first.coordinate)
    #expect(zoom(region: call.region, mapSize: env.map.size) == 15)
    #expect(!call.animated)

    // the map reacts with a region change → annotations load for the new region
    env.remote.response = ([img(1, cell: 0, 0, zoom: 15, year: 1900)], [])
    model(.external(.map(.regionChanged(call.region))))
    #expect(await eventually { model.state.lastLoadedParams?.zoom == 15 })

    // a second fix updates state but leaves the map alone
    let second = CLLocation(latitude: 59.94, longitude: 30.31)
    model(.external(.newLocationState(
      LocationState(location: second, errorMessage: nil, isAccessGranted: true),
    )))
    #expect(env.map.setRegionCalls.count == 1)
    #expect(model.state.locationState.location?.coordinate == second.coordinate)

    // a nil-location update keeps the last known location
    model(.external(.newLocationState(
      LocationState(location: nil, errorMessage: nil, isAccessGranted: true),
    )))
    #expect(model.state.locationState.location?.coordinate == second.coordinate)
  }

  /// A filter change resets a narrowed year range immediately, clears the map before the reload
  /// response arrives, and the new load lands with the new filters applied.
  @Test func filterChangeResetsYearRangeClearsAndReloads() async {
    let env = TestEnv()
    let model = env.makeModel()
    model(.external(.ui(.mapViewLoaded)))

    // cid 1 passes both the old and the new filters — it must survive the clear + reload
    let survivor = img(1, cell: 1, 0, zoom: 10, year: 1901)
    env.remote.response = (
      [survivor] + (2...3).map { img($0, cell: $0, 0, zoom: 10, year: 1900 + $0) },
      [serverCluster(41)],
    )
    model(.external(.map(.regionChanged(region(zoom: 10)))))
    #expect(await eventually { !env.map.visibleAnnotations.isEmpty })

    // switching imageKind discards the narrowed year range immediately
    let painting = modified(ImageRequestFilters(imageKind: .painting)) {
      $0.yearRange = 1900...1950
    }
    let newImages = [survivor, img(10, cell: 0, 0, zoom: 10, year: 1920)]
    env.remote.gateNextCall = true
    env.remote.response = (newImages, [])
    model(.external(.ui(.filtersChanged(painting))))
    #expect(model.state.filters.imageKind == .painting)
    #expect(model.state.filters.yearRange == ImageRequestFilters.ImageKind.painting.maxRange)

    // the debounced follow-up clears the map before the reload response arrives
    #expect(await eventually { env.remote.loadCount == 2 })
    #expect(await eventually { env.map.visibleAnnotations.isEmpty })
    #expect(model.state.isLoading)

    env.remote.openGate()
    #expect(await eventually { env.map.imageValues == Set(newImages) })
    #expect(env.map.clusterValues.isEmpty)
    #expect(model.state.lastLoadedParams?.filters.imageKind == .painting)
  }

  /// A drag near the bottom edge minimizes the controls and they unfold back after the 2s
  /// debounce; once minimized by the user, a drag must not re-arm the auto-unfold.
  @Test func dragMinimizesControlsAndAutoUnfoldsUnlessUserMinimized() async {
    let env = TestEnv()
    let model = env.makeModel()
    #expect(model.state.controls.minimization == .normal)

    let frame = CGRect(origin: .zero, size: env.map.size)
    let bottomTouch = CGPoint(x: 100, y: frame.height - mapControlsTouchBlockingHeight + 1)
    model(.external(.map(.userDragged(bottomTouch, frame))))
    #expect(model.state.controls.minimization == .minimized(byUser: false))

    #expect(await eventually(timeout: .seconds(4)) {
      model.state.controls.minimization == .normal
    })

    model(.external(.ui(.controls(.setMinimization(.minimized(byUser: true))))))
    model(.external(.map(.userDragged(bottomTouch, frame))))
    await sleep(.seconds(2.3)) // past the unfold debounce: nothing should fire
    #expect(model.state.controls.minimization == .minimized(byUser: true))
  }

  /// Selection routing: image → details, server cluster → zoom-in (or preview details when
  /// cluster previews are enabled), local cluster and MapKit-merged cluster → image list,
  /// closing the preview → deselection on the map.
  @Test func annotationSelectionRoutesByType() async throws {
    let env = TestEnv()
    let model = env.makeModel()

    let single = img(1, cell: 10, 10, zoom: 10, year: 1901)
    let clustered = (2...6).map { img($0, cell: 0, 0, zoom: 10, year: 1900 + $0) }
    env.remote.response = ([single] + clustered, [serverCluster(42)])
    model(.external(.map(.regionChanged(region(zoom: 10)))))
    // one individual image + a server cluster + five same-cell images merged into a local cluster
    #expect(await eventually { env.map.visibleAnnotations.count == 3 })

    let imageAnn = try #require(env.map.firstAnnotation(of: Model.Image.self))
    model(.external(.map(.annotationSelected(imageAnn))))
    #expect(env.lastPresentedImage == single)

    // server cluster with previews disabled → zoom towards the cluster
    let clusterAnn = try #require(env.map.firstAnnotation(of: Model.Cluster.self))
    model(.external(.map(.annotationSelected(clusterAnn))))
    let call = try #require(env.map.setRegionCalls.last)
    #expect(call.region.center == serverCluster(42).coordinate)
    #expect(zoom(region: call.region, mapSize: env.map.size) == 11) // current zoom 10, one step in
    #expect(call.animated)

    // server cluster with previews enabled → details of the cluster preview
    env.settings.openClusterPreviews = true
    model(.external(.map(.annotationSelected(clusterAnn))))
    #expect(env.lastPresentedImage?.cid == 42)

    let localAnn = try #require(env.map.firstAnnotation(of: Model.LocalCluster.self))
    model(.external(.map(.annotationSelected(localAnn))))
    #expect(Set(env.lastPresentedList ?? []) == Set(clustered))

    let mkCluster = MKClusterAnnotation(memberAnnotations: [imageAnn])
    model(.external(.map(.annotationSelected(mkCluster))))
    #expect(env.lastPresentedList == [single])

    model(.external(.previewClosed))
    #expect(env.map.deselectCount == 1)
  }

  /// focusOn (e.g. "show on map" from image details) recenters at the requested zoom, and the
  /// follow-up region change reloads, replacing old annotations since the zoom changed.
  @Test func focusOnRecentersAndReloads() async throws {
    let env = TestEnv()
    let model = env.makeModel()

    let old = [img(1, cell: 0, 0, zoom: 10, year: 1900)]
    env.remote.response = (old, [])
    model(.external(.map(.regionChanged(region(zoom: 10)))))
    #expect(await eventually { env.map.imageValues == Set(old) })

    let target = Coordinate(latitude: 48.85, longitude: 2.35)
    model(.external(.focusOn(target, zoom: 17)))
    let call = try #require(env.map.setRegionCalls.last)
    #expect(call.region.center == target)
    #expect(zoom(region: call.region, mapSize: env.map.size) == 17)
    #expect(call.animated)

    // the map answers with a region change → reload at the new zoom replaces annotations
    let new = [img(2, cell: 0, 0, zoom: 17, year: 1900)]
    env.remote.response = (new, [])
    model(.external(.map(.regionChanged(call.region))))
    #expect(await eventually { env.map.imageValues == Set(new) })
    #expect(model.state.lastLoadedParams?.zoom == 17)
  }
}

// MARK: - Test environment

@MainActor
private final class TestEnv {
  let remote = FakeAnnotationsRemote()
  let map = FakeMap()
  var settings = SettingsState.default
  private(set) var appActions: [AppAction] = []

  /// Whether a non-nil alert was ever presented (a nil `.present` — e.g. a suppressed cancellation
  /// error — does not count).
  var presentedNonNilAlert: Bool {
    appActions.contains { action in
      if case let .alert(.present(params)) = action { params != nil } else { false }
    }
  }

  var lastPresentedImage: Model.Image? {
    if case let .imageDetails(.present(image, _)) = appActions.last { image } else { nil }
  }

  var lastPresentedList: [Model.Image]? {
    if case let .imageList(.present(images, _, _)) = appActions.last { images } else { nil }
  }

  func region(latOffset: Double = 0) -> Region {
    Region(
      center: Coordinate(latitude: 50 + latOffset, longitude: 14),
      span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5),
    )
  }

  func makeModel() -> MapModel {
    makeMapModel(
      map: Lazy(onMainThreadGetter: { self.map }),
      annotationsRemote: remote.asRemote,
      applyMapType: { _ in },
      performAppAction: { [weak self] in self?.appActions.append($0) },
      locationModel: LocationModel(
        initial: LocationState(location: nil, errorMessage: nil, isAccessGranted: false),
        reduce: { _, _, _, _ in },
      ),
      urlOpener: { _ in },
      settings: Variable { self.settings },
      annotationStore: AnnotationStore(),
      sorting: Variable { ImageSorting.dateDescending },
    )
  }
}

@MainActor
private final class FakeAnnotationsRemote {
  private(set) var loadCount = 0
  private(set) var receivedParams: [AnnotationLoadingParams] = []
  var hangFirstCall = false
  var gateNextCall = false
  var response: ([Model.Image], [Model.Cluster]) = ([], [])

  private var gate: CheckedContinuation<Void, Never>?
  private var pendingGateOpen = false

  var asRemote: Remote<AnnotationLoadingParams, ([Model.Image], [Model.Cluster])> {
    Remote { params in
      let (isFirst, gated) = await self.record(params)
      if isFirst, await self.hangFirstCall {
        // Long enough to still be in-flight when the next load replaces (cancels) this one;
        // Task.sleep throws on cancellation, so the load surfaces as a CancellationError.
        try await Task.sleep(for: .seconds(5))
      }
      if gated {
        await self.waitForGate()
      }
      return await self.response
    }
  }

  /// Releases a load suspended by `gateNextCall`; safe to call before the load reaches the gate.
  func openGate() {
    if let gate {
      gate.resume()
      self.gate = nil
    } else {
      pendingGateOpen = true
    }
  }

  private func record(_ params: AnnotationLoadingParams) -> (isFirst: Bool, gated: Bool) {
    loadCount += 1
    receivedParams.append(params)
    let gated = gateNextCall
    gateNextCall = false
    return (loadCount == 1, gated)
  }

  private func waitForGate() async {
    if pendingGateOpen {
      pendingGateOpen = false
      return
    }
    await withCheckedContinuation { gate = $0 }
  }
}

@MainActor
private final class FakeMap: RewindMap {
  struct SetRegionCall {
    var region: Region
    var animated: Bool
  }

  var events: Signal<Event> { .empty }
  var view: UIView { UIView() }
  var size = CGSize(width: 390, height: 844)
  var visibleAnnotations: [MKAnnotation] = []
  private(set) var setRegionCalls: [SetRegionCall] = []
  private(set) var deselectCount = 0

  func add(annotations: [MKAnnotation]) {
    visibleAnnotations += annotations
  }

  func remove(annotations: [MKAnnotation]) async {
    let removed = Set(annotations.map(ObjectIdentifier.init))
    visibleAnnotations.removeAll { removed.contains(ObjectIdentifier($0)) }
  }

  func clear() async {
    visibleAnnotations = []
  }

  func deselectAnnotations() {
    deselectCount += 1
  }

  func set(region: Region, animated: Bool) {
    setRegionCalls.append(SetRegionCall(region: region, animated: animated))
  }

  func apply(mapType _: MapType) {}

  func updateBottomInset(_: CGFloat) {}

  var imageValues: Set<Model.Image> {
    Set(visibleAnnotations.compactMap { ($0 as? Annotation<Model.Image>)?.value })
  }

  var clusterValues: [Model.Cluster] {
    visibleAnnotations.compactMap { ($0 as? Annotation<Model.Cluster>)?.value }
  }

  func firstAnnotation<T: Locatable>(of _: T.Type) -> Annotation<T>? {
    visibleAnnotations.compactMap { $0 as? Annotation<T> }.first
  }
}

// MARK: - Fixtures

private let mapSize = CGSize(width: 390, height: 844) // matches FakeMap.size

private func region(zoom: Int, center: Coordinate = .zero) -> Region {
  Region(center: center, zoom: zoom, mapSize: mapSize)
}

/// An image at the center of grid cell `(lat, lon)` for `zoom` (mirrors LocalClusteringTests);
/// distinct years make date sorting deterministic.
private func img(_ cid: Int, cell lat: Int, _ lon: Int, zoom: Int, year: Int) -> Model.Image {
  let s = delta(zoom: zoom, mapSize: mapSize) / 8
  return modified(Model.Image.mock) {
    $0.cid = cid
    $0.coordinate = Coordinate(
      latitude: Double(lat) * s + s / 2,
      longitude: Double(lon) * s + s / 2,
    )
    $0.date = ImageDate(year: year, year2: year)
  }
}

/// A distinct server-side cluster per `id` (differs in preview cid, coordinate and count).
private func serverCluster(_ id: Int) -> Model.Cluster {
  Model.Cluster(
    preview: modified(Model.Image.mock) { $0.cid = id },
    coordinate: Coordinate(latitude: Double(id), longitude: Double(id)),
    count: id,
  )
}

// MARK: - Async helpers (mirrors ReducerTests: async effects run in an internal Task we can't await)

@MainActor
private func eventually(
  timeout: Duration = .seconds(2),
  _ condition: () -> Bool,
) async -> Bool {
  let deadline = ContinuousClock().now.advanced(by: timeout)
  while !condition() {
    if ContinuousClock().now >= deadline { return false }
    try? await Task.sleep(for: .milliseconds(5))
  }
  return true
}

private func sleep(_ duration: Duration) async {
  try? await Task.sleep(for: duration)
}
