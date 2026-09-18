//
//  MagicOverlay.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 16. 9. 2026.
//

import SwiftUI

struct MagicOverlay: View {
  var image: UIImage
  var origin: CGPoint
  var isActive: Bool
  var tuning: MagicTuning

  var body: some View {
    ViewRepresentable(
      factory: { MagicOverlayView() },
      updater: { view in
        view.image = image
        view.origin = origin
        view.tuning = tuning
        view.isActive = isActive
      },
    )
  }
}
