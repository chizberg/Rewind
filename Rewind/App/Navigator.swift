//
//  Navigator.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 5. 10. 2026..
//

import SwiftUI
import UIKit
import VGSL

@MainActor
final class Navigator: NSObject {
  let navigationController = UINavigationController()

  var screens: ObservableVariable<[Screen]> {
    $stack.skipRepeats()
  }

  @ObservableProperty
  private var stack: [Screen] = []
  private let makeController: (Screen) -> NavigationScreen
  private let uiKitSources: (TransitionSource) -> UIView?

  init(
    uiKitSources: @escaping (TransitionSource) -> UIView?,
    content: @escaping (Screen) -> some View,
  ) {
    makeController = { makeScreenController(screen: $0, content: content($0)) }
    self.uiKitSources = uiKitSources
    super.init()

    navigationController.delegate = self
    navigationController.interactivePopGestureRecognizer?.delegate = self
  }

  func setRoot(_ content: some View) {
    navigationController.setViewControllers(
      [makeScreenController(screen: nil, content: content)],
      animated: false,
    )
  }

  func push(_ screen: Screen) {
    afterTransition { [self] in
      let controller = makeController(screen)
      if let source = screen.transitionSource,
         let sourceViews = screenControllers.last?.zoomSourceViews {
        controller.preferredTransition = .zoom { [uiKitSources] _ in
          sourceViews.view(for: source) ?? uiKitSources(source)
        }
        sourceViews.freeze(source)
      }
      navigationController.pushViewController(controller, animated: true)
      updateStack()
    }
  }

  func popToRoot() {
    afterTransition { [self] in
      navigationController.popToRootViewController(animated: true)
    }
  }

  private var screenControllers: [NavigationScreen] {
    navigationController.viewControllers.compactMap { $0 as? NavigationScreen }
  }

  private func updateStack() {
    stack = screenControllers.compactMap(\.screen)
  }

  private func afterTransition(_ action: @escaping () -> Void) {
    if let coordinator = navigationController.transitionCoordinator {
      coordinator.animate(alongsideTransition: nil) { [weak self] _ in
        self?.afterTransition(action)
      }
    } else {
      action()
    }
  }
}

extension Navigator: UINavigationControllerDelegate {
  func navigationController(
    _ navigationController: UINavigationController,
    willShow _: UIViewController,
    animated: Bool,
  ) {
    let wasHidden = navigationController.isNavigationBarHidden
    navigationController.setNavigationBarHidden(false, animated: animated)
    navigationController.transitionCoordinator?.notifyWhenInteractionChanges { context in
      if context.isCancelled {
        navigationController.setNavigationBarHidden(wasHidden, animated: true)
      }
    }
  }

  func navigationController(
    _: UINavigationController,
    didShow _: UIViewController,
    animated _: Bool,
  ) {
    screenControllers.last?.zoomSourceViews.unfreezeAll()
    updateStack()
  }
}

extension Navigator: UIGestureRecognizerDelegate {
  func gestureRecognizerShouldBegin(_: UIGestureRecognizer) -> Bool {
    navigationController.viewControllers.count > 1
      && navigationController.transitionCoordinator == nil
  }
}

@MainActor
private protocol NavigationScreen: UIViewController {
  var screen: Screen? { get }
  var zoomSourceViews: ZoomSourceViews { get }
}

@MainActor
private func makeScreenController(screen: Screen?, content: some View) -> NavigationScreen {
  let zoomSourceViews = ZoomSourceViews()
  return ScreenHostingController(
    screen: screen,
    zoomSourceViews: zoomSourceViews,
    content: content.environment(\.zoomSourceViews, zoomSourceViews),
  )
}

private final class ScreenHostingController<Content: View>: UIHostingController<Content>,
  NavigationScreen {
  let screen: Screen?
  let zoomSourceViews: ZoomSourceViews

  init(screen: Screen?, zoomSourceViews: ZoomSourceViews, content: Content) {
    self.screen = screen
    self.zoomSourceViews = zoomSourceViews
    super.init(rootView: content)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
