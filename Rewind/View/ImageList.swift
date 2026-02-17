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

  @Namespace
  private var namespace

  var body: some View {
    NavigationStack {
      content
        .animation(.default, value: viewStore.sorting)
        .navigationTitle(viewStore.title)
        .toolbar { toolbar }
        .fullScreenCover(
          item: viewStore.binding(\.imageDetails, send: { _ in .dismissImage }),
          content: { identified in
            let viewStore = identified.value
            ImageDetailsView(viewStore: viewStore)
              .navigationTransition(
                .zoom(sourceID: viewStore.image.cid, in: namespace)
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

  @ToolbarContentBuilder
  private var toolbar: some ToolbarContent {
    ToolbarItem(placement: .topBarLeading) {
      ToolbarBackButton()
    }
    if let sorting = viewStore.sorting {
      ToolbarItem(placement: .topBarTrailing) {
        Menu(content: {
          Picker(
            "Sorting",
            selection: Binding(
              get: { sorting },
              set: { viewStore(.setSorting($0)) }
            ),
            content: {
              ForEach(ImageSorting.allCases) {
                Label($0.title, systemImage: $0.iconName)
              }
            }
          )
        }, label: {
          Image(systemName: "arrow.up.arrow.down")
        })
      }
    }
  }
}

struct ToolbarBackButton: View {
  @Environment(\.dismiss)
  private var dismiss

  var body: some View {
    Button {
      dismiss()
    } label: {
      Image(systemName: "chevron.left")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .foregroundStyle(.primary)
    .buttonStyle(.plain)
  }
}

extension ImageSorting: Identifiable {
  var id: ImageSorting { self }

  fileprivate var title: LocalizedStringKey {
    switch self {
    case .dateAscending: "Date Ascending"
    case .dateDescending: "Date Descending"
    case .shuffle: "Shuffle"
    }
  }

  fileprivate var iconName: String {
    switch self {
    case .dateAscending: "arrow.up"
    case .dateDescending: "arrow.down"
    case .shuffle: "shuffle"
    }
  }
}

#if DEBUG
private let imageDetailsFactoryMock: ImageDetailsFactory = { _, source in
  makeImageDetailsModel(
    modelImage: .mock,
    remote: Remote { _ in .mock },
    openSource: source,
    favoritesModel: .mock,
    showOnMap: { _ in },
    canOpenURL: { _ in false },
    urlOpener: { _ in },
    setOrientationLock: { _ in },
    streetViewAvailability: .mock(.unavailable),
    translate: .mock("translated text"),
    extractModelImage: { _ in .mock }
  )
}

#Preview {
  @Previewable @State
  var store = makeImageListModel(
    title: "Images",
    matchedTransitionSourceName: "",
    images: (0..<10).map { idx in
      modified(.mock) {
        let year = Int.random(in: 1826...1995)
        let year2 = year + Int.random(in: 0...5)
        $0.date = ImageDate(
          year: year,
          year2: year2
        )
        $0.cid = idx
      }
    },
    listUpdates: .empty,
    imageDetailsFactory: imageDetailsFactoryMock,
    sorting: .constant(.dateAscending)
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
    imageDetailsFactory: imageDetailsFactoryMock,
    sorting: .constant(.dateAscending)
  ).viewStore

  ImageList(viewStore: store)
}
#endif
