//
//  MapType.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 4. 7. 2026..
//

import MapKit

enum MapType {
  case scheme
  case satellite

  var mkMapType: MKMapType {
    switch self {
    case .scheme: .standard
    case .satellite: .satellite
    }
  }
}

extension MapType {
  var isScheme: Bool {
    self == .scheme
  }

  var isSatellite: Bool {
    self == .satellite
  }
}
