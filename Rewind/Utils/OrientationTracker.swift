//
//  OrientationTracker.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 7. 12. 2025.
//

import UIKit
import VGSL

enum Orientation {
  case portrait
  case landscapeLeft
  case landscapeRight
  case upsideDown

  init?(systemValue: UIDeviceOrientation) {
    switch systemValue {
    case .portrait: self = .portrait
    case .landscapeLeft: self = .landscapeLeft
    case .landscapeRight: self = .landscapeRight
    case .portraitUpsideDown: self = .upsideDown
    case .faceDown, .faceUp, .unknown: fallthrough
    @unknown default: return nil
    }
  }
}

final class OrientationTracker {
  @ObservableProperty
  var orientation = Orientation(
    systemValue: UIDevice.current.orientation
  ) ?? .portrait

  init() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(orientationDidChange),
      name: UIDevice.orientationDidChangeNotification,
      object: nil
    )
    UIDevice.current.beginGeneratingDeviceOrientationNotifications()
  }

  @objc
  private func orientationDidChange() {
    orientation = Orientation(
      systemValue: UIDevice.current.orientation
    ) ?? orientation
  }

  deinit {
    UIDevice.current.endGeneratingDeviceOrientationNotifications()
    NotificationCenter.default.removeObserver(self)
  }
}
