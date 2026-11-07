//
//  NavigationStackPreview.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 27. 9. 2026..
//

import SwiftUI

@MainActor
extension PreviewTrait where T == Preview.ViewTraits {
  static var navigationStack: Self {
    .modifier(NavigationStackPreview())
  }
}

private struct NavigationStackPreview: PreviewModifier {
  func body(content: Content, context _: Void) -> some View {
    NavigationStack {
      content
    }
  }
}
