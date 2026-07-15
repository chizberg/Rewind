//
//  MapType.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 4. 7. 2026..
//

import MapKit

enum MapType {
  case scheme
  case hybrid

  var mkMapType: MKMapType {
    switch self {
    case .scheme: .standard
    case .hybrid: .hybrid
    }
  }
}

extension MapType {
  var isScheme: Bool {
    self == .scheme
  }

  var isHybrid: Bool {
    self == .hybrid
  }
}
