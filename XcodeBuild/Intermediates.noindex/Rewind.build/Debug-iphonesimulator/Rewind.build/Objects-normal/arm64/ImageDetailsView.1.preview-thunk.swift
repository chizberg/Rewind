import func SwiftUI.__designTimeFloat
import func SwiftUI.__designTimeString
import func SwiftUI.__designTimeInteger
import func SwiftUI.__designTimeBoolean

#sourceLocation(file: "/Users/chizberg/Documents/Личные проекты/Rewind/Rewind/View/ImageDetailsView.swift", line: 1)
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
  @ObservedVariable
  var state: ImageDetailsState

  init(
    model: ImageDetailsModel,
    state: ObservedVariable<ImageDetailsState>
  ) {
    self.model = model
    _state = state
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
        RewindAsyncImage(data.image, .high) { loaded in
          Image(uiImage: loaded)
            .resizable()
            .aspectRatio(contentMode: .fit)
        } placeholder: {
          BlurView()
        }
        Text(data.title)
      }
    }
  }
}

func makeImageDetailsView(
  load: Remote<Void, Model.ImageDetails>
) -> ImageDetailsView {
  print(__designTimeString("#7675_0", fallback: "chzbrg remove me after image details ui is made"))
  let model = makeImageDetailsModel(load: load)
  return ImageDetailsView(
    model: model,
    state: model.$state.asObservedVariable()
  )
}

#Preview {
  makeImageDetailsView(load: Remote { _ in
    Model.ImageDetails(.mock, image: .mock)
  })
}
