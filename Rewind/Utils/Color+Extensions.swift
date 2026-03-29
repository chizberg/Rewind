//
//  Color+Extensions.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 09.02.2025.
//

import SwiftUI
import VGSL

extension SwiftUI.Color {
  static let systemBackground = SwiftUI.Color(uiColor: .systemBackground)
  static let secondarySystemBackground = SwiftUI.Color(uiColor: .secondarySystemBackground)
  static let label = SwiftUI.Color(uiColor: .label)

  static func fromHex(_ hex: UInt32) -> SwiftUI.Color {
    VGSL.Color.colorWithHexCode(hex).swiftUIColor
  }
}

extension VGSL.Color {
  var swiftUIColor: SwiftUI.Color {
    Color(uiColor: systemColor)
  }
}

extension RGBAColor {
  init(_ uiColor: UIColor) {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
    self.init(red: r, green: g, blue: b, alpha: a)
  }

  var isDark: Bool {
    func linearize(_ c: CGFloat) -> CGFloat {
      c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    let luminance = 0.2126 * linearize(red) + 0.7152 * linearize(green) + 0.0722 * linearize(blue)
    return luminance < 0.5
  }
}
