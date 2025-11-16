//
//  ImageAnnotationView.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 05.02.2025.
//

import MapKit
import UIKit

final class ImageAnnotationView: MKAnnotationView {
  private let iconView: UIImageView

  override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
    iconView = UIImageView(image: iconImage)
    super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)

    bounds = CGRect(origin: .zero, size: iconSize)
    addSubview(iconView)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("unavailable")
  }

  override func prepareForDisplay() {
    super.prepareForDisplay()
    guard let wrapper = annotation as? AnnotationWrapper,
          case let .image(image) = wrapper.value else { return }
    iconView.tintColor = UIColor.from(year: image.date.year)

    let angle = (image.dir?.angle ?? 0)
    transform = .identity.rotated(by: angle)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    iconView.frame = bounds
  }

  override var annotation: MKAnnotation? {
    didSet {
      clusteringIdentifier = "image"
      displayPriority = .required
    }
  }
}

private let iconImage = UIImage(named: "imageAnnotation")?.withRenderingMode(.alwaysTemplate)
private let iconSize = CGSize(width: 20, height: 26)
