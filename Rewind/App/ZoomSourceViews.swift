//
//  ZoomSourceViews.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 10. 10. 2026..
//

import SwiftUI
import UIKit

extension EnvironmentValues {
  @Entry
  var zoomSourceViews: ZoomSourceViews?
}

@MainActor
final class ZoomSourceViews {
  private var views: [TransitionSource: WeakRef<ZoomSourceView>] = [:]

  func view(for source: TransitionSource) -> UIView? {
    views[source]?.value
  }

  func freeze(_ source: TransitionSource) {
    views[source]?.value?.freeze()
  }

  func unfreezeAll() {
    for view in views.values {
      view.value?.unfreeze()
    }
  }

  fileprivate func register(_ view: ZoomSourceView, for source: TransitionSource) {
    views[source] = WeakRef(view)
  }
}

struct ZoomSourceModifier: ViewModifier {
  let source: TransitionSource

  @Environment(\.zoomSourceViews)
  private var zoomSourceViews
  @State
  private var frozen = false

  func body(content: Content) -> some View {
    if let zoomSourceViews {
      content
        .buttonStyle(StillButtonStyle())
        .opacity(frozen ? 0 : 1)
        .background {
          ViewRepresentable(
            factory: { ZoomSourceView() },
            updater: {
              $0.onFrozenChange = { frozen = $0 }
              zoomSourceViews.register($0, for: source)
            },
          )
        }
    } else {
      content
    }
  }
}

private struct StillButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
  }
}

private final class ZoomSourceView: UIView {
  var onFrozenChange: (Bool) -> Void = { _ in }
  private var snapshot: UIView?

  override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = false
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func freeze() {
    guard snapshot == nil,
          let window,
          let snapshot = window.resizableSnapshotView(
            from: convert(bounds, to: window),
            afterScreenUpdates: false,
            withCapInsets: .zero,
          )
    else { return }
    snapshot.frame = bounds
    snapshot.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    addSubview(snapshot)
    self.snapshot = snapshot
    onFrozenChange(true)
  }

  func unfreeze() {
    guard let snapshot else { return }
    snapshot.removeFromSuperview()
    self.snapshot = nil
    onFrozenChange(false)
  }
}
