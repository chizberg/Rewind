//
//  AxisStack.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 19. 9. 2026..
//

import SwiftUI

struct AxisStack<Content: View>: View {
  var axis: Axis
  var spacing: CGFloat?

  @ViewBuilder
  var content: () -> Content

  var body: some View {
    layout(content)
  }

  private var layout: AnyLayout {
    switch axis {
    case .horizontal: AnyLayout(HStackLayout(spacing: spacing))
    case .vertical: AnyLayout(VStackLayout(spacing: spacing))
    }
  }
}
