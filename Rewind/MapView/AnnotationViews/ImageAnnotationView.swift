//
//  ImageAnnotationView.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 05.02.2025.
//

import MapKit
import UIKit
import VGSL

final class ImageAnnotationView: MKAnnotationView {
  private let iconView: UIImageView

  private var gradient = SettingsState.default.gradientScheme
  private var gradientSubscription: Disposable?

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

    layer.shadowOpacity = 0.25
    layer.shadowOffset = CGSize(width: 0, height: 4)
    layer.shadowRadius = 8
    layer.masksToBounds = false

    updateColor()

    let image = imageAnn.value
    iconView.transform = .identity.rotated(by: image.dir?.angle ?? 0)
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    gradientSubscription = nil
  }

  func subscribe(gradientScheme: ObservableVariable<GradientScheme>) {
    gradientSubscription = gradientScheme.currentAndNewValues.addObserver { [weak self] in
      guard let self else { return }
      gradient = $0
      updateColor()
    }
  }

  private func updateColor() {
    guard let imageAnn = annotation as? Annotation<Model.Image> else {
      return
    }
    let yearColor = gradient.color(at: imageAnn.value.date.year)
    iconView.tintColor = yearColor.systemColor
    let shadowColor: UIColor = if yearColor.isDark {
      .white
    } else if let fg = gradient.darkForeground {
      fg.systemColor
    } else {
      .black
    }
    layer.shadowColor = shadowColor.cgColor
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
