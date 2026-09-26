//
//  ImageListModel.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 9. 11. 2025.
//

import Foundation
import SwiftUI
import VGSL

typealias ImageListModel = Reducer<ImageListState, ImageListAction>

struct ImageListState {
  var title: LocalizedStringKey
  var source: TransitionSource
  var images: [Model.Image]
  var sorting: ImageSorting?
}

enum ImageListAction {
  case presentImage(Model.Image)
  case updateImages([Model.Image])
  case setSorting(ImageSorting)
}

func makeImageListModel(
  title: LocalizedStringKey,
  source: TransitionSource,
  images: [Model.Image],
  listUpdates: Signal<[Model.Image]>,
  imageDetailsFactory: @escaping ImageDetailsFactory,
  sorting: Property<ImageSorting>?,
  pushScreen: @escaping (Screen) -> Void,
) -> ImageListModel {
  ImageListModel(
    initial: ImageListState(
      title: title,
      source: source,
      images: images,
      sorting: sorting?.value,
    ),
    reduce: { state, action, effect, _ in
      switch action {
      case let .presentImage(image):
        let store = imageDetailsFactory(image, .image(.listRow(image.cid))).viewStore
        pushScreen(Screen(.image(store)))
      case let .updateImages(images):
        state.images = images
      case let .setSorting(newSorting):
        guard state.sorting != newSorting else { return }
        state.sorting = newSorting
        effect { sorting?.value = newSorting }
        state.images = state.images.sorted(by: newSorting)
      }
    },
  ).adding(
    signal: listUpdates,
    makeAction: { .updateImages($0) },
  )
}
