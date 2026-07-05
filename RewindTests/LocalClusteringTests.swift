//
//  LocalClusteringTests.swift
//  RewindTests
//
//  Unit tests for the local (grid-based) clustering in LocalClustering.swift.
//

import CoreLocation
import MapKit
@testable import Rewind
import Testing
import VGSL

// MARK: - Cluster formation (fresh state, first load → no clearing)

struct ClusterFormationTests {
  @Test func fourImagesStayIndividual() {
    var state = emptyState()
    let (toAdd, toRemove) = receive(
      cellImages(4, zoom: 13),
      params: params(zoom: 13),
      into: &state,
    )

    #expect(toAdd.images.count == 4)
    #expect(toAdd.localClusters.isEmpty)
    #expect(toRemove.isEmpty)
    // single cell, stored as individual images (.left)
    #expect(state.clusteredImages.count == 1)
    #expect(state.clusteredImages.values.first?.left?.count == 4)
  }

  @Test func fiveImagesFormClusterAtThreshold() {
    var state = emptyState()
    let (toAdd, toRemove) = receive(
      cellImages(5, zoom: 13),
      params: params(zoom: 13),
      into: &state,
    )

    #expect(toAdd.localClusters.count == 1)
    #expect(toAdd.localClusters.first?.images.count == 5)
    #expect(toAdd.images.isEmpty)
    #expect(toRemove.isEmpty)
    // single cell, stored as a local cluster (.right)
    #expect(state.clusteredImages.count == 1)
    #expect(state.clusteredImages.values.first?.right != nil)
  }

  @Test func cellsClusterIndependently() {
    var state = emptyState()
    // 6 images in cell (0,0) → cluster; 3 in cell (5,5) → individuals.
    let images = cellImages(6, cell: 0, 0, from: 0, zoom: 13)
      + cellImages(3, cell: 5, 5, from: 100, zoom: 13)
    let (toAdd, _) = receive(images, params: params(zoom: 13), into: &state)

    #expect(toAdd.localClusters.count == 1)
    #expect(toAdd.localClusters.first?.images.count == 6)
    #expect(toAdd.images.count == 3)
    #expect(state.clusteredImages.count == 2)
    #expect(state.clusteredImages.values.contains { $0.right != nil })
    #expect(state.clusteredImages.values.contains { $0.left?.count == 3 })
  }
}

// MARK: - Incremental growth (same zoom & filters → additive path)

struct IncrementalGrowthTests {
  @Test func twoPlusThreePromotesToCluster() {
    var state = emptyState()
    let p = params(zoom: 13)
    let base = cellImages(2, from: 0, zoom: 13)
    receive(base, params: p, into: &state) // 2 individuals

    // next load returns the original 2 plus 3 new ones (5 total in the cell)
    let grown = base + cellImages(3, from: 100, zoom: 13)
    let (toAdd, toRemove) = receive(grown, params: p, into: &state)

    #expect(toAdd.localClusters.count == 1)
    #expect(toAdd.localClusters.first?.images.count == 5)
    #expect(toAdd.images.isEmpty)
    // the 2 previously-individual annotations are removed in favor of the cluster
    #expect(toRemove.images.count == 2)
    #expect(state.clusteredImages.values.first?.right != nil)
  }

  @Test func twoPlusTwoStaysIndividual() {
    var state = emptyState()
    let p = params(zoom: 13)
    let base = cellImages(2, from: 0, zoom: 13)
    receive(base, params: p, into: &state)

    let grown = base + cellImages(2, from: 100, zoom: 13) // 4 < threshold
    let (toAdd, toRemove) = receive(grown, params: p, into: &state)

    #expect(toAdd.images.count == 2)
    #expect(toAdd.localClusters.isEmpty)
    #expect(toRemove.isEmpty)
    #expect(state.clusteredImages.values.first?.left?.count == 4)
  }

  @Test func newImageAddedToExistingClusterGetsNewIdentity() throws {
    var state = emptyState()
    let p = params(zoom: 13)
    let base = cellImages(5, from: 0, zoom: 13)
    let first = receive(base, params: p, into: &state)
    let oldCluster = try #require(first.toAdd.localClusters.first)

    let grown = base + cellImages(1, from: 100, zoom: 13) // 6 in the cell
    let (toAdd, toRemove) = receive(grown, params: p, into: &state)

    let newCluster = try #require(toAdd.localClusters.first)
    #expect(newCluster.images.count == 6)
    #expect(newCluster.id != oldCluster.id) // re-created with a fresh id
    #expect(toRemove.localClusters.map(\.id) == [oldCluster.id])
    #expect(toAdd.images.isEmpty)
  }

