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
