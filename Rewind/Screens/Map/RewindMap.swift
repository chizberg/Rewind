//
//  RewindMap.swift
//  Rewind
//
//  The map's interface: MapModel drives annotations and the region through it, AppGraph wires
//  events, map type and insets. A protocol so tests can drive MapModel with a fake map (no live
//  MKMapView, no view lifecycle). Production: RewindMapImpl; MapModelTests supplies a fake.
//

import MapKit
import UIKit
import VGSL

@MainActor
protocol RewindMap {
  typealias Event = MapAction.External.Map

  var events: Signal<Event> { get }
  var view: UIView { get }
  var size: CGSize { get }
  var visibleAnnotations: [MKAnnotation] { get }

  func add(annotations: [MKAnnotation])
  func remove(annotations: [MKAnnotation]) async
  func clear() async

  func deselectAnnotations()
  func set(region: Region, animated: Bool)
  func apply(mapType: MapType)
  func updateBottomInset(_ inset: CGFloat)
}
