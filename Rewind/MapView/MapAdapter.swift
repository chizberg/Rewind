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
final class MapAdapter: NSObject, MKMapViewDelegate {
  typealias Event = MapAction.External.Map

  private var map: Lazy<MKMapView>
  private var pipe = SignalPipe<Event>()
  private var showYearColorInClusters: ObservableVariable<Bool>

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
  }

  func add(annotations: [MKAnnotation]) {
    map.value.addAnnotations(annotations)
  }

  // operation queue for adding/removal?
  func remove(annotations: [MKAnnotation]) {
    animateRemoval(
      annotations.compactMap { map.value.view(for: $0) },
      completion: { [weak self] _ in
        self?.map.value.removeAnnotations(annotations)
      }
    )
  }

  func clear() {
    remove(annotations: map.value.annotations.filter { !($0 is MKUserLocation) })
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
    if let wrapper = annotation as? AnnotationWrapper {
      switch wrapper.value {
      case .image:
        return mapView.dequeueReusableAnnotationView(
          withIdentifier: ReuseIdentifier.image
        )
      case .cluster:
        guard let cell = mapView.dequeueReusableAnnotationView(
          withIdentifier: ReuseIdentifier.cluster
        ) as? ClusterAnnotationView else {
          return nil
        }
        cell.showYearColor = showYearColorInClusters
        return cell
      case .localCluster:
        guard let cell = mapView.dequeueReusableAnnotationView(
          withIdentifier: ReuseIdentifier.localCluster
        ) as? MergedAnnotationView else {
          return nil
        }
        cell.showYearColor = showYearColorInClusters
        return cell
      }
    }
    if annotation is MKClusterAnnotation {
      guard let cell = mapView.dequeueReusableAnnotationView(
        withIdentifier: ReuseIdentifier.mkCluster
      ) as? MergedAnnotationView else {
        return nil
      }
      cell.showYearColor = showYearColorInClusters
      return cell
    }
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
    longitude: 15.796728
  ),
  span: MKCoordinateSpan(
    latitudeDelta: 76.225,
    longitudeDelta: 76.225
  )
)
