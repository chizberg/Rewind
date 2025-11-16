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
    Button(action: action) {
      Image(systemName: iconName)
        .font(.title2)
        .padding(14)
        .circleBlurBackground()
    }
    .foregroundStyle(.primary)
  }
}

extension View {
  @ViewBuilder
  fileprivate func circleBlurBackground() -> some View {
    if #available(iOS 26, *) {
      glassEffect(in: Circle())
    } else {
      background(.thinMaterial).clipShape(Circle())
    }
  }
}

struct BackButton: View {
  @Environment(\.dismiss)
  var dismiss

  var body: some View {
    OverlayButton(
      iconName: "chevron.left",
      action: {
        dismiss()
        print("dismiss called")
      }
    )
  }
}

#Preview {
  Color.blue.ignoresSafeArea()
    .overlay(alignment: .topLeading) {
      BackButton()
        .padding()
    }
}
