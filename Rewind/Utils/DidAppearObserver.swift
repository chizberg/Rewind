//
//  DidAppearObserver.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 27. 9. 2026..
//

import SwiftUI

extension View {
  // SwiftUI's onAppear may be called too early to affect toolbar animations
  func onUIKitAppear(
    perform action: @escaping () -> Void,
  ) -> some View {
    background {
      ViewControllerRepresentable(
        factory: { DidAppearObserver() },
        updater: { $0.onDidAppear = action },
      )
    }
  }
}

private final class DidAppearObserver: UIViewController {
  var onDidAppear: () -> Void = {}

  override func viewDidLoad() {
    super.viewDidLoad()
    view.isUserInteractionEnabled = false
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    onDidAppear()
  }
}
