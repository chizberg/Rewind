//
//  ImageList.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 19.2.25..
//

import SwiftUI
import VGSL

struct ImageList: View {
  var viewStore: ImageListModel.Store

  @Environment(\.dismiss)
  private var dismiss
  @Namespace
  private var namespace

  var body: some View {
    NavigationStack {
      content
        .navigationTitle(viewStore.title)
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            backButton
              .buttonStyle(.plain)
          }
        }
        .fullScreenCover(
          item: Binding(
            get: { viewStore.imageDetails },
            set: { _ in viewStore(.dismissImage) }
          ),
          content: { identified in
            let viewStore = identified.value
            ImageDetailsView(viewStore: viewStore)
              .navigationTransition(
                .zoom(sourceID: viewStore.cid, in: namespace)
              )
          }
        )
    }
  }

  @ViewBuilder
  private var content: some View {
    if !viewStore.images.isEmpty {
      ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 10) {
          items
        }
        .padding(.horizontal, 16)
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

  private var items: some View {
    ForEach(viewStore.images) { image in
      Button {
        viewStore(.presentImage(image))
      } label: {
        ImageListCell(value: image)
      }
      .foregroundStyle(.primary)
      .matchedTransitionSource(id: image.cid, in: namespace)
    }
  }

  private var backButton: some View {
    Button {
      dismiss()
    } label: {
      Image(systemName: "chevron.left")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .foregroundStyle(.primary)
  }
}

#if DEBUG
private let imageDetailsFactoryMock: ImageDetailsFactory = { image, source in
  makeImageDetailsModel(
    modelImage: .mock,
    remote: Remote { .mock },
    image: .mock,
    coordinate: image.coordinate,
    openSource: source,
    favoriteModel: .mock,
    showOnMap: { _ in },
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
