//
//  MapAdapter.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 03.02.2025.
//

import MapKit
import VGSL

typealias MapType = MKMapType

// TODO: rename, it's not only adapter
@MainActor
final class MapAdapter: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
  typealias Event = MapAction.External.Map

  private var map: Lazy<MKMapView>
  private var pipe = SignalPipe<Event>()
  private var showYearColorInClusters: ObservableVariable<Bool>

  var size: CGSize {
    map.value.frame.size
  }

  var view: UIView {
    map.value
  }

  var events: Signal<Event> {
    pipe.signal
  }

  var visibleAnnotations: [MKAnnotation] {
    map.value.annotations.filter {
      map.value.visibleMapRect.contains(MKMapPoint($0.coordinate))
    }
  }

  init(showYearColorInClusters: ObservableVariable<Bool>) {
    weak var weakSelf: MapAdapter?
    map = Lazy(getter: { // TODO: simplify
      let map = MKMapView()
      map.region = initialRegion
      map.delegate = weakSelf
      map.showsUserLocation = true
      map.isPitchEnabled = false
      map.isRotateEnabled = false
      map.register(
        ImageAnnotationView.self,
        forAnnotationViewWithReuseIdentifier: ReuseIdentifier.image
      )
      map.register(
        ClusterAnnotationView.self,
        forAnnotationViewWithReuseIdentifier: ReuseIdentifier.cluster
      )
      map.register(
        MergedAnnotationView.self,
        forAnnotationViewWithReuseIdentifier: ReuseIdentifier.localCluster
      )
      map.register(
        MergedAnnotationView.self,
        forAnnotationViewWithReuseIdentifier: ReuseIdentifier.mkCluster
      )
      return map
    })
    self.showYearColorInClusters = showYearColorInClusters
    super.init()
    weakSelf = self

    map.whenLoaded { map in
      let pan = UIPanGestureRecognizer(
        target: self,
        action: #selector(self.handlePan(_:))
      )
      pan.delegate = self
      map.addGestureRecognizer(pan)
    }
  }

  func add(annotations: [MKAnnotation]) {
    map.value.addAnnotations(annotations)
  }

  func remove(annotations: [MKAnnotation]) async {
    await withCheckedContinuation { continuation in
      remove(annotations: annotations) {
        continuation.resume()
      }
    }
  }

  func remove(annotations: [MKAnnotation], completion: @escaping Action) {
    animateRemoval(
      annotations.compactMap { map.value.view(for: $0) },
      completion: { [weak self] _ in
        self?.map.value.removeAnnotations(annotations)
        completion()
      }
    )
  }

  func clear() {
    remove(
      annotations: map.value.annotations.filter { !($0 is MKUserLocation) },
      completion: {}
    )
  }

  func deselectAnnotations() {
    map.value.selectedAnnotations = []
  }

  func set(region: Region, animated: Bool) {
    map.value.setRegion(region, animated: animated)
  }

  func apply(mapType: MapType) {
    map.value.mapType = mapType
  }

  func annotations(in rect: MKMapRect) -> [MKAnnotation] {
    map.value.annotations(in: rect).compactMap { $0 as? MKAnnotation }
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
    viewFor annotation: any MKAnnotation
  ) -> MKAnnotationView? {
    if annotation is Annotation<Model.Image> {
      return mapView.dequeueReusableAnnotationView(
        withIdentifier: ReuseIdentifier.image
      )
    } else if annotation is Annotation<Model.Cluster> {
      guard let cell = mapView.dequeueReusableAnnotationView(
        withIdentifier: ReuseIdentifier.cluster
      ) as? ClusterAnnotationView else {
        assertionFailure()
        return nil
      }
      cell.showYearColor = showYearColorInClusters
      return cell
    } else if annotation is Annotation<Model.LocalCluster> {
      guard let cell = mapView.dequeueReusableAnnotationView(
        withIdentifier: ReuseIdentifier.localCluster
      ) as? MergedAnnotationView else {
        assertionFailure()
        return nil
      }
      cell.showYearColor = showYearColorInClusters
      return cell
    } else if annotation is MKClusterAnnotation {
      guard let cell = mapView.dequeueReusableAnnotationView(
        withIdentifier: ReuseIdentifier.mkCluster
      ) as? MergedAnnotationView else {
        return nil
      }
      cell.showYearColor = showYearColorInClusters
      return cell
    } else if annotation is MKUserLocation {
      return nil
    }
    assertionFailure("unknown annotation type: \(type(of: annotation))")
    return nil
  }

  // MARK: - Pan location tracking

  @objc
  private func handlePan(_ recognizer: UIPanGestureRecognizer) {
    pipe.send(.userDragged(recognizer.location(in: map.value), map.value.frame))
  }

  func gestureRecognizer(
    _: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer
  ) -> Bool {
    true
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
    longitude: 15.796728
  ),
  span: MKCoordinateSpan(
    latitudeDelta: 76.225,
    longitudeDelta: 76.225
  )
)
