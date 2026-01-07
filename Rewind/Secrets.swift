//
//  Secrets.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 7. 1. 2026..
//

import Foundation

enum Secrets {
  static var googleMapsApiKey: String {
    object(forKey: "GOOGLE_MAPS_API_KEY")
  }
}

private func object<T>(forKey key: String) -> T {
  if let key = Bundle.main.object(forInfoDictionaryKey: key) as? T {
    key
  } else {
    fatalError("Value is missing")
  }
}
