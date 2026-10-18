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
  private let disposePool = AutodisposePool()

  init(content: UIViewController, state: ObservableVariable<BottomSheet.State>) {
    self.content = content
    _state = state
    super.init(nibName: nil, bundle: nil)
    state.newValues.addObserver { [weak self] in
      self?.update(fullscreenProgress: $0.fullscreenProgress)
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
    cardView.layer.cornerRadius = 32
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
    content.view.frame = cardView.bounds
    content.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    cardView.addSubview(content.view)
    content.didMove(toParent: self)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    cardView.bounds.size = view.bounds.size
    cardView.center = CGPoint(x: view.bounds.midX, y: 0)
    update(fullscreenProgress: state.fullscreenProgress)
  }

  private func update(fullscreenProgress: CGFloat) {
    let width = view.bounds.width
    guard width > 0 else { return }
    let padding = 8 * (1 - fullscreenProgress)
    let scale = (width - padding * 2) / width
    cardView.transform = CGAffineTransform(scaleX: scale, y: scale)
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
