//
//  MergedAnnotationView.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 07.02.2025.
//

import MapKit
import VGSL

final class MergedAnnotationView: MKAnnotationView {
  private let label = UILabel()
  private var colorSubscription: Disposable?

  var showYearColor: ObservableVariable<Bool>? {
    didSet {
      colorSubscription = showYearColor?
        .currentAndNewValues
        .addObserver { [weak self] showYearColor in
          self?.updateColors(showYearColor: showYearColor)
        }
    }
  }

  override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
    super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)

    label.textAlignment = .center
    label.font = .systemFont(ofSize: 17, weight: .semibold)
    addSubview(label)
    registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
      self.updateColors()
    }
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    let labelSize = label.intrinsicContentSize
    let withPaddings = modified(labelSize) {
      $0.width += paddings.width * 2
      $0.height += paddings.height * 2
    }
    bounds = CGRect(origin: .zero, size: withPaddings)
    label.frame = CGRect(
      origin: CGPoint(
        x: paddings.width,
        y: paddings.height
      ),
      size: labelSize
    )
    layer.cornerRadius = min(bounds.width, bounds.height) / 2
  }

  override func prepareForDisplay() {
    super.prepareForDisplay()
    guard let count else {
      assertionFailure("unable to extract year and count")
      return
    }
    label.text = "\(count)"
    updateColors()
    setNeedsLayout()
  }

  private func updateColors() {
    updateColors(showYearColor: showYearColor?.value ?? true)
  }

  private func updateColors(showYearColor: Bool) {
    if showYearColor, let year {
      backgroundColor = UIColor.from(year: year)
      label.textColor = .white
    } else {
      backgroundColor = .neutralClusterBg
      label.textColor = .label
    }
  }

  private var year: Int? {
    if let mkCluster = annotation as? MKClusterAnnotation,
       let wrappers = mkCluster.memberAnnotations as? [Annotation<Model.Image>],
       let first = wrappers.first {
      first.value.date.year
    } else
    if let wrapper = annotation as? Annotation<Model.LocalCluster>,
       let first = wrapper.value.images.first {
      first.date.year
    } else {
      nil
    }
  }

  private var count: Int? {
    if let mkCluster = annotation as? MKClusterAnnotation,
       let wrappers = mkCluster.memberAnnotations as? [Annotation<Model.Image>] {
      wrappers.count
    } else
    if let wrapper = annotation as? Annotation<Model.LocalCluster> {
      wrapper.value.images.count
    } else {
      nil
    }
  }
}

private let paddings = CGSize(width: 7, height: 5)