  @Test func redundantReloadOfClusterIsNoOp() {
    var state = emptyState()
    let p = params(zoom: 13)
    let images = cellImages(5, zoom: 13)
    receive(images, params: p, into: &state)

    let (toAdd, toRemove) = receive(images, params: p, into: &state)
    #expect(toAdd.isEmpty)
    #expect(toRemove.isEmpty)
  }

  @Test func redundantReloadOfIndividualsIsNoOp() {
    var state = emptyState()
    let p = params(zoom: 13)
    let images = cellImages(3, zoom: 13)
    receive(images, params: p, into: &state)

    let (toAdd, toRemove) = receive(images, params: p, into: &state)
    #expect(toAdd.isEmpty)
    #expect(toRemove.isEmpty)
  }

  @Test func clusterDoesNotBreakApartWithFewerImagesAtSameZoom() {
    // Answers "is breaking apart even possible?": at the same zoom, no.
    // The non-clear path is purely additive — a subset reload changes nothing.
    var state = emptyState()
    let p = params(zoom: 13)
    let full = cellImages(6, zoom: 13)
    receive(full, params: p, into: &state)

    let subset = Array(full.prefix(3))
    let (toAdd, toRemove) = receive(subset, params: p, into: &state)

    #expect(toAdd.isEmpty)
    #expect(toRemove.isEmpty)
    #expect(state.clusteredImages.values.first?.right?.images.count == 6)
  }
}

// MARK: - Zoom change (clear + rebuild)

struct ZoomChangeTests {
  @Test func zoomChangeRebuildsClusterWithNewIdentity() throws {
    var state = emptyState()
    // Identical coordinates → the 5 stay together in one cell at any zoom.
    let images = cellImages(5, zoom: 10)
    let first = receive(images, params: params(zoom: 10), into: &state)
    let oldCluster = try #require(first.toAdd.localClusters.first)

    let (toAdd, toRemove) = receive(images, params: params(zoom: 11), into: &state)
    let newCluster = try #require(toAdd.localClusters.first)

    #expect(toRemove.localClusters.map(\.id) == [oldCluster.id])
    #expect(newCluster.images.count == 5)
    #expect(newCluster.id != oldCluster.id)
  }

  @Test func zoomInBreaksClusterIntoIndividuals() {
    var state = emptyState()
    // Cell centers at zoom 13 in 5 distinct rows. At zoom 10 (cell size ×8) they all
    // collapse into one cell → a cluster; back at zoom 13 they split into 5 cells.
    let images = (0..<5).map { img($0, cell: $0, 0, zoom: 13) }
    let first = receive(images, params: params(zoom: 10), into: &state)
    #expect(first.toAdd.localClusters.count == 1) // clustered while zoomed out

    let (toAdd, toRemove) = receive(images, params: params(zoom: 13), into: &state)
    #expect(toRemove.localClusters.count == 1) // old cluster removed
    #expect(toAdd.images.count == 5) // re-evaluated as 5 individuals
    #expect(toAdd.localClusters.isEmpty)
    #expect(state.clusteredImages.count == 5)
    #expect(state.clusteredImages.values.allSatisfy { $0.left?.count == 1 })
  }

  @Test func zoomOutMergesIndividualsIntoCluster() {
    var state = emptyState()
    // 5 separate cells at zoom 13 → 5 individuals.
    let images = (0..<5).map { img($0, cell: $0, 0, zoom: 13) }
    receive(images, params: params(zoom: 13), into: &state)

    // At zoom 10 (cell size ×8) the 5 fall into one cell and merge into a cluster.
    let (toAdd, toRemove) = receive(images, params: params(zoom: 10), into: &state)

    #expect(toAdd.localClusters.count == 1)
    #expect(toAdd.localClusters.first?.images.count == 5)
    // the 5 former individual annotations are replaced by the cluster
    #expect(toRemove.images.count == 5)
    #expect(state.clusteredImages.count == 1)
    #expect(state.clusteredImages.values.first?.right != nil)
    #expect(state.clusteredImages.values.first?.left == nil)
  }

