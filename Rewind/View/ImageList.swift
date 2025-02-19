//
//  ImageList.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 19.2.25..
//

import SwiftUI
import VGSL

struct ImageList: View {
  var title: LocalizedStringKey
  var images: [Model.Image]
  var imageDetailsFactory: (Model.Image) -> ImageDetailsModel

  @State
  private var path = NavigationPath()

  @Environment(\.dismiss)
  var dismiss

  var body: some View {
    ZStack {
      BlurView().ignoresSafeArea()

      NavigationStack(path: $path) {
        ScrollView {
          LazyVStack(spacing: 10) {
            items
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
    }
  )
}
