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
  private let minimizedScaleView = UIView()
  private let cardView = UIView()
  private let fillView = UIView()
  private let grabberView = UIView()
  private var sheetToolbarTop: CGFloat?
  private var lastParentTop: CGFloat?
  private var isMinimized = false
  private var showsSheetToolbar: Bool
  let disposePool = AutodisposePool()

  init(
    content: UIViewController,
    state: ObservableVariable<BottomSheet.State>,
  ) {
    self.content = content
    _state = state
    showsSheetToolbar = state.value.showsSheetToolbar
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
    minimizedScaleView.layer.anchorPoint = CGPoint(x: 0.5, y: 0)
    minimizedScaleView.addSubview(cardView)
    view.addSubview(minimizedScaleView)

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

    grabberView.backgroundColor = .label.withAlphaComponent(0.3)
    grabberView.layer.cornerRadius = 2
    grabberView.isUserInteractionEnabled = false
    grabberView.frame = CGRect(x: (cardView.bounds.width - 60) / 2, y: 4.5, width: 60, height: 4)
    grabberView.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin]
    cardView.addSubview(grabberView)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    minimizedScaleView.bounds.size = view.bounds.size
    minimizedScaleView.center = CGPoint(x: view.bounds.midX, y: 0)
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
    if state.showsSheetToolbar != showsSheetToolbar {
      showsSheetToolbar = state.showsSheetToolbar
      if showsSheetToolbar {
        fadeOutMapTopBar()
      } else {
        fadeInMapTopBar()
      }
    }
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
    let grabberAlpha: CGFloat = state.fullscreenProgress > 0.35 ? 0 : 1
    if grabberView.alpha != grabberAlpha {
      UIView.animate(withDuration: 0.25) { [grabberView] in
        grabberView.alpha = grabberAlpha
      }
    }
    let isMinimized = state.detent == .minimized
    content.view.alpha = isMinimized ? 0.5 : 1
    setMinimizedScale(isMinimized: isMinimized)
  }

  private func fadeOutMapTopBar() {
    guard let host = parent?.view else { return }
    fadeOutSnapshotAboveSheet(in: host, at: 0)
  }

  private func fadeInMapTopBar() {
    guard let navigationController else { return }
    let fadeIn = CABasicAnimation(keyPath: "opacity")
    fadeIn.fromValue = 0
    fadeIn.duration = 0.25
    fadeIn.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    navigationController.navigationBar.layer.add(fadeIn, forKey: "fadeIn")
    let host: UIView = navigationController.view
    fadeOutSnapshotAboveSheet(in: host, at: host.subviews.count)
  }

  private func fadeOutSnapshotAboveSheet(in host: UIView, at index: Int) {
    guard let window = view.window,
          let sheetTop = view.superview?.layer.presentation()?.frame.minY,
          sheetTop > 0
    else { return }
    let rect = CGRect(x: 0, y: 0, width: window.bounds.width, height: sheetTop)
    guard let snapshot = window.resizableSnapshotView(
      from: rect,
      afterScreenUpdates: false,
      withCapInsets: .zero,
    ) else { return }
    snapshot.frame = host.convert(rect, from: window)
    snapshot.isUserInteractionEnabled = false
    host.insertSubview(snapshot, at: index)
    UIView.animate(withDuration: 0.25) {
      snapshot.alpha = 0
    } completion: { _ in
      snapshot.removeFromSuperview()
    }
  }

  private func setMinimizedScale(isMinimized: Bool) {
    guard isMinimized != self.isMinimized else { return }
    self.isMinimized = isMinimized
    let scale = isMinimized ? CATransform3DMakeScale(0.9, 0.9, 1) : CATransform3DIdentity
    let spring = content.view.layer.animation(forKey: "opacity")?.copy() as? CABasicAnimation
    let animation = spring ?? CABasicAnimation()
    animation.delegate = nil
    animation.keyPath = "transform"
    let currentScale = minimizedScaleView.layer.presentation()?.transform ?? scale
    animation.fromValue = spring == nil ? scale : currentScale
    animation.toValue = scale
    animation.fillMode = .forwards
    animation.isRemovedOnCompletion = false
    minimizedScaleView.layer.add(animation, forKey: "minimizedScale")
  }
}

private func makeGlassEffect() -> UIVisualEffect {
  if #available(iOS 26, *) {
    UIGlassEffect()
  } else {
    UIBlurEffect(style: .systemThinMaterial)
  }
}
