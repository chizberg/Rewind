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

  override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
    imageView = UIImageView(image: nil)
    countView = UIView()
    countLabel = UILabel()
    super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)

    imageView.layer.borderWidth = borderWidth
    imageView.layer.cornerRadius = imageSize.width / 2
    imageView.clipsToBounds = true

    countLabel.textColor = labelColor
    countLabel.font = labelFont

    bounds = CGRect(origin: .zero, size: imageSize)
    addSubview(imageView)
    addSubview(countView)
    countView.addSubview(countLabel)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("unavailable")
  }

  override func prepareForDisplay() {
    super.prepareForDisplay()
    guard let wrapper = annotation as? AnnotationWrapper,
          case let .cluster(cluster) = wrapper.value
    else { return }

    imageView.image = nil
    loadingTask?.cancel()

    loadingTask = cluster.preview.image.load(quality: .low) { [weak self] in
      self?.imageView.image = $0
    }

    let color = UIColor.from(year: cluster.preview.date.year)
    imageView.layer.borderColor = color.cgColor
    imageView.backgroundColor = color
    countView.backgroundColor = color

    countLabel.text = String(cluster.count)
    setNeedsLayout()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    imageView.frame = bounds
    layoutCountView()
  }

  private func layoutCountView() {
    let labelSize = countLabel.intrinsicContentSize
    let countViewSize = CGSize(
      width: labelSize.width + badgePadding.width * 2,
      height: labelSize.height + badgePadding.height * 2
    )

    countView.isHidden = countViewSize.width > frame.width
    if countView.isHidden { return }

    let countViewOrigin = CGPoint(
      x: bounds.width - countViewSize.width,
      y: bounds.height - countViewSize.height
    )
    let labelOrigin = CGPoint(
      x: badgePadding.width,
      y: badgePadding.height
    )

    countView.frame = CGRect(origin: countViewOrigin, size: countViewSize)
    countLabel.frame = CGRect(origin: labelOrigin, size: labelSize)
    countView.layer.cornerRadius = min(countViewSize.height, countViewSize.width) / 2
  }
}

private let imageSize = CGSize(width: 60, height: 60)
private let borderWidth: CGFloat = 3
private let badgePadding = CGSize(width: 5, height: 2.5)

private let labelColor = UIColor.white
private let labelFont = UIFont.systemFont(ofSize: 15, weight: .bold)
