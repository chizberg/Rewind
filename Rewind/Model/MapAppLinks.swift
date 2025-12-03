//
//  MapAppLinks.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 09.02.2025.
//

import SwiftUI

enum MapApp: CaseIterable {
  case apple
  case google
  case yandex
}

extension MapApp {
  var name: LocalizedStringKey {
    switch self {
    case .apple: "Apple Maps"
    case .google: "Google Maps"
    case .yandex: "Yandex Maps"
    }
  }

  func coordinateLink(latitude: Double, longitude: Double) -> URL? {
    switch self {
    case .apple:
      URL(string: "http://maps.apple.com/?daddr=\(latitude),\(longitude)")
    case .google:
      URL(string: "https://www.google.com/maps/dir//\(latitude),\(longitude)")
    case .yandex:
      URL(string: "https://yandex.com/maps/?mode=routes&rtext=~\(latitude),\(longitude)&rtt=auto")
    }
  }
}
