//
//  OverlayButton.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 23.2.25..
//

import SwiftUI

struct OverlayButton: View {
  var iconName: String
  var renderingMode: SymbolRenderingMode?
  var action: () -> Void

  init(
    iconName: String,
    renderingMode: SymbolRenderingMode? = nil,
    action: @escaping () -> Void,
  ) {
    self.iconName = iconName
    self.renderingMode = renderingMode
    self.action = action
  }

  var body: some View {
    Button(action: action) {
      Image(systemName: iconName)
        .symbolRenderingMode(renderingMode)
        .font(.title2.monospaced())
        .padding(14)
        .blurBackground(in: Circle())
    }
    .foregroundStyle(.primary)
  }
}

extension View {
  @ViewBuilder
  func blurBackground(in shape: some Shape) -> some View {
    if #available(iOS 26, *) {
      glassEffect(.regular.interactive(), in: shape)
    } else {
      background(.thinMaterial).clipShape(shape)
    }
  }
}

struct BackButton: View {
  @Environment(\.dismiss)
  var dismiss

  var body: some View {
    OverlayButton(
      iconName: "chevron.left",
      action: { dismiss() },
    )
  }
}

#Preview {
  Color.blue.ignoresSafeArea()
    .overlay(alignment: .topLeading) {
      HStack {
        BackButton()

        Spacer()

        OverlayButton(
          iconName: "paintpalette.fill",
          renderingMode: .multicolor,
          action: {},
        )
      }
      .padding()
    }
}
