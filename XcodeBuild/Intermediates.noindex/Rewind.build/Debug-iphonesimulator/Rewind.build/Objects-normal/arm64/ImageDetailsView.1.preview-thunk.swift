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

/*
 old impl

 var body: some View {
   VStack(alignment: .leading, spacing: 10) {
     VStack(alignment: .leading, spacing: 5) {
       Text(details.title.attrString)
         .font(.title)
         .bold()
         .textSelection(.enabled)

       HStack(spacing: 20) {
         Text(details.date.description)
           .font(.title3)
           .bold()
           .textSelection(.enabled)
         DirectionIndicator(direction: details.dir)
       }
       .foregroundColor(yearColor)
       .brightness(colorScheme == .dark ? 0.3 : 0)
     }

     if let description = details.description {
       Text(description.attrString)
         .textSelection(.enabled)
     }

     HStack {
       LabeledText(label: "uploaded by", value: details.username)
       Spacer()
       if let author = details.author {
         LabeledText(label: "author", value: author)
         Spacer()
       }
     }

     if let source = details.source {
       LabeledText(label: "source", value: source)
     }
     if let address = details.address {
       LabeledText(label: "address", value: address)
     }
   }
 }
 */

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
      if let data = state.data, let image = state.image {
        ImageDetailsViewImpl(
          data: data,
          image: image,
          actionHandler: model.callAsFunction
        )
      } else {
        ProgressView()
          .controlSize(.large)
      }
    }.task {
      model(.willBePresented)
    }
  }
}

private struct ImageDetailsViewImpl: View {
  var data: Model.ImageDetails
  var image: UIImage
  var actionHandler: (ImageDetailsAction) -> Void

  var body: some View {
    ScrollView {
      LazyVStack() {
        titleImage

        title.padding(.horizontal)
      }
    }
  }

  private var title: some View {
    HStack {
      VStack(alignment: .leading, spacing: __designTimeInteger("#7675_0", fallback: 5)) {
        Text(data.title)
          .font(.title.bold())

        HStack(spacing: __designTimeInteger("#7675_1", fallback: 20)) {
          Text(data.date.description)
            .font(.title3.bold())

          DirectionIndicator(direction: data.direction)
        }
        .foregroundStyle(Color(uiColor: UIColor.from(year: data.date.year)))
      }
      Spacer(minLength: __designTimeInteger("#7675_2", fallback: 0))
    }
  }

  private var titleImage: some View {
    Image(uiImage: image)
      .resizable()
      .aspectRatio(contentMode: .fit)
  }
}

private struct DirectionIndicator: View {
  let direction: Direction?

  var body: some View {
    HStack(spacing: __designTimeInteger("#7675_3", fallback: 5)) {
      Text(direction?.rawValue.uppercased() ?? __designTimeString("#7675_4", fallback: ""))
        .font(.title3.bold().monospaced())
      Image(systemName: __designTimeString("#7675_5", fallback: "arrowtriangle.up.fill"))
        .resizable()
        .frame(width: __designTimeInteger("#7675_6", fallback: 8), height: __designTimeInteger("#7675_7", fallback: 10))
        .rotationEffect(.radians(angle ?? __designTimeInteger("#7675_8", fallback: 0)))
    }
  }

  private var angle: CGFloat? {
    direction?.angle
  }
}

private struct LabeledText: View {
  var label: String
  var value: String

  var body: some View {
    VStack(alignment: .leading) {
      Text(label)
        .font(.caption.monospaced().bold().smallCaps())
        .opacity(__designTimeFloat("#7675_9", fallback: 0.5))
      Text(value)
        .font(.body)
        .textSelection(.enabled)
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
      load: Remote { Model.ImageDetails(.mock) },
      image: .mock
    )
  )
}
