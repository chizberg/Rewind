//
//  ClusterAnnotationView.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 05.02.2025.
//

import MapKit
import UIKit
import VGSL

final class ClusterAnnotationView: MKAnnotationView {
  private let imageView: UIImageView
  private let countView: UIView
  private let countLabel: UILabel
  private var loadingTask: Task<Void, Never>?

  private var gradient = SettingsState.default.gradientScheme
  private var yearRange = ImageRequestFilters.default.imageKind.maxRange

  private var gradientSubscription: Disposable?
  private var yearRangeSubscription: Disposable?

  override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
    imageView = UIImageView(image: nil)
    countView = UIView()
    countLabel = UILabel()
    super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)

    imageView.layer.borderWidth = borderWidth
    imageView.layer.cornerRadius = imageSize.width / 2
    imageView.clipsToBounds = true
    countLabel.font = labelFont

    bounds = CGRect(origin: .zero, size: imageSize)
    addSubview(imageView)
    addSubview(countView)
    countView.addSubview(countLabel)

    registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
      self.updateColors()
    }
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("unavailable")
  }

  override func prepareForDisplay() {
    super.prepareForDisplay()
    guard let clusterValue else { return }

    imageView.image = nil

    loadingTask = clusterValue.preview.image.load(
      ImageLoadingParams(
        quality: .low,
        cachedOnly: false,
      ),
    ) { [weak self] result in
      guard let self else { return }
      switch result {
      case let .success(image):
        UIView.transition(
          with: imageView,
          duration: 0.25,
          options: .transitionCrossDissolve,
        ) {
          self.imageView.image = image
        }
      case let .failure(error):
        guard error is CancellationError == false else { return }
        imageView.image = .error
      }
    }

    countLabel.text = String(clusterValue.count)
    updateColors()
    setNeedsLayout()
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    loadingTask?.cancel()
    gradientSubscription = nil
    yearRangeSubscription = nil
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    imageView.frame = bounds
    layoutCountView()
  }

  func subscribe(
    gradientScheme: ObservableVariable<GradientScheme>,
    yearRange: ObservableVariable<ClosedRange<Int>>,
  ) {
    gradientSubscription = gradientScheme.currentAndNewValues.addObserver { [weak self] in
      guard let self else { return }
      gradient = $0
      updateColors()
    }
    yearRangeSubscription = yearRange.currentAndNewValues.addObserver { [weak self] in
      guard let self else { return }
      self.yearRange = $0
      UIView.animate { self.updateColors() }
    }
  }

  private var clusterValue: Model.Cluster? {
    if let wrapper = annotation as? Annotation<Model.Cluster> {
      wrapper.value
    } else {
      nil
    }
  }

  private func updateColors() {
    guard let clusterValue else { return }
    let yearColor = gradient.color(at: clusterValue.preview.date.year, maxRange: yearRange)
    let bgColor = yearColor.systemColor
    let fgColor: UIColor = if yearColor.isDark {
      .white
    } else if let fg = gradient.darkForeground {
      fg.systemColor
    } else {
      .black
    }

    imageView.layer.borderColor = bgColor.cgColor
    imageView.backgroundColor = bgColor.withAlphaComponent(0.8)
    countView.backgroundColor = bgColor
    countLabel.textColor = fgColor
  }

  private func layoutCountView() {
    let labelSize = countLabel.intrinsicContentSize
    let countViewSize = CGSize(
      width: labelSize.width + badgePadding.width * 2,
      height: labelSize.height + badgePadding.height * 2,
    )

    countView.isHidden = countViewSize.width > frame.width
    if countView.isHidden { return }

    let countViewOrigin = CGPoint(
      x: bounds.width - countViewSize.width,
      y: bounds.height - countViewSize.height,
    )
    let labelOrigin = CGPoint(
      x: badgePadding.width,
      y: badgePadding.height,
    )

    countView.frame = CGRect(origin: countViewOrigin, size: countViewSize)
    countLabel.frame = CGRect(origin: labelOrigin, size: labelSize)
    countView.layer.cornerRadius = min(countViewSize.height, countViewSize.width) / 2
  }
}

private let imageSize = CGSize(width: 60, height: 60)
private let borderWidth: CGFloat = 3
private let badgePadding = CGSize(width: 5, height: 2.5)

private let labelFont = UIFont.systemFont(ofSize: 15, weight: .semibold)

extension UIColor {
  static let neutralClusterBg = UIColor(dynamicProvider: { traits in
    switch traits.userInterfaceStyle {
    case .dark: .black.withAlphaComponent(0.7)
    case .light, .unspecified: fallthrough
    @unknown default: .white.withAlphaComponent(0.9)
    }
  })
}
