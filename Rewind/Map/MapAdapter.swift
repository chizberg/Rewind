//
//  MapViewAdapter.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 03.02.2025.
//

import MapKit
import VGSL

// todo: rename, it's not only adapter
final class MapAdapter: NSObject, MKMapViewDelegate {
  typealias Event = MapAction.External.Map

  private var map: Lazy<MKMapView>
  private var pipe = SignalPipe<Event>()

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

  override init() {
    weak var weakSelf: MapAdapter?
    map = Lazy(getter: { // todo: simplify
      let map = MKMapView()
      map.region = initialRegion
      map.delegate = weakSelf
      map.showsUserLocation = true
      map.register(ImageAnnotationView.self)
      map.register(ClusterAnnotationView.self)
      return map
    })
    super.init()
    weakSelf = self
  }

  func add(annotations: [MKAnnotation]) {
    map.value.addAnnotations(annotations)
  }

  func clear() {
    let toRemove = map.value.annotations.filter { !($0 is MKUserLocation) }
    animateRemoval(
      toRemove.compactMap { map.value.view(for: $0) },
      completion: { [weak self] _ in
        self?.map.value.removeAnnotations(toRemove)
      }
    )
  }

  func set(region: Region, animated: Bool) {
    map.value.setRegion(region, animated: animated)
  }

  func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
    pipe.send(.regionChanged(mapView.region))
  }

  func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
    pipe.send(.annotationSelected(view.annotation))
  }

  func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
    pipe.send(.annotationDeselected(view.annotation))
  }

  func mapView(
    _ mapView: MKMapView,
    viewFor annotation: any MKAnnotation
  ) -> MKAnnotationView? {
    guard let wrapper = annotation as? AnnotationWrapper else { return nil }
    switch wrapper.value {
    case .image:
      return mapView.dequeueReusableAnnotationView(
        ImageAnnotationView.self
      )
    case .cluster:
      return mapView.dequeueReusableAnnotationView(
        ClusterAnnotationView.self
      )
    }
  }

  func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
    animateAddition(views)
  }
}

// TODO: get rid of
private let initialRegion = Region(
  center: Coordinate(latitude: 44.821782, longitude: 20.455564),
  span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
)
