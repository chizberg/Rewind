//
//  AppStoreReview.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 5. 4. 2026..
//

import StoreKit
import UIKit
import VGSL

@MainActor
final class AppStoreReview {
  @Property
  private var launchCount: Int
  @Property
  private var requestCount: Int

  init(storage: KeyValueStorage) {
    _launchCount = storage.makeCodableField(
      key: "launchCount",
      default: 0,
    )
    _requestCount = storage.makeCodableField(
      key: "requestCount",
      default: 0,
    )
  }

  func appLaunched() {
    launchCount += 1
  }

  func request() {
    guard launchCount > 1 else { return }
    if requestCount.isMultiple(of: 10) {
      requestAppStoreReview()
    }
    requestCount += 1
  }

  private func requestAppStoreReview() {
    #if DEBUG
    print("App Store review requested")
    #else
    guard let scene = UIApplication.shared.activeWindowScene else { return }
    AppStore.requestReview(in: scene)
    #endif
  }
}
