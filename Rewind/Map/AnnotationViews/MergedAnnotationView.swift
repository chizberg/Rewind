//
//  MergedAnnotationView.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 07.02.2025.
//

import MapKit
import VGSL

// when multiple annotations are nearby, they are merged into a local cluster
// don't mix it with Model.Cluster, that thing is for network clusters
final class MergedAnnotationView: MKAnnotationView {
  private let label = UILabel()

  override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
    super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)

    label.textAlignment = .center
    label.font = .systemFont(ofSize: 17, weight: .bold)
    label.textColor = .white
    addSubview(label)
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
    guard let cluster = annotation as? MKClusterAnnotation,
          let wrappers = cluster.memberAnnotations as? [AnnotationWrapper],
          case let .image(firstPhoto) = wrappers.first?.value,
          wrappers.count > 0
    else { return }
    label.text = "\(wrappers.count)"
    backgroundColor = UIColor.from(year: firstPhoto.date.year)
    setNeedsLayout()
  }
}

private let paddings = CGSize(width: 7, height: 5)
