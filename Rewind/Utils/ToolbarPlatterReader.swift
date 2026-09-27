//
//  ToolbarPlatterReader.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 26. 9. 2026..
//

import SwiftUI

extension View {
  // toolbar items on iOS 26+ have glass appearance,
  // but unfortunately can't be filled entirely out of the box
  // so here we read its frame to fill it with gradient
  func readToolbarPlatterFrame(
    action: @escaping (CGRect) -> Void,
  ) -> some View {
    background {
      ViewRepresentable(
        factory: { ToolbarPlatterReaderView() },
        updater: { $0.onChange = action },
      )
    }
  }
}

private final class ToolbarPlatterReaderView: UIView {
  var onChange: (CGRect) -> Void = { _ in }

  private var lastFrame: CGRect?

  override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = false
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    reportPlatterFrame()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    reportPlatterFrame()
  }

  private func reportPlatterFrame() {
    guard let platter else { return }
    unclipAncestors(below: platter) // iOS 26.x
    let frame = platter.convert(platter.bounds, to: self)
    guard frame != lastFrame else { return }
    lastFrame = frame
    DispatchQueue.main.async { [onChange] in
      onChange(frame)
    }
  }

  private var platter: UIView? {
    ancestors.first { ancestor in
      let name = String(describing: type(of: ancestor))
      return name.contains("GlassInteractionView") || name.contains("PlatterGlassView")
    }
  }

  private var ancestors: some Sequence<UIView> {
    sequence(first: self, next: \.superview).dropFirst()
  }

  private func unclipAncestors(below platter: UIView) {
    for ancestor in ancestors.prefix(while: { $0 !== platter }) where ancestor.clipsToBounds {
      ancestor.clipsToBounds = false
    }
  }
}
