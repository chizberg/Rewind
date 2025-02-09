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
  case gis
}

extension MapApp {
  var name: LocalizedStringKey {
    switch self {
    case .apple: return "Apple Maps"
    case .google: return "Google Maps"
    case .yandex: return "Yandex Maps"
    case .gis: return "2GIS"
    }
  }

  var downloadLink: URL? {
    switch self {
    case .yandex:
      return URL(string: "https://apps.apple.com/ru/app/id313877526")
    case .gis:
      return URL(string: "https://itunes.apple.com/ru/app/id481627348?mt=8")
    case .google:
      return URL(string: "https://apps.apple.com/ru/app/id585027354")
    case .apple:
      return nil
    }
  }

  func coordinateLink(latitude: Double, longitude: Double) -> URL? {
    switch self {
    case .yandex:
      return URL(string: "yandexmaps://yandex.ru/maps/?rtext=~\(latitude)%2C\(longitude)")
    case .gis:
      return URL(
        string: "dgis://2gis.ru/routeSearch/rsType/pedestrian/to/\(longitude),\(latitude)"
      )
    case .google:
      return URL(string: "comgooglemaps://?daddr=\(latitude),\(longitude)")
    case .apple:
      return URL(string: "http://maps.apple.com/?daddr=\(latitude),\(longitude)")
    }
  }
}
