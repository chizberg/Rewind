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
    guard let (year, count) = makeYearAndCount() else {
      assertionFailure("unable to extract year and count")
      return
    }
    label.text = "\(count)"
    backgroundColor = UIColor.from(year: year)
    setNeedsLayout()
  }

  private func makeYearAndCount() -> (year: Int, count: Int)? {
    if let mkCluster = annotation as? MKClusterAnnotation,
       let wrappers = mkCluster.memberAnnotations as? [AnnotationWrapper],
       case let .image(firstImage) = wrappers.first?.value {
      (year: firstImage.date.year, count: wrappers.count)
    } else
    if let wrapper = annotation as? AnnotationWrapper,
       case let .localCluster(cluster) = wrapper.value,
       let first = cluster.images.first {
      (year: first.date.year, count: cluster.images.count)
    } else {
      nil
    }
  }
}

private let paddings = CGSize(width: 7, height: 5)
