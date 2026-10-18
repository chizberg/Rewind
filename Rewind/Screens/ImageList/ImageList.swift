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

  @State
  private var scrollPosition = ScrollPosition()
  @Environment(\.screenGeometry)
  private var screenGeometry

  var body: some View {
    content
      .animation(.default, value: viewStore.sorting)
      .navigationTitle(viewStore.title)
      .toolbar { toolbar }
  }

  @ViewBuilder
  private var content: some View {
    if !viewStore.images.isEmpty {
      ScrollView {
        let columnCount = columnCount
        let columns = (0..<columnCount).map { column in
          stride(from: column, to: viewStore.images.count, by: columnCount)
            .map { viewStore.images[$0] }
        }
        HStack(alignment: .top, spacing: spacing) {
          ForEach(columns.indices, id: \.self) { column in
            LazyVStack(spacing: spacing) {
              ForEach(columns[column]) { cell(image: $0) }
            }
            .padding(.top, column.isMultiple(of: 2) ? 0 : columnShift)
            .frame(maxWidth: .infinity, alignment: .top)
          }
        }
        .padding(.horizontal, 16)
      }
      .scrollPosition($scrollPosition)
      .onChange(of: viewStore.sorting) { _, _ in
        withAnimation {
          scrollPosition.scrollTo(edge: .top)
        }
      }
    } else {
      ZStack {
        SwiftUI.Color.clear
        VStack {
          Text("💔").font(.largeTitle)
          Text("Nothing here yet")
        }
      }
    }
  }

  private var columnCount: Int {
    guard let screenGeometry else {
      assertionFailure("ImageList is shown outside of a screen")
      return 2
    }
    let width = screenGeometry.size.width - screenGeometry.safeAreaInsets.horizontal.sum - 32
    return max(2, Int(((width + spacing) / (maxCardWidth + spacing)).rounded(.up)))
  }

  private func cell(image: Model.Image) -> some View {
    Button {
      viewStore(.presentImage(image))
    } label: {
      ImageCardView(image: image)
    }
    .foregroundStyle(.primary)
    .zoomTransitionSource(.image(.listRow(image.cid)))
  }

  @ToolbarContentBuilder
  private var toolbar: some ToolbarContent {
    if let sorting = viewStore.sorting {
      ToolbarItem(placement: .topBarTrailing) {
        Menu(content: {
          Picker(
            "Sorting",
            selection: Binding(
              get: { sorting },
              set: { viewStore(.setSorting($0)) },
            ),
            content: {
              ForEach(ImageSorting.allCases) {
                Label($0.title, systemImage: $0.iconName)
              }
            },
          )
        }, label: {
          Image(systemName: "arrow.up.arrow.down")
        })
      }
    }
  }
}

private let columnShift: CGFloat = 60
private let spacing: CGFloat = 10
private let maxCardWidth: CGFloat = 250

struct ToolbarBackButton: View {
  @Environment(\.dismiss)
  private var dismiss

  var body: some View {
    Button {
      dismiss()
    } label: {
      Label("Back", systemImage: "chevron.left")
    }
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
  let screenID = Screen.ID()
  let model = makeImageDetailsModel(
    modelImage: .mock,
    remote: Remote { _ in .mock },
    cachedDetails: nil,
    source: source,
    favoritesModel: .mock,
    showOnMap: { _ in },
    canOpenURL: { _ in false },
    urlOpener: { _ in },
    streetViewAvailability: .mock(.unavailable),
    translate: .mock("translated text"),
    colorizationModel: .constant(nil),
    extractModelImage: { _ in .mock },
    makeColorizationPicker: { _ in .mock(.mock) },
    pushScreen: { _ in },
    imageDetailsFactory: { _, _ in fatalError() },
    isLastScreen: .constant(true),
  )
  return Screen(.image(model.viewStore), id: screenID)
}

#Preview {
  @Previewable @State
  var store = makeImageListModel(
    title: "Images",
    source: .mock,
    images: (0..<10).map { idx in
      modified(.mock) {
        let year = Int.random(in: 1826...1995)
        let year2 = year + Int.random(in: 0...5)
        $0.date = ImageDate(
          year: year,
          year2: year2,
        )
        $0.cid = idx
      }
    },
    listUpdates: .empty,
    imageDetailsFactory: imageDetailsFactoryMock,
    sorting: .constant(.dateAscending),
    pushScreen: { _ in },
    isLastScreen: .constant(true),
  ).viewStore

  ImageList(viewStore: store)
    .environment(
      \.screenGeometry,
      ScreenGeometry(size: CGSize(width: 400, height: 800), safeAreaInsets: .zero)
    )
}

#Preview("empty") {
  @Previewable @State
  var store = makeImageListModel(
    title: "Images",
    source: .mock,
    images: [],
    listUpdates: .empty,
    imageDetailsFactory: imageDetailsFactoryMock,
    sorting: .constant(.dateAscending),
    pushScreen: { _ in },
    isLastScreen: .constant(true),
  ).viewStore

  ImageList(viewStore: store)
    .environment(
      \.screenGeometry,
      ScreenGeometry(size: CGSize(width: 400, height: 800), safeAreaInsets: .zero)
    )
}
#endif
