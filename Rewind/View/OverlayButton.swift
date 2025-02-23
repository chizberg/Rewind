//
//  OverlayButton.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 23.2.25..
//

import SwiftUI

struct OverlayButton: View {
  var iconName: String
  var action: () -> Void

  var body: some View {
    SquishyButton(action: action) { _ in
      Image(systemName: iconName)
        .padding(10)
        .background(.thinMaterial)
        .clipShape(Circle())
    }
  }
}

struct BackButton: View {
  @Environment(\.dismiss)
  var dismiss

  var body: some View {
    OverlayButton(
      iconName: "chevron.left",
      action: { dismiss() }
    )
  }
}
