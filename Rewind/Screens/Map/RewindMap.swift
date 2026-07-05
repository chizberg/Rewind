//
//  RewindMap.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 03.02.2025.
//

import MapKit
import VGSL

@MainActor
final class RewindMap {
  typealias Event = MapAction.External.Map

  var events: Signal<Event>

  var view: UIView {
    map
  }

  var visibleAnnotations: [MKAnnotation] {
    map.annotations.filter {
      map.visibleMapRect.contains(MKMapPoint($0.coordinate))
    }
  }

  private let map: RewindMapView
  private let delegate: RewindMapDelegate

  init(
    settings: ObservableVariable<SettingsState>,
    filters: ObservableVariable<ImageRequestFilters>,
  ) {
    map = RewindMapView()
    map.region = initialRegion

    delegate = RewindMapDelegate(
      gradientScheme: settings.gradientScheme,
      maxYearRange: filters.imageKind.skipRepeats().map(\.maxRange)
    )
    map.delegate = delegate

    events = Signal.merge(
      map.events,
      delegate.events,
    )
  }

  func add(annotations: [MKAnnotation]) {
    map.addAnnotations(annotations)
  }

  func remove(annotations: [MKAnnotation]) async {
    await withCheckedContinuation { continuation in
      remove(annotations: annotations) {
        continuation.resume()
      }
    }
  }

  func clear() async {
    await remove(
      annotations: map.annotations.filter { !($0 is MKUserLocation) },
    )
  }

  func deselectAnnotations() {
    map.selectedAnnotations = []
  }

  func set(region: Region, animated: Bool) {
    map.setRegion(region, animated: animated)
  }

  func apply(mapType: MapType) {
    guard map.mapType != mapType.mkMapType else { return }
    map.mapType = mapType.mkMapType
  }

  private func remove(annotations: [MKAnnotation], completion: @escaping Action) {
    animateRemoval(
      annotations.compactMap { map.view(for: $0) },
      completion: { [weak self] _ in
        self?.map.removeAnnotations(annotations)
        completion()
      },
    )
  }
}

private final class RewindMapView: MKMapView, UIGestureRecognizerDelegate {
  typealias Event = RewindMap.Event

  var events: Signal<Event> {
    pipe.signal
  }

  private let pipe = SignalPipe<Event>()

  override init(frame: CGRect) {
    super.init(frame: frame)

    showsUserLocation = false
    isPitchEnabled = false
    isRotateEnabled = false

    register(
      ImageAnnotationView.self,
      forAnnotationViewWithReuseIdentifier: ReuseIdentifier.image,
    )
    register(
      ClusterAnnotationView.self,
      forAnnotationViewWithReuseIdentifier: ReuseIdentifier.cluster,
    )
    register(
      MergedAnnotationView.self,
      forAnnotationViewWithReuseIdentifier: ReuseIdentifier.localCluster,
    )
    register(
      MergedAnnotationView.self,
      forAnnotationViewWithReuseIdentifier: ReuseIdentifier.mkCluster,
    )

    let pan = UIPanGestureRecognizer(
      target: self,
      action: #selector(handlePan(_:))
    )
    pan.delegate = self
    addGestureRecognizer(pan)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  @objc
  func handlePan(_ recognizer: UIPanGestureRecognizer) {
    pipe.send(.userDragged(recognizer.location(in: self), frame))
  }

  func gestureRecognizer(
    _: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer,
  ) -> Bool {
    true
  }
}

private final class RewindMapDelegate: NSObject, MKMapViewDelegate {
  typealias Event = RewindMap.Event

  var events: Signal<Event> {
    pipe.signal
  }

  private let pipe = SignalPipe<Event>()
  private let gradientScheme: ObservableVariable<GradientScheme>
  private let maxYearRange: ObservableVariable<ClosedRange<Int>>

  init(
    gradientScheme: ObservableVariable<GradientScheme>,
    maxYearRange: ObservableVariable<ClosedRange<Int>>
  ) {
    self.gradientScheme = gradientScheme
    self.maxYearRange = maxYearRange
  }

  func mapView(_: MKMapView, didAdd views: [MKAnnotationView]) {
    animateAddition(views)
  }

  func mapView(_ mapView: MKMapView, regionDidChangeAnimated _: Bool) {
    pipe.send(.regionChanged(mapView.region))
  }

  func mapView(_: MKMapView, didSelect view: MKAnnotationView) {
    pipe.send(.annotationSelected(view.annotation))
  }

  func mapView(_: MKMapView, didDeselect view: MKAnnotationView) {
    pipe.send(.annotationDeselected(view.annotation))
  }

  func mapView(
    _ mapView: MKMapView,
    viewFor annotation: any MKAnnotation,
  ) -> MKAnnotationView? {
    if annotation is Annotation<Model.Image> {
      guard let cell = mapView.dequeueReusableAnnotationView(
        withIdentifier: ReuseIdentifier.image,
      ) as? ImageAnnotationView else {
        assertionFailure()
        return nil
      }
      cell.subscribe(gradientScheme: gradientScheme, yearRange: maxYearRange)
      return cell
    } else if annotation is Annotation<Model.Cluster> {
      guard let cell = mapView.dequeueReusableAnnotationView(
        withIdentifier: ReuseIdentifier.cluster,
      ) as? ClusterAnnotationView else {
        assertionFailure()
        return nil
      }
      cell.subscribe(gradientScheme: gradientScheme, yearRange: maxYearRange)
      return cell
    } else if annotation is Annotation<Model.LocalCluster> {
      guard let cell = mapView.dequeueReusableAnnotationView(
        withIdentifier: ReuseIdentifier.localCluster,
      ) as? MergedAnnotationView else {
        assertionFailure()
        return nil
      }
      cell.subscribe(gradientScheme: gradientScheme, yearRange: maxYearRange)
      return cell
    } else if annotation is MKClusterAnnotation {
      guard let cell = mapView.dequeueReusableAnnotationView(
        withIdentifier: ReuseIdentifier.mkCluster,
      ) as? MergedAnnotationView else {
        return nil
      }
      cell.subscribe(gradientScheme: gradientScheme, yearRange: maxYearRange)
      return cell
    } else if annotation is MKUserLocation {
      return nil
    }
    assertionFailure("unknown annotation type: \(type(of: annotation))")
    return nil
  }
}

private enum ReuseIdentifier {
  static let image = "image"
  static let cluster = "cluster"
  static let localCluster = "localCluster"
  static let mkCluster = "mkCluster"
}

// europe and africa
private let initialRegion = Region(
  center: Coordinate(
    latitude: 15.908556,
    longitude: 15.796728,
  ),
  span: MKCoordinateSpan(
    latitudeDelta: 76.225,
    longitudeDelta: 76.225,
  ),
)
