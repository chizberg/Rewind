//
//  ImageListModel.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 9. 11. 2025..
//

import Foundation
import SwiftUI

import VGSL

typealias ImageListModel = Reducer<ImageListState, ImageListAction>

struct ImageListState {
  var title: LocalizedStringKey
  var matchedTransitionSourceName: String
  var images: [Model.Image]
  var imageDetails: [Identified<ImageDetailsModel>]
}

enum ImageListAction {
  case presentImage(Model.Image)
  case dismissImage
  case updateImages([Model.Image])
}

func makeImageListModel(
  title: LocalizedStringKey,
  matchedTransitionSourceName: String,
  images: [Model.Image],
  listUpdates: Signal<[Model.Image]>,
  imageDetailsFactory: @escaping ImageDetailsFactory
) -> ImageListModel {
  ImageListModel(
    initial: ImageListState(
      title: title,
      matchedTransitionSourceName: matchedTransitionSourceName,
      images: images,
      imageDetails: []
    ),
    reduce: { state, action, _ in
      print(action)
      switch action {
      case let .presentImage(image):
        state.imageDetails = [Identified(value: imageDetailsFactory(image, "image_list"))]
      case .dismissImage:
        state.imageDetails = []
      case let .updateImages(images):
        state.images = images
      }
    }
  ).adding(
    signal: listUpdates,
    makeAction: { .updateImages($0) }
  )
}