  @Test func zoomOutMergesSurvivorsAndNewImagesIntoOneCluster() {
    var state = emptyState()
    let all = (0..<6).map { img($0, cell: $0, 0, zoom: 13) }
    // first load shows only 2 of them, as individuals at zoom 13
    receive(Array(all.prefix(2)), params: params(zoom: 13), into: &state)

    // zoom out: the 2 survivors plus 4 brand-new images share one cell → one cluster
    let (toAdd, toRemove) = receive(all, params: params(zoom: 10), into: &state)

    #expect(toAdd.localClusters.count == 1) // exactly one cluster, no duplicates
    #expect(toAdd.localClusters.first?.images.count == 6)
    #expect(toRemove.images.count == 2) // only the 2 survivors were on the map
    #expect(state.clusteredImages.count == 1)
    #expect(state.clusteredImages.values.first?.right?.images.count == 6)
  }

  @Test func individualsStayPutOnZoomChangeWithoutChurn() {
    var state = emptyState()
    // two far-apart individuals, each alone in its cell (below threshold)
    let images = [img(0, cell: 0, 0, zoom: 13), img(1, cell: 100, 0, zoom: 13)]
    receive(images, params: params(zoom: 13), into: &state)

    // zoom change: they are still far apart and still individual → nothing should move
    let (toAdd, toRemove) = receive(images, params: params(zoom: 12), into: &state)

    #expect(toAdd.isEmpty)
    #expect(toRemove.isEmpty)
    #expect(state.clusteredImages.count == 2)
    #expect(state.clusteredImages.values.allSatisfy { $0.left?.count == 1 })
  }
}

// MARK: - Server clusters (Model.Cluster from the API)

struct ServerClusterTests {
  @Test func serverClustersAddedOnFirstLoad() {
    var state = emptyState()
    let (toAdd, toRemove) = receive(
      [],
      clusters: [serverCluster(1), serverCluster(2)],
      params: params(zoom: 10),
      into: &state,
    )

    #expect(toAdd.clusters.count == 2)
    #expect(toRemove.isEmpty)
    #expect(state.clusters.count == 2)
  }

  @Test func newServerClustersAddedIncrementally() {
    var state = emptyState()
    let p = params(zoom: 10)
    let a = serverCluster(1)
    let b = serverCluster(2)
    receive([], clusters: [a], params: p, into: &state)

    let (toAdd, toRemove) = receive([], clusters: [a, b], params: p, into: &state)
    #expect(toAdd.clusters == [b]) // only the new one
    #expect(toRemove.isEmpty)
    #expect(state.clusters == [a, b])
  }

  @Test func serverClustersReplacedOnZoomChange() {
    var state = emptyState()
    let a = serverCluster(1)
    let b = serverCluster(2)
    let c = serverCluster(3)
    receive([], clusters: [a, b], params: params(zoom: 10), into: &state)

    let (toAdd, toRemove) = receive(
      [],
      clusters: [c],
      params: params(zoom: 11),
      into: &state,
    )
    #expect(Set(toRemove.clusters) == [a, b])
    #expect(toAdd.clusters == [c])
    #expect(state.clusters == [c])
  }

  @Test func serverClustersUnchangedOnSameParamReload() {
    var state = emptyState()
    let p = params(zoom: 10)
    let a = serverCluster(1)
    receive([], clusters: [a], params: p, into: &state)

    let (toAdd, toRemove) = receive([], clusters: [a], params: p, into: &state)
    #expect(toAdd.clusters.isEmpty)
    #expect(toRemove.clusters.isEmpty)
  }
}

// MARK: - Edge cases

struct EdgeCaseTests {
  @Test func emptyInputProducesNoChanges() {
    var state = emptyState()
    let (toAdd, toRemove) = receive([], params: params(zoom: 10), into: &state)
    #expect(toAdd.isEmpty)
    #expect(toRemove.isEmpty)
    #expect(state.clusteredImages.isEmpty)
    #expect(state.clusters.isEmpty)
  }

