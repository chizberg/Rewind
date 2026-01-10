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
  var imageDetails: Identified<ImageDetailsModel.Store>?
  var sorting: ImageSorting?
}

enum ImageListAction {
  case presentImage(Model.Image)
  case dismissImage
  case updateImages([Model.Image])
  case setSorting(ImageSorting)
}

func makeImageListModel(
  title: LocalizedStringKey,
  matchedTransitionSourceName: String,
  images: [Model.Image],
  listUpdates: Signal<[Model.Image]>,
  imageDetailsFactory: @escaping ImageDetailsFactory,
  sorting: Property<ImageSorting>?
) -> ImageListModel {
  ImageListModel(
    initial: ImageListState(
      title: title,
      matchedTransitionSourceName: matchedTransitionSourceName,
      images: images,
      imageDetails: nil,
      sorting: sorting?.value
    ),
    reduce: { state, action, _ in
      switch action {
      case let .presentImage(image):
        state.imageDetails = Identified(
          value: imageDetailsFactory(image, "image_list").viewStore
        )
      case .dismissImage:
        state.imageDetails = nil
      case let .updateImages(images):
        state.images = images
      case let .setSorting(newSorting):
        guard state.sorting != newSorting else { return }
        state.sorting = newSorting
        sorting?.value = newSorting
        state.images = state.images.sorted(by: newSorting)
      }
    }
  ).adding(
    signal: listUpdates,
    makeAction: { .updateImages($0) }
  )
}
