//
//  ThumbnailsBottomSheetWrapper.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 18. 10. 2026.
//

import UIKit
import VGSL

final class ThumbnailsBottomSheetWrapper: UIViewController {
  private let content: UIViewController
  @ObservableVariable
  private var state: BottomSheet.State
  private let cardView = UIView()
  private let fillView = UIView()
  private var sheetToolbarTop: CGFloat?
  private var lastParentTop: CGFloat?
  let disposePool = AutodisposePool()

  init(
    content: UIViewController,
    state: ObservableVariable<BottomSheet.State>,
  ) {
    self.content = content
    _state = state
    super.init(nibName: nil, bundle: nil)
    state.newValues.addObserver { [weak self] in
      self?.update(state: $0)
    }.dispose(in: disposePool)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    cardView.clipsToBounds = true
    cardView.layer.cornerCurve = .continuous
    cardView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    cardView.layer.anchorPoint = CGPoint(x: 0.5, y: 0)
    view.addSubview(cardView)

    let glassView = UIVisualEffectView(effect: makeGlassEffect())
    glassView.frame = cardView.bounds
    glassView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    cardView.addSubview(glassView)

    fillView.backgroundColor = .systemBackground
    fillView.frame = cardView.bounds
    fillView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    cardView.addSubview(fillView)

    addChild(content)
    content.view.backgroundColor = .clear
    cardView.addSubview(content.view)
    content.didMove(toParent: self)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    cardView.bounds.size = view.bounds.size
    cardView.center = CGPoint(x: view.bounds.midX, y: 0)
    content.view.bounds.size = view.bounds.size
    content.view.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
    update(state: state)
  }

  override func viewWillTransition(
    to size: CGSize,
    with coordinator: any UIViewControllerTransitionCoordinator,
  ) {
    super.viewWillTransition(to: size, with: coordinator)
    sheetToolbarTop = nil
  }

  private func update(state: BottomSheet.State) {
    let width = view.bounds.width
    guard width > 0 else { return }
    let fullscreenProgress = state.fullscreenProgress
    let offset = view.bounds.height - state.visibleHeight
    let parentInsets = parent?.view.safeAreaInsets ?? .zero
    let windowInsets = view.window?.safeAreaInsets ?? .zero
    if state.showsSheetToolbar, parentInsets.top != lastParentTop {
      sheetToolbarTop = parentInsets.top
    }
    lastParentTop = parentInsets.top
    let top = sheetToolbarTop ?? parentInsets.top
    let shift = min(offset, top)
    content.view.transform = CGAffineTransform(translationX: 0, y: -shift)
    content.additionalSafeAreaInsets = UIEdgeInsets(
      top: shift,
      left: (fullscreenProgress - 1) * (parentInsets.left - windowInsets.left),
      bottom: 0,
      right: (fullscreenProgress - 1) * (parentInsets.right - windowInsets.right),
    )
    content.view.layoutIfNeeded()
    let padding = 8 * (1 - fullscreenProgress)
    let scale = (width - padding * 2) / width
    cardView.transform = CGAffineTransform(scaleX: scale, y: scale)
    let radius: CGFloat = fullscreenProgress.isApproximatelyEqualTo(1) ? 0 : 38
    if cardView.layer.cornerRadius != radius {
      UIView.animate(withDuration: 0.25) { [cardView] in
        cardView.layer.cornerRadius = radius
      }
    }
    fillView.alpha = fullscreenProgress
  }
}

private func makeGlassEffect() -> UIVisualEffect {
  if #available(iOS 26, *) {
    UIGlassEffect()
  } else {
    UIBlurEffect(style: .systemThinMaterial)
  }
}
