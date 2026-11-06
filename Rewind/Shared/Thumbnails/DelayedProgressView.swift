//
//  DelayedProgressView.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 05.02.2025.
//

import SwiftUI
import VGSL

struct DelayedProgressView: View {
  var delay: TimeInterval = 0.5

  @State
  private var isVisible = false

  var body: some View {
    ZStack {
      if isVisible {
        ProgressView()
          .transition(.opacity)
      }
    }
    .task {
      do {
        try await Task.sleep(for: .seconds(delay))
        withAnimation {
          isVisible = true
        }
      } catch {}
    }
  }
}

#if DEBUG
#Preview("single cat") {
  ZStack {
    Image(.cat).resizable().ignoresSafeArea()

    let image = modified(Model.Image.mock) {
      $0.image = $0.image.delayed(delay: 1)
    }

    ImageCardView(
      image: image,
      backgroundColor: SwiftUI.Color(uiColor: .secondarySystemBackground)
    )
    .frame(height: 300)
  }
}
#endif
