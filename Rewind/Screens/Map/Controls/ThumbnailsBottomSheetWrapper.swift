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
  private let onHidesNavbarChange: (Bool) -> Void
  private let disposePool = AutodisposePool()
  private var hidesNavbar = false

  init(
    content: UIViewController,
    state: ObservableVariable<BottomSheet.State>,
    onHidesNavbarChange: @escaping (Bool) -> Void,
  ) {
    self.content = content
    self.onHidesNavbarChange = onHidesNavbarChange
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

  private func update(state: BottomSheet.State) {
    let width = view.bounds.width
    guard width > 0 else { return }
    let fullscreenProgress = state.fullscreenProgress
    let offset = view.bounds.height - state.visibleHeight
    let shift = min(offset, view.window?.safeAreaInsets.top ?? 0)
    content.view.transform = CGAffineTransform(translationX: 0, y: -shift)
    content.additionalSafeAreaInsets.top = shift
    let padding = 8 * (1 - fullscreenProgress)
    let scale = (width - padding * 2) / width
    cardView.transform = CGAffineTransform(scaleX: scale, y: scale)
    let radius: CGFloat = fullscreenProgress.isApproximatelyEqualTo(1) ? 0 : 41
    if cardView.layer.cornerRadius != radius {
      UIView.animate(withDuration: 0.25) { [cardView] in
        cardView.layer.cornerRadius = radius
      }
    }
    fillView.alpha = fullscreenProgress
    if hidesNavbar != (fullscreenProgress > 0.35) {
      hidesNavbar.toggle()
      onHidesNavbarChange(hidesNavbar)
    }
  }
}

private func makeGlassEffect() -> UIVisualEffect {
  if #available(iOS 26, *) {
    UIGlassEffect()
  } else {
    UIBlurEffect(style: .systemThinMaterial)
  }
}
