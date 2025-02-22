//
//  LocationProvider.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 22.2.25..
//

import CoreLocation
import VGSL

final class LocationProvider: NSObject, CLLocationManagerDelegate {
  @ObservableProperty
  private(set) var location: CLLocation? = nil
  private let manager: CLLocationManager

  override init() {
    manager = CLLocationManager()
    super.init()

    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyBest
    manager.distanceFilter = kCLHeadingFilterNone
  }

  func start() {
    manager.requestWhenInUseAuthorization()
    manager.startUpdatingLocation()
  }

  func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    location = locations.last
  }

  func locationManager(_: CLLocationManager, didFailWithError error: Error) {
    print("Location manager failed with error: \(error)") // TODO: error handling
    location = nil
  }
}
