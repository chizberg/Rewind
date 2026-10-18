//
//  VariableBlurView.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 17. 10. 2026.
//

import SwiftUI
import UIKit
import VGSL

struct VariableBlurView: UIViewRepresentable {
  var gradient: SwiftUI.Gradient
  var startPoint: UnitPoint = .top
  var endPoint: UnitPoint = .bottom
  var maxRadius: CGFloat

  func makeUIView(context _: Context) -> VariableBlurUIView {
    VariableBlurUIView(
      maskImage: gradient.renderMask(startPoint: startPoint, endPoint: endPoint),
      maxRadius: maxRadius,
    )
  }

  func updateUIView(_: VariableBlurUIView, context _: Context) {}
}

extension SwiftUI.Gradient {
  static func easedFade(_ color: SwiftUI.Color = .black) -> SwiftUI.Gradient {
    SwiftUI.Gradient(stops: (0...16).map { index in
      let progress = Double(index) / 16
      return SwiftUI.Gradient.Stop(
        color: color.opacity(1 - UnitCurve.easeInOut.value(at: progress)),
        location: progress,
      )
    })
  }

  fileprivate func renderMask(startPoint: UnitPoint, endPoint: UnitPoint) -> CGImage? {
    let stops = stops.sorted { $0.location < $1.location }
    let environment = EnvironmentValues()
    guard let cgGradient = CGGradient(
      colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
      colors: stops.map { $0.color.resolve(in: environment).cgColor } as CFArray,
      locations: stops.map { CGFloat($0.location.clamp(0...1)) },
    ) else {
      return nil
    }
    let side: CGFloat = 64
    let point = { (unitPoint: UnitPoint) in
      CGPoint(x: unitPoint.x * side, y: unitPoint.y * side)
    }
    return UIImage.imageOfSize(CGSize(squareDimension: side), scale: 1) { context in
      context.drawLinearGradient(
        cgGradient,
        start: point(startPoint),
        end: point(endPoint),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation],
      )
    }?.cgImage
  }
}

final class VariableBlurUIView: UIVisualEffectView {
  private let maskImage: CGImage?
  private let maxRadius: CGFloat
  private var appliedFilter: NSObject?

  init(maskImage: CGImage?, maxRadius: CGFloat) {
    self.maskImage = maskImage
    self.maxRadius = maxRadius
    super.init(effect: UIBlurEffect(style: .regular))
    isUserInteractionEnabled = false
    isHidden = true
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func applyFilter() {
    guard let maskImage, let backdropLayer, let filter = makeVariableBlurFilter() else {
      isHidden = true
      return
    }
    filter.setValue(maxRadius, forKey: "inputRadius")
    filter.setValue(maskImage, forKey: "inputMaskImage")
    filter.setValue(true, forKey: "inputNormalizeEdges")
    backdropLayer.filters = [filter]
    appliedFilter = filter
    for subview in subviews.dropFirst() {
      subview.alpha = 0
    }
    if window != nil {
      backdropLayer.setValue(traitCollection.displayScale, forKey: "scale")
    }
    isHidden = false
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    if let backdropLayer, backdropLayer.filters?.first as? NSObject !== appliedFilter {
      applyFilter()
    }
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    applyFilter()
  }

  private var backdropLayer: CALayer? {
    guard let layer = subviews.first?.layer,
          NSStringFromClass(type(of: layer)).hasSuffix("BackdropLayer") else {
      return nil
    }
    return layer
  }
}

private func makeVariableBlurFilter() -> NSObject? {
  let className = ["CA", "Filter"].joined()
  let selector = NSSelectorFromString(["filter", "With", "Type:"].joined())
  guard let filterClass = NSClassFromString(className) as? NSObject.Type,
        filterClass.responds(to: selector) else {
    return nil
  }
  return filterClass.perform(selector, with: ["variable", "Blur"].joined())?
    .takeUnretainedValue() as? NSObject
}

#if DEBUG
#Preview {
  Image(.cat)
    .resizable()
    .scaledToFill()
    .frame(width: 300, height: 400)
    .clipped()
    .overlay(alignment: .top) {
      VariableBlurView(gradient: .easedFade(), maxRadius: 20)
        .frame(height: 200)
    }
}
#endif