  @Test func filterChangeClearsAndRebuilds() throws {
    var state = emptyState()
    let images = cellImages(5, zoom: 10)
    let first = receive(
      images,
      params: params(zoom: 10, filters: .default),
      into: &state,
    )
    let oldCluster = try #require(first.toAdd.localClusters.first)

    // same zoom, different filters → still triggers a clear
    let (toAdd, toRemove) = receive(
      images,
      params: params(zoom: 10, filters: ImageRequestFilters(imageKind: .painting)),
      into: &state,
    )
    let newCluster = try #require(toAdd.localClusters.first)
    #expect(toRemove.localClusters.map(\.id) == [oldCluster.id])
    #expect(newCluster.id != oldCluster.id)
  }

  @Test func firstLoadNeverClears() {
    var state = emptyState()
    // lastLoadedParams is nil → no clearing, hence no spurious removals.
    let (_, toRemove) = receive(cellImages(5, zoom: 13), params: params(zoom: 13), into: &state)
    #expect(toRemove.isEmpty)
  }
}

// MARK: - Fixtures

private let mapSize = CGSize(width: 390, height: 844)

/// Grid cell size in degrees for a zoom — mirrors `clusteringCellRatio = 8`.
private func cellSize(zoom: Int) -> Double {
  delta(zoom: zoom, mapSize: mapSize) / 8
}

/// An image positioned at the *center* of grid cell `(lat, lon)` for `zoom`.
/// Placing at the center guarantees `floor(coord / size)` maps back to `(lat, lon)`.
private func img(
  _ cid: Int,
  cell lat: Int,
  _ lon: Int,
  zoom: Int,
) -> Model.Image {
  let s = cellSize(zoom: zoom)
  return modified(Model.Image.mock) {
    $0.cid = cid
    $0.coordinate = Coordinate(
      latitude: Double(lat) * s + s / 2,
      longitude: Double(lon) * s + s / 2,
    )
  }
}

/// `n` images sharing one cell `(lat, lon)` (identical coordinate → same cell at any zoom),
/// with cids `start ..< start + n`.
private func cellImages(
  _ n: Int,
  cell lat: Int = 0,
  _ lon: Int = 0,
  from start: Int = 0,
  zoom: Int,
) -> [Model.Image] {
  (0..<n).map { img(start + $0, cell: lat, lon, zoom: zoom) }
}

/// A distinct server-side cluster per `id` (differs in preview cid, coordinate and count).
private func serverCluster(_ id: Int) -> Model.Cluster {
  Model.Cluster(
    preview: modified(Model.Image.mock) { $0.cid = id },
    coordinate: Coordinate(latitude: Double(id), longitude: Double(id)),
    count: id,
  )
}

private func params(
  zoom: Int,
  filters: ImageRequestFilters = .default,
) -> AnnotationLoadingParams {
  // Build via the only available init; Region(center:zoom:) round-trips the zoom exactly.
  // (Avoid Region.zero — its zero span makes zoom(region:) divide by zero.)
  AnnotationLoadingParams(
    region: Region(center: .zero, zoom: zoom, mapSize: mapSize),
    filters: filters,
    mapSize: mapSize,
  )
}

private func emptyState() -> MapState {
  MapState(
    mapType: .scheme,
    region: .zero,
    filters: .default,
    currentRegionImages: [],
    previews: [],
    locationState: LocationState(isAccessGranted: false),
    isLoading: false,
    lastLoadedParams: nil,
    clusters: [],
    clusteredImages: [:],
    controls: MapState.ControlsState(
      expandedItems: [],
      minimization: .normal,
      size: .zero,
    ),
  )
}

/// Runs the diff and then advances `lastLoadedParams`, mimicking MapModel `.loaded`
/// (MapModel.swift) so consecutive `receive` calls behave like consecutive server loads.
@discardableResult
private func receive(
  _ images: [Model.Image],
  clusters: [Model.Cluster] = [],
  params p: AnnotationLoadingParams,
  into state: inout MapState,
) -> (toAdd: [AnnotationValue], toRemove: [AnnotationValue]) {
  let diff = makeDiffAfterReceived(
    images: images,
    clusters: clusters,
    params: p,
    mapSize: mapSize,
    state: &state,
  )
  state.lastLoadedParams = p
  return diff
}

extension [AnnotationValue] {
  var images: [Model.Image] { compactMap(\.image) }
  var clusters: [Model.Cluster] { compactMap(\.cluster) }
  var localClusters: [Model.LocalCluster] { compactMap(\.localCluster) }
}
