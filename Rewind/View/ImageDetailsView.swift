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
      item: Binding(
        get: { state.shareVC },
        set: { if $0 == nil { model(.shareSheetDismissed) }}
      ),
      content: { vc in
        ViewControllerRepresentable {
          vc.value
        }
      }
    )
    .confirmationDialog(
      "Select map app to find route", // TODO: localization
      isPresented: Binding(
        get: { state.mapOptionsPresented },
        set: { model(.setMapOptionsVisibility($0)) }
      ),
      titleVisibility: .visible,
      actions: {
        ForEach(MapApp.allCases, id: \.self) { app in
          Button(app.name, action: { model(.mapAppSelected(app)) })
        }
      }
    )
  }

  private var closeButton: some View {
    SquishyButton(action: { dismiss() }) { _ in
      Image(systemName: "chevron.left")
        .padding(10)
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
      LazyVStack(spacing: 0) {
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
    LazyVGrid(columns: [.init(.adaptive(minimum: 200))]) {
      ForEach(visibleActions, id: \.self) {
        makeButton(action: $0)
      }
    }
  }

  private func makeButton(action: ImageDetailsAction.Button) -> some View {
    let foreground: SwiftUI.Color = switch action {
    case .favorite: isFavorite ? .red : .primary
    case .share, .saveImage, .viewOnWeb, .route: .primary
    }
    let background: SwiftUI.Color = .systemBackground
    let pressedForeground: SwiftUI.Color = switch action {
    case .favorite: .white
    case .share, .saveImage, .viewOnWeb, .route: .primary
    }
    let pressedBackground: SwiftUI.Color = switch action {
    case .favorite: .red
    case .share, .saveImage, .viewOnWeb, .route: .secondaryBackground
    }
    let title: LocalizedStringKey = switch action {
    case .favorite: "Favorite"
    case .share: "Share"
    case .saveImage: "Save image"
    case .viewOnWeb: "View on Web"
    case .route: "Find route"
    }
    let iconName: String = switch action {
    case .favorite: isFavorite ? "heart.fill" : "heart"
    case .share: "square.and.arrow.up"
    case .saveImage: "square.and.arrow.down"
    case .viewOnWeb: "globe.americas.fill"
    case .route: "map"
    }
    return SquishyButton(action: { actionHandler(.button(action)) }) { pressed in
      HStack {
        Image(systemName: iconName)
        Text(title)
          .lineLimit(1)
        Spacer()
      }
      .foregroundStyle(pressed ? pressedForeground : foreground)
      .padding(10)
      .frame(minHeight: 50)
      .background(pressed ? pressedBackground : background)
      .cornerRadius(10)
    }
  }

  private var detailsView: some View {
    LazyVStack(alignment: .leading, spacing: 10) {
      title

      if let description = details.description {
        Text(description.makeAttrString())
          .font(.body)
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

private let visibleActions: [ImageDetailsAction.Button] = [
  .favorite,
  .share,
  .saveImage,
  .viewOnWeb,
  .route,
]

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
  var label: LocalizedStringKey
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
      coordinate: Model.ImageDetails(.mock).coordinate,
      isFavorite: previewFavorite,
      canOpenURL: { _ in true },
      urlOpener: { _ in }
    )
  )
}

private var previewFavorite: Property<Bool> = {
  var favorite = false
  return Property(getter: { favorite }, setter: { favorite = $0 })
}()
#endif
