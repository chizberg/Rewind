//
//  Secrets.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 7. 1. 2026.
//

import Foundation

enum Secrets {
  static var googleApiKey: String {
    object(forKey: "GOOGLE_API_KEY", fallback: "")
  }
}

private func object<T>(forKey key: String, fallback: T) -> T {
  if let value = Bundle.main.object(forInfoDictionaryKey: key) as? T {
    return value
  }
  assertionFailure(
    """
    Missing \(key). Create Config/Secrets.xcconfig from \
    Config/Secrets.xcconfig.example and set your API key.
    """
  )
  return fallback
}
