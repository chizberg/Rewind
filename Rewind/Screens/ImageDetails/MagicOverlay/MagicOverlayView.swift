//
//  MagicOverlayView.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 18. 9. 2026.
//

import UIKit
import VGSL

final class MagicOverlayView: UIView {
  var image: UIImage? {
    didSet {
      if isShown, image !== oldValue {
        renderBlur()
      }
    }
  }

  var origin = CGPoint.zero
  var tuning = MagicTuning.default {
    didSet {
      if isShown, tuning != oldValue {
        buildContent()
      }
    }
  }

  var isActive = false {
    didSet {
      guard isActive != oldValue else { return }
      if isActive {
        activate()
      } else {
        deactivate()
      }
    }
  }

  private let content = CALayer()
  private var blurLayer = CALayer()
  private var blobs = CALayer()
  private var dust: MagicDustLayer?
  private var isShown = false
  private var generation = 0
  private var blurRequests = 0

  override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = false
    content.masksToBounds = true
    content.opacity = 0
    layer.addSublayer(content)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    CATransaction.performWithoutAnimations {
      content.frame = bounds
      content.mask?.frame = content.bounds
      blurLayer.frame = content.bounds
      blobs.frame = content.bounds
    }
  }

  private func activate() {
    generation += 1
    if isShown {
      fade(to: 1, completion: nil)
      return
    }
    isShown = true
    buildContent()
    CATransaction.performWithoutAnimations {
      content.removeAnimation(forKey: "fade")
      content.opacity = 1
    }
    reveal()
  }

  private func deactivate() {
    generation += 1
    let generation = generation
    fade(to: 0) { [weak self] in
      guard let self, generation == self.generation else { return }
      clearContent()
      isShown = false
    }
  }

  private func buildContent() {
    clearContent()
    CATransaction.performWithoutAnimations {
      blurLayer = CALayer()
      blurLayer.frame = bounds
      blurLayer.contentsGravity = .resize
      content.addSublayer(blurLayer)
      blobs = MagicBlobsLayer(tuning: tuning, size: bounds.size)
      blobs.frame = bounds
      content.addSublayer(blobs)
      let dust = MagicDustLayer(
        tuning: tuning,
        size: bounds.size,
        origin: origin,
        scale: traitCollection.displayScale,
      )
      content.addSublayer(dust)
      self.dust = dust
    }
    renderBlur()
  }

  private func clearContent() {
    CATransaction.performWithoutAnimations {
      content.sublayers?.forEach { $0.removeFromSuperlayer() }
      content.mask = nil
    }
    dust = nil
  }

  private func renderBlur() {
    guard let image else { return }
    blurRequests += 1
    let request = blurRequests
    let blur = MagicBlur(image: image, radius: tuning.blur, displayedSize: bounds.size)
    Task { [weak self] in
      let rendered = await Task.detached(priority: .userInitiated) { blur.rendered() }.value
      guard let self, request == blurRequests else { return }
      blurLayer.contents = rendered
    }
  }

  private func reveal() {
    let generation = generation
    let ripple = MagicRippleLayer(tuning: tuning, size: bounds.size, origin: origin)
    content.mask = ripple
    dust?.gust()
    CATransaction.begin()
    CATransaction.setCompletionBlock { [weak self] in
      guard let self, generation == self.generation else { return }
      content.mask = nil
    }
    ripple.reveal()
    CATransaction.commit()
  }

  private func fade(to opacity: Float, completion: (() -> Void)?) {
    let animation = CABasicAnimation(keyPath: "opacity")
    animation.fromValue = content.presentation()?.opacity ?? content.opacity
    animation.toValue = opacity
    animation.duration = tuning.duration
    animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    CATransaction.begin()
    CATransaction.setCompletionBlock(completion)
    CATransaction.performWithoutAnimations {
      content.opacity = opacity
    }
    content.add(animation, forKey: "fade")
    CATransaction.commit()
  }
}
