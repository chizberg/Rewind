//
//  View+Extensions.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 06.02.2025.
//

import SwiftUI

extension View {
  func frame(size: CGSize) -> some View {
    frame(width: size.width, height: size.height)
  }
}
