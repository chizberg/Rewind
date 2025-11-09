//
//  ImageList.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 19.2.25..
//

import SwiftUI
import VGSL

struct ImageList: View {
  var viewStore: ViewStore<ImageListState, ImageListAction>

  @Environment(\.dismiss)
  var dismiss

  var body: some View {
    NavigationStack(path: Binding(
      get: { viewStore.imageDetails },
      set: { _ in viewStore(.dismissImage) }
    )) {
      Group {
        if !viewStore.images.isEmpty {
          ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 10) {
              items
            }
          }
        } else {
          ZStack {
            Color.clear
            VStack {
              Text("💔").font(.largeTitle)
              Text("Nothing here yet")
            }
          }
        }
      }
      .navigationTitle(viewStore.title)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          backButton
        }
      }
      .navigationDestination(for: Identified<ImageDetailsModel>.self) { model in
        ImageDetailsView(
          viewStore: model.value.viewStore,
          showCloseButton: false
        )
      }
    }
  }

  private var items: some View {
    ForEach(viewStore.images) { image in
      Button {
        viewStore(.presentImage(image))
      } label: {
        ImageListCell(value: image)
      }
      .foregroundStyle(.primary)
      .padding(.horizontal, 16)
    }
  }

  private var backButton: some View {
    Button {
      dismiss()
    } label: {
      Image(systemName: "chevron.left")
    }
    .foregroundStyle(.primary)
  }
}

#if DEBUG
private let imageDetailsFactoryMock: (Model.Image) -> ImageDetailsModel = { image in
  makeImageDetailsModel(
    modelImage: .mock,
    load: Remote { .mock },
    image: .mock,
    coordinate: image.coordinate,
    favoriteModel: .mock,
    canOpenURL: { _ in false },
    urlOpener: { _ in }
  )
}

#Preview {
  @Previewable @State
  var store = makeImageListModel(
    title: "Images",
    matchedTransitionSourceName: "",
    images: (0..<10).map { idx in
      modified(.mock) { $0.cid = idx }
    },
    listUpdates: .empty,
    imageDetailsFactory: imageDetailsFactoryMock
  ).viewStore

  ImageList(viewStore: store)
}

#Preview("empty") {
  @Previewable @State
  var store = makeImageListModel(
    title: "Images",
    matchedTransitionSourceName: "",
    images: [],
    listUpdates: .empty,
    imageDetailsFactory: imageDetailsFactoryMock
  ).viewStore

  ImageList(viewStore: store)
}
#endif
