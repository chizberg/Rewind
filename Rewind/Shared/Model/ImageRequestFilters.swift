//
//  ImageRequestFilters.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 13. 4. 2026..
//

import Foundation
import SwiftUI

struct ImageRequestFilters: Equatable {
  enum ImageKind {
    case photo
    case painting
  }

  var yearRange: ClosedRange<Int>
  var imageKind: ImageKind

  init(imageKind: ImageKind) {
    self.yearRange = imageKind.maxRange
    self.imageKind = imageKind
  }

  var isRangeModified: Bool {
    yearRange != imageKind.maxRange
  }
}

extension ImageRequestFilters.ImageKind {
  var isPainting: Bool {
    self == .painting
  }

  var isPhoto: Bool {
    self == .photo
  }
}

extension ImageRequestFilters {
  static let `default` = ImageRequestFilters(imageKind: .photo)
}

extension EnvironmentValues {
  @Entry
  var maxRange: ClosedRange<Int> = ImageRequestFilters.default.imageKind.maxRange
}

extension ImageRequestFilters.ImageKind {
  var maxRange: ClosedRange<Int> {
    switch self {
    case .photo:
      1826...2000
    case .painting:
      -100...1980
    }
  }
}
