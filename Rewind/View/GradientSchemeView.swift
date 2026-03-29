//
//  GradientSchemeView.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 29. 3. 2026..
//

import SwiftUI

struct GradientSchemeView: UIViewRepresentable {
  var gradientScheme: GradientScheme

  init(_ gradientScheme: GradientScheme) {
    self.gradientScheme = gradientScheme
  }

  func makeUIView(context _: Context) -> GradientSchemeViewImpl {
    GradientSchemeViewImpl(gradientScheme: gradientScheme)
  }

  func updateUIView(_ uiView: GradientSchemeViewImpl, context _: Context) {
    uiView.gradientScheme = gradientScheme
  }
}

final class GradientSchemeViewImpl: UIView {
  var gradientScheme: GradientScheme {
    didSet {
      gradientLayer.set(gradientScheme)
    }
  }

  var gradientLayer: CAGradientLayer

  init(gradientScheme: GradientScheme) {
    self.gradientScheme = gradientScheme
    self.gradientLayer = CAGradientLayer()
    super.init(frame: .zero)

    gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
    gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
    gradientLayer.set(gradientScheme)

    layer.addSublayer(gradientLayer)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    gradientLayer.frame = bounds
  }
}

#if DEBUG
#Preview {
  VStack {
    ForEach(GradientScheme.allCases, id: \.self) {
      GradientSchemeView($0)
    }
  }
}
#endif // DEBUG
