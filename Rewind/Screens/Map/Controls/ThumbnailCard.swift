//
//  ThumbnailCard.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 29. 11. 2025.
//

enum ThumbnailCard: Equatable, Identifiable {
  case noImages
  case image(Model.Image)
  case viewAsList

  var id: String {
    switch self {
    case .noImages: "noImages"
    case let .image(image): "\(image.cid)"
    case .viewAsList: "viewAsList"
    }
  }

  var image: Model.Image? {
    if case let .image(image) = self { image } else { nil }
  }
}
