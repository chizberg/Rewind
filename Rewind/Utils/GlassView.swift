//
//  GlassView.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 19. 10. 2025.
//

import SwiftUI

@available(iOS 26.0, *)
struct GlassView: View {
  var style: Glass = .regular
  var radius: CGFloat

  var body: some View {
    Color.clear
      .glassEffect(style, in: RoundedRectangle(cornerRadius: radius))
  }
}

@available(iOS 26.0, *)
#Preview {
  ZStack {
    Image("cat")
      .resizable()
      .ignoresSafeArea()

    VStack {
      GlassView(radius: 20)
        .frame(width: 200, height: 200)

      GlassView(style: .clear, radius: 20)
        .frame(width: 200, height: 200)
    }
  }
}
