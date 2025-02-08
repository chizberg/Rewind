//
//  ImageDetailsView.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 08.02.2025.
//

import SwiftUI
import VGSL

struct ImageDetailsView: View {
  @State
  var model: ImageDetailsModel
  @State @ObservedVariable
  var state: ImageDetailsState

  init(
    model: ImageDetailsModel,
    state: ObservedVariable<ImageDetailsState>
  ) {
    self.model = model
    _state = State(wrappedValue: state)
  }

  var body: some View {
    Group {
      if let data = state.data {
        ImageDetailsViewImpl(
          data: data,
          actionHandler: model.callAsFunction
        )
      } else {
        ProgressView()
      }
    }.task {
      model(.willBePresented)
    }
  }
}

private struct ImageDetailsViewImpl: View {
  var data: Model.ImageDetails
  var actionHandler: (ImageDetailsAction) -> Void

  var body: some View {
    ScrollView {
      LazyVStack {
        image
        Text(data.title)
      }
    }
  }

  private var image: some View {
    RewindAsyncImage(data.image, .high) { loaded in
      Image(uiImage: loaded)
        .resizable()
        .aspectRatio(contentMode: .fit)
    } placeholder: {
      ZStack {
        BlurView()
          .aspectRatio(4/3, contentMode: .fit)
        ProgressView()
      }
    }
  }
}

func makeImageDetailsView(
  model: ImageDetailsModel
) -> ImageDetailsView {
  ImageDetailsView(
    model: model,
    state: model.$state.asObservedVariable()
  )
}

#Preview {
  makeImageDetailsView(
    model: makeImageDetailsModel(
      load: Remote { Model.ImageDetails(.mock, image: .mock) }
    )
  )
}
