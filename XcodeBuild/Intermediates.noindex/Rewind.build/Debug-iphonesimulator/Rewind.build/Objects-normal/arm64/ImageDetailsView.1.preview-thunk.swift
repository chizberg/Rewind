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

struct ImageDetailsView: View {
  @State
  var model: ImageDetailsModel
  @State @ObservedVariable
  var state: ImageDetailsState

  @Environment(\.dismiss)
  var dismiss

  init(
    model: ImageDetailsModel,
    state: ObservedVariable<ImageDetailsState>
  ) {
    self.model = model
    _state = State(wrappedValue: state)
  }

  var body: some View {
    ZStack {
      if let data = state.data, let image = state.image {
        ImageDetailsViewImpl(
          details: data,
          image: image,
          isFavorite: state.isFavorite,
          actionHandler: model.callAsFunction
        )
      } else {
        ProgressView()
          .controlSize(.large)
      }

      ZStack(alignment: .topLeading) {
        Color.clear

        closeButton
          .padding()
      }
    }
    .background(Color.secondaryBackground)
    .task {
      model(.willBePresented)
    }
    .sheet(
      isPresented: Binding(
        get: { !state.itemsToShare.isEmpty },
        set: { if !$0 { model(.shareSheetDismissed) }}
      ),
      content: {
        ViewControllerRepresentable {
          UIActivityViewController(
            activityItems: state.itemsToShare,
            applicationActivities: nil
          )
        }
      }
    )
  }

  private var closeButton: some View {
    SquishyButton(action: { dismiss() }) { _ in
      Image(systemName: __designTimeString("#7675_0", fallback: "chevron.left"))
        .padding(__designTimeInteger("#7675_1", fallback: 10))
        .background(.thinMaterial)
        .clipShape(Circle())
    }
  }
}

private struct ImageDetailsViewImpl: View {
  var details: Model.ImageDetails
  var image: UIImage
  var isFavorite: Bool
  var actionHandler: (ImageDetailsAction) -> Void

  var body: some View {
    ScrollView {
      LazyVStack(spacing: __designTimeInteger("#7675_2", fallback: 0)) {
        titleImage

        detailsView.padding()
          .background(.background)
          .textSelection(.enabled)

        actions
          .padding()
      }
    }
  }

  private var actions: some View {
    LazyVGrid(columns: [.init(.adaptive(minimum: __designTimeInteger("#7675_3", fallback: 150)))]) {
      ForEach(visibleActions, id: \.self) {
        makeButton(action: $0)
      }
    }
  }

  private func makeButton(action: ImageDetailsAction.Button) -> some View {
    let foreground: Color = switch action {
    case .favorite: .red
    case .route: .green
    case .share, .saveImage, .viewOnWeb: .primary
    }
    let background: Color = .systemBackground
    let pressedForeground: Color = switch action {
    case .favorite, .route: .white
    case .share, .saveImage, .viewOnWeb: .primary
    }
    let pressedBackground: Color = switch action {
    case .favorite: .red
    case .route: .green
    case .share, .saveImage, .viewOnWeb: .secondaryBackground
    }
    // todo: localization
    let title: String = switch action {
    case .favorite: __designTimeString("#7675_4", fallback: "Favorite")
    case .share: __designTimeString("#7675_5", fallback: "Share")
    case .saveImage: __designTimeString("#7675_6", fallback: "Save image")
    case .viewOnWeb: __designTimeString("#7675_7", fallback: "View on Web")
    case .route: __designTimeString("#7675_8", fallback: "Find route")
    }
    let iconName: String = switch action {
    case .favorite: isFavorite ? __designTimeString("#7675_9", fallback: "heart.fill") : __designTimeString("#7675_10", fallback: "heart")
    case .share: __designTimeString("#7675_11", fallback: "square.and.arrow.up")
    case .saveImage: __designTimeString("#7675_12", fallback: "square.and.arrow.down")
    case .viewOnWeb: __designTimeString("#7675_13", fallback: "globe.americas.fill")
    case .route: __designTimeString("#7675_14", fallback: "map")
    }
    return SquishyButton(action: { actionHandler(.button(action)) }) { pressed in
      HStack {
        Image(systemName: iconName)
        Text(title)
        Spacer()
      }
      .foregroundStyle(pressed ? pressedForeground : foreground)
      .padding(__designTimeInteger("#7675_15", fallback: 10))
      .frame(minHeight: __designTimeInteger("#7675_16", fallback: 50))
      .background(pressed ? pressedBackground : background)
      .cornerRadius(__designTimeInteger("#7675_17", fallback: 10))
    }
  }

  private var detailsView: some View {
    LazyVStack(alignment: .leading, spacing: __designTimeInteger("#7675_18", fallback: 10)) {
      title

      if let description = details.description {
        Text(description.makeAttrString())
          .font(.body)
      }

      HStack {
        // todo: localized string
        LabeledText(label: __designTimeString("#7675_19", fallback: "uploaded by"), value: details.username)
        Spacer()
        if let author = details.author {
          // todo: localized string
          LabeledText(label: __designTimeString("#7675_20", fallback: "author"), value: author)
          Spacer()
        }
      }

      if let source = details.source {
        // todo: localized string
        LabeledText(label: __designTimeString("#7675_21", fallback: "source"), value: source)
      }
      if let address = details.address {
        // todo: localized string
        LabeledText(label: __designTimeString("#7675_22", fallback: "address"), value: address)
      }
    }
  }

  private var title: some View {
    HStack {
      VStack(alignment: .leading, spacing: __designTimeInteger("#7675_23", fallback: 5)) {
        Text(details.title.makeAttrString())
          .font(.title.bold())


        HStack(spacing: __designTimeInteger("#7675_24", fallback: 20)) {
          Text(details.date.description)
            .font(.title3.bold())

          DirectionIndicator(direction: details.direction)
        }
        .foregroundStyle(Color(uiColor: UIColor.from(year: details.date.year)))
      }
      Spacer(minLength: __designTimeInteger("#7675_25", fallback: 0))
    }
  }

  private var titleImage: some View {
    Image(uiImage: image)
      .resizable()
      .aspectRatio(contentMode: .fit)
  }
}

private let visibleActions: [ImageDetailsAction.Button] = [
  .favorite,
  .share,
  .saveImage,
  .viewOnWeb,
  .route
]

private struct DirectionIndicator: View {
  let direction: Direction?

  var body: some View {
    HStack(spacing: __designTimeInteger("#7675_26", fallback: 5)) {
      Text(direction?.rawValue.uppercased() ?? __designTimeString("#7675_27", fallback: ""))
        .font(.title3.bold().monospaced())
      Image(systemName: __designTimeString("#7675_28", fallback: "arrowtriangle.up.fill"))
        .resizable()
        .frame(width: __designTimeInteger("#7675_29", fallback: 8), height: __designTimeInteger("#7675_30", fallback: 10))
        .rotationEffect(.radians(angle ?? __designTimeInteger("#7675_31", fallback: 0)))
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
        .opacity(__designTimeFloat("#7675_32", fallback: 0.5))
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
      image: .mock,
      urlOpener: { _ in }
    )
  )
}
#endif
