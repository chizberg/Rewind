//
//  SidebarController.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 7. 11. 2026.
//

import UIKit
import VGSL

final class SidebarController: UIViewController {
  private let content: UIViewController
  private let panelView = UIView()
  private(set) var isCollapsed = false
  private(set) lazy var collapseItem = UIBarButtonItem(
    image: sidebarImage,
    primaryAction: UIAction { [weak self] _ in self?.setCollapsed(true) },
  )
  private lazy var expandButton = UIButton(
    configuration: makeExpandConfiguration(),
    primaryAction: UIAction { [weak self] _ in self?.setCollapsed(false) },
  )

  init(content: UIViewController) {
    self.content = content
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func loadView() {
    view = PassthroughView()
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    expandButton.isHidden = true
    view.addSubview(expandButton)

    panelView.clipsToBounds = true
    if #available(iOS 26, *) {
      panelView.cornerConfiguration = .corners(radius: .containerConcentric(minimum: minRadius))
    } else {
      panelView.layer.cornerCurve = .continuous
      panelView.layer.cornerRadius = max(screenRadius - panelInset, minRadius)
    }
    view.addSubview(panelView)

    let glassView = UIVisualEffectView(effect: .makeGlass())
    glassView.frame = panelView.bounds
    glassView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    panelView.addSubview(glassView)

    addChild(content)
    content.view.backgroundColor = .clear
    panelView.addSubview(content.view)
    content.didMove(toParent: self)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    let bounds = view.bounds
    let safeArea = view.safeAreaInsets
    panelView.bounds.size = CGSize(
      width: min(panelWidth, bounds.width - panelInset * 2),
      height: bounds.height - panelInset * 2,
    )
    panelView.center = CGPoint(x: panelInset + panelView.bounds.midX, y: bounds.midY)
    panelView.transform = slideTransform(panelView, isVisible: !isCollapsed)
    content.view.frame = panelView.bounds
    expandButton.bounds.size = expandButton.intrinsicContentSize
    expandButton.center = CGPoint(
      x: safeArea.left + panelInset + expandButton.bounds.midX,
      y: safeArea.top + panelInset + expandButton.bounds.midY,
    )
    expandButton.transform = slideTransform(expandButton, isVisible: isCollapsed)
  }

  func setCollapsed(_ collapsed: Bool) {
    guard collapsed != isCollapsed else { return }
    isCollapsed = collapsed
    slide(panelView, isVisible: !collapsed)
    slide(expandButton, isVisible: collapsed)
  }

  private func slide(_ slidingView: UIView, isVisible: Bool) {
    let oldOffset = slidingView.transform.tx
    slidingView.transform = slideTransform(slidingView, isVisible: isVisible)
    slidingView.isHidden = false
    let animation = CASpringAnimation(perceptualDuration: 0.5, bounce: 0)
    animation.keyPath = "transform.translation.x"
    animation.isAdditive = true
    animation.fromValue = oldOffset - slidingView.transform.tx
    animation.toValue = 0
    animation.onDidStop { [weak slidingView] _ in
      guard let slidingView, slidingView.layer.animationKeys() == nil else { return }
      slidingView.isHidden = slidingView.transform != .identity
    }
    slidingView.layer.add(animation, forKey: UUID().uuidString)
  }
}

private final class PassthroughView: UIView {
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    let view = super.hitTest(point, with: event)
    return view === self ? nil : view
  }
}

private func slideTransform(_ view: UIView, isVisible: Bool) -> CGAffineTransform {
  let rightEdge = view.center.x + view.bounds.width / 2
  return isVisible ? .identity : CGAffineTransform(translationX: -rightEdge, y: 0)
}

private func makeExpandConfiguration() -> UIButton.Configuration {
  var configuration: UIButton.Configuration
  if #available(iOS 26, *) {
    configuration = .glass()
  } else {
    configuration = .plain()
    configuration.background.visualEffect = .makeGlass()
  }
  let chevron = NSTextAttachment()
  chevron.image = UIImage(systemName: "chevron.forward")
  configuration.image = sidebarImage
  configuration.attributedTitle = AttributedString(NSAttributedString(attachment: chevron))
  configuration.imagePadding = 6
  configuration.cornerStyle = .capsule
  configuration.contentInsets = .init(top: 12, leading: 14, bottom: 12, trailing: 14)
  return configuration
}

private let panelWidth: CGFloat = 375
private let panelInset: CGFloat = 8
private let minRadius: CGFloat = 12
private let sidebarImage = UIImage(systemName: "sidebar.leading")
private let screenRadius = DeviceModel.getCurrent().screenRadius()
