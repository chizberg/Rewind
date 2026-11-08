//
//  UIVisualEffect+Glass.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 7. 11. 2026.
//

import UIKit

extension UIVisualEffect {
  static func makeGlass() -> UIVisualEffect {
    if #available(iOS 26, *) {
      UIGlassEffect()
    } else {
      UIBlurEffect(style: .systemThinMaterial)
    }
  }
}
