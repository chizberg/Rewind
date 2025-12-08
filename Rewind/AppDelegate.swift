//
//  AppDelegate.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 5. 12. 2025..
//

import UIKit
import VGSL

final class AppDelegate: NSObject, UIApplicationDelegate {
  let orientationLock: ObservableProperty<OrientationLock?>?
  let disposePool = AutodisposePool()

  override init() {
    orientationLock = withUIIdiom(
      phone: ObservableProperty(initialValue: nil),
      pad: nil // orientation lock does not apply
    )
    super.init()

    orientationLock?.newValues.addObserver {
      if let scene = UIApplication.shared.activeWindowScene {
        scene.requestGeometryUpdate(
          UIWindowScene.GeometryPreferences.iOS(
            interfaceOrientations: $0?.mask ?? defaultOrientationMask
          )
        )
      }
    }.dispose(in: disposePool)
  }

  func application(
    _: UIApplication,
    supportedInterfaceOrientationsFor _: UIWindow?
  ) -> UIInterfaceOrientationMask {
    orientationLock?.value?.mask ?? defaultOrientationMask
  }
}

private var defaultOrientationMask: UIInterfaceOrientationMask {
  withUIIdiom(phone: .allButUpsideDown, pad: .all)
}

extension UIApplication {
  var activeWindowScene: UIWindowScene? {
    connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
  }
}
