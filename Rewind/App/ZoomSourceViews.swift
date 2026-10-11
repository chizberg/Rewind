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
  private var views: [TransitionSource: WeakRef<FreezableView>] = [:]

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

  fileprivate func register(_ view: FreezableView, for source: TransitionSource) {
    views[source] = WeakRef(view)
  }
}

struct ZoomSource<Content: View>: View {
  let source: TransitionSource
  let content: Content

  @Environment(\.self)
  private var environment
  @Environment(\.zoomSourceViews)
  private var zoomSourceViews
  @State
  private var frozen = false

  var body: some View {
    content
      .buttonStyle(StillButtonStyle())
      .opacity(frozen ? 0 : 1)
      .background {
        if let zoomSourceViews {
          ViewRepresentable(
            factory: { ZoomSourceView(hostedContent: hostedContent) },
            updater: {
              $0.hostedContent = hostedContent
              $0.onFrozenChange = { frozen = $0 }
              zoomSourceViews.register($0, for: source)
            },
          )
        }
      }
  }

  private var hostedContent: HostedZoomSource<Content> {
    HostedZoomSource(content: content, environment: environment)
  }
}

private struct HostedZoomSource<Content: View>: View {
  let content: Content
  let environment: EnvironmentValues

  var body: some View {
    content
      .buttonStyle(StillButtonStyle())
      .transformEnvironment(\.self) { hosted in
        let colorScheme = hosted.colorScheme
        hosted = environment
        hosted.colorScheme = colorScheme
      }
  }
}

private struct StillButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
  }
}

private class FreezableView: UIView {
  func freeze() {}
  func unfreeze() {}
}

private final class ZoomSourceView<HostedContent: View>: FreezableView {
  var hostedContent: HostedContent {
    didSet { host?.rootView = hostedContent }
  }

  var onFrozenChange: (Bool) -> Void = { _ in }
  private var host: UIHostingController<HostedContent>?

  init(hostedContent: HostedContent) {
    self.hostedContent = hostedContent
    super.init(frame: .zero)
    isUserInteractionEnabled = false
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func freeze() {
    guard host == nil,
          let parent = sequence(first: next, next: \.?.next)
          .lazy.compactMap({ $0 as? UIViewController }).first
    else { return }
    let host = UIHostingController(rootView: hostedContent)
    host.view.backgroundColor = .clear
    host.safeAreaRegions = []
    parent.addChild(host)
    host.view.frame = bounds
    host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    addSubview(host.view)
    host.didMove(toParent: parent)
    host.view.layoutIfNeeded()
    self.host = host
    onFrozenChange(true)
  }

  override func unfreeze() {
    guard let host else { return }
    host.willMove(toParent: nil)
    host.view.removeFromSuperview()
    host.removeFromParent()
    self.host = nil
    onFrozenChange(false)
  }
}
