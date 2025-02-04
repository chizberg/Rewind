//
//  MapViewAdapter.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 03.02.2025.
//

import MapKit
import VGSL

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
      return map
    })
    super.init()
    weakSelf = self
  }

  func add(annotations: [MKAnnotation]) {
    map.value.addAnnotations(annotations)
  }

  func clear() {
    map.value.removeAnnotations(map.value.annotations.filter { !($0 is MKUserLocation) })
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
}

// TODO: get rid of
private let initialRegion = Region(
  center: Coordinate(latitude: 44.821782, longitude: 20.455564),
  span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
)
