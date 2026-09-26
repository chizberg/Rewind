//
//  ToolbarPlatterReader.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 26. 9. 2026..
//

import SwiftUI

extension View {
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
    let frame = platter.convert(platter.bounds, to: self)
    guard frame != lastFrame else { return }
    lastFrame = frame
    DispatchQueue.main.async { [onChange] in
      onChange(frame)
    }
  }

  private var platter: UIView? {
    sequence(first: self, next: \.superview)
      .dropFirst()
      .first { String(describing: type(of: $0)).contains("GlassInteractionView") }
  }
}
