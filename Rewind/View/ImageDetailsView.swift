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
      if let data = state.data, let image = state.image {
        ImageDetailsViewImpl(
          details: data,
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
  var details: Model.ImageDetails
  var image: UIImage
  var actionHandler: (ImageDetailsAction) -> Void

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 10) {
        titleImage

        LazyVStack(alignment: .leading, spacing: 10) {
          title

          if let description = details.description {
            Text(description.makeAttrString())
              .font(.body)
          }

          HStack {
            // todo: localized string
            LabeledText(label: "uploaded by", value: details.username)
            Spacer()
            if let author = details.author {
              // todo: localized string
              LabeledText(label: "author", value: author)
              Spacer()
            }
          }

          if let source = details.source {
            // todo: localized string
            LabeledText(label: "source", value: source)
          }
          if let address = details.address {
            // todo: localized string
            LabeledText(label: "address", value: address)
          }
        }.padding(.horizontal)
      }.textSelection(.enabled)
    }
  }

  private var title: some View {
    HStack {
      VStack(alignment: .leading, spacing: 5) {
        Text(details.title.makeAttrString())
          .font(.title.bold())


        HStack(spacing: 20) {
          Text(details.date.description)
            .font(.title3.bold())

          DirectionIndicator(direction: details.direction)
        }
        .foregroundStyle(Color(uiColor: UIColor.from(year: details.date.year)))
      }
      Spacer(minLength: 0)
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
    HStack(spacing: 5) {
      Text(direction?.rawValue.uppercased() ?? "")
        .font(.title3.bold().monospaced())
      Image(systemName: "arrowtriangle.up.fill")
        .resizable()
        .frame(width: 8, height: 10)
        .rotationEffect(.radians(angle ?? 0))
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
        .opacity(0.5)
      Text(value.makeAttrString())
        .font(.body)
        .textSelection(.enabled)
    }
  }
}

extension String {
  fileprivate func makeAttrString() -> AttributedString {
    let nsAttrString = NSAttributedString(html: self) ?? NSAttributedString(string: self)
    return AttributedString(nsAttrString)
  }
}

extension NSAttributedString {
  fileprivate convenience init?(html: String) {
    guard let data = html.data(using: .utf8) else { return nil }

    guard let mutableAttrStr = try? NSMutableAttributedString(
      data: data,
      options: [
        .documentType: NSAttributedString.DocumentType.html,
        .characterEncoding: String.Encoding.utf8.rawValue
      ],
      documentAttributes: nil
    ) else { return nil }

    let fullRange = NSRange(
      location: 0,
      length: mutableAttrStr.length
    )

    mutableAttrStr.removeAttribute(
      .font,
      range: fullRange
    )
    mutableAttrStr.removeAttribute(
      .foregroundColor,
      range: fullRange
    )
    self.init(attributedString: mutableAttrStr)
  }
}


#if DEBUG
fileprivate func makeImageDetailsView(
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
#endif
