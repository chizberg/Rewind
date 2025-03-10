//
//  ImageList.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 19.2.25..
//

import SwiftUI
import VGSL

struct ImageList<EmptyLabel: View>: View {
  var title: LocalizedStringKey
  var images: [Model.Image]
  var imageDetailsFactory: (Model.Image) -> ImageDetailsModel
  @ViewBuilder
  var emptyLabel: () -> EmptyLabel

  @State
  private var path = NavigationPath()

  @Environment(\.dismiss)
  var dismiss

  var body: some View {
    ZStack {
      BlurView().ignoresSafeArea()

      NavigationStack(path: $path) {
        Group {
          if !images.isEmpty {
            ScrollView {
              LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 10) {
                items
              }
            }
          } else {
            ZStack {
              Color.clear
              emptyLabel()
            }
          }
        }
        .navigationTitle(title)
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            backButton
          }
        }
        .navigationDestination(for: Model.Image.self) { image in
          makeImageDetails(for: image)
        }
      }
    }
  }

  private var items: some View {
    ForEach(images) { image in
      SquishyButton {
        path.append(image)
      } label: { _ in
        ImageListCell(value: image)
      }.padding(.horizontal, 16)
    }
  }

  private var backButton: some View {
    SquishyButton {
      dismiss()
    } label: { _ in
      Image(systemName: "chevron.left")
    }.foregroundStyle(.tint)
  }

  private func makeImageDetails(for image: Model.Image) -> some View {
    let model = imageDetailsFactory(image)
    return ImageDetailsView(
      model: model,
      state: model.$state.asObservedVariable(),
      showCloseButton: false
    )
  }
}

#Preview {
  ImageList(
    title: "Images",
    images: (0..<10).map { idx in
      modified(.mock) { $0.cid = idx }
    },
    imageDetailsFactory: { image in
      makeImageDetailsModel(
        load: Remote { .mock },
        image: .mock,
        coordinate: image.coordinate,
        isFavorite: .constant(true),
        canOpenURL: { _ in false },
        urlOpener: { _ in }
      )
    },
    emptyLabel: { EmptyView() }
  )
}

#Preview("empty") {
  ImageList(
    title: "Images",
    images: [],
    imageDetailsFactory: { image in
      makeImageDetailsModel(
        load: Remote { .mock },
        image: .mock,
        coordinate: image.coordinate,
        isFavorite: .constant(true),
        canOpenURL: { _ in false },
        urlOpener: { _ in }
      )
    },
    emptyLabel: { Text("nothing here") }
  )
}
