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

  var source: TransitionSource? {
    switch self {
    case .noImages: nil
    case let .image(image): .image(.thumbnail(image.cid))
    case .viewAsList: .imageList(.viewAsListButton)
    }
  }

  var id: TransitionSource? { source }

  var image: Model.Image? {
    if case let .image(image) = self { image } else { nil }
  }
}
