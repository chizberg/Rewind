//
//  LocationModel.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 22.2.25..
//

import CoreLocation
import VGSL

typealias LocationModel = Reducer<LocationState, LocationAction>

struct LocationState {
  var location: CLLocation?
  var errorMessage: String?
  var isAccessGranted: Bool
}

enum LocationAction {
  enum LocationEvent {
    case didUpdateLocations([CLLocation])
    case didFailWithError(CLError.Code)
    case didChangeAuthorizationStatus(CLAuthorizationStatus)
  }

  case requestAccess
  case tryStartUpdatingLocation
  case locationEvent(LocationEvent)
}

func makeLocationModel() -> LocationModel {
  let manager = CLLocationManager()
  let delegate = LocationDelegate()

  manager.delegate = delegate
  manager.desiredAccuracy = kCLLocationAccuracyBest
  manager.distanceFilter = kCLHeadingFilterNone

  return Reducer(
    initial: LocationState(
      location: nil,
      isAccessGranted: false
    ),
    reduce: { state, action, enqueueEffect in
      switch action {
      case .requestAccess:
        manager.requestWhenInUseAuthorization()
      case .tryStartUpdatingLocation:
        guard state.isAccessGranted else { return }
        manager.startUpdatingLocation()
      case let .locationEvent(event):
        switch event {
        case let .didUpdateLocations(locations):
          state.location = locations.last
        case let .didFailWithError(errorCode):
          state.errorMessage = String(describing: errorCode)
        case let .didChangeAuthorizationStatus(status):
          state.isAccessGranted = status.isAuthorized
          if state.isAccessGranted {
            enqueueEffect(.anotherAction(.tryStartUpdatingLocation))
          }
        }
      }
    }
  ).adding(signal: delegate.signal.retaining(object: delegate)) { .locationEvent($0) }
}

private final class LocationDelegate: NSObject, CLLocationManagerDelegate {
  private let pipe = SignalPipe<LocationAction.LocationEvent>()

  var signal: Signal<LocationAction.LocationEvent> {
    pipe.signal
  }

  func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    pipe.send(.didUpdateLocations(locations))
  }

  func locationManager(_: CLLocationManager, didFailWithError error: Error) {
    guard let clError = error as? CLError else {
      assertionFailure("Unexpected error type: \(error)")
      return
    }
    pipe.send(.didFailWithError(clError.code))
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    pipe.send(.didChangeAuthorizationStatus(manager.authorizationStatus))
  }
}

extension CLAuthorizationStatus {
  fileprivate var isAuthorized: Bool {
    switch self {
    case .authorizedAlways, .authorizedWhenInUse: true
    case .denied, .notDetermined, .restricted: fallthrough
    @unknown default: false
    }
  }
}
