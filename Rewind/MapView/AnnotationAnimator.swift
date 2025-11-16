//
//  AnnotationAnimator.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 05.02.2025.
//

import MapKit

func animateAddition(
  _ views: [MKAnnotationView],
  completion: @escaping (Bool) -> Void = { _ in }
) {
  views.forEach { $0.transform = superSmallTransform }

  UIView.animate(duration: duration, animations: {
    views.forEach { $0.transform = .identity }
  }, completion: completion)
}

func animateRemoval(
  _ views: [MKAnnotationView],
  completion: @escaping (Bool) -> Void = { _ in }
) {
  UIView.animate(duration: duration, animations: {
    views.forEach { $0.transform = superSmallTransform }
  }, completion: completion)
}

private let duration = 0.2
private let superSmallTransform = CGAffineTransform(scaleX: 0.01, y: 0.01)
