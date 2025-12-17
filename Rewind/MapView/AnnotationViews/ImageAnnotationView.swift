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
    guard let imageAnn = annotation as? Annotation<Model.Image> else {
      return
    }
    let image = imageAnn.value
    iconView.tintColor = UIColor.from(year: image.date.year)
    iconView.transform = .identity.rotated(by: image.dir?.angle ?? 0)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    iconView.bounds = bounds
    iconView.center = bounds.center
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
