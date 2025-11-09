//
//  ImageDetailsView.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 9. 11. 2025..
//

import SwiftUI
import VGSL

struct ImageDetailsView: View {
  var viewStore: ViewStore<ImageDetailsState, ImageDetailsAction>
  var showCloseButton: Bool

  @Namespace
  private var namespace

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        picture
          .aspectRatio(contentMode: .fit)
          .onTapGesture { viewStore(.fullscreenPreview(.present)) }
          .matchedTransitionSource(id: titleImageID, in: namespace)
        textDetails
          .padding()
          .background(.background)
        actionButtons
          .padding()
      }
    }
    .background {
      Color.secondaryBackground.ignoresSafeArea()
    }
    .overlay(alignment: .topLeading) {
      if showCloseButton {
        BackButton()
          .padding()
      }
    }
    .task {
      viewStore(.willBePresented)
    }
    .sheet(
      item: Binding(
        get: { viewStore.shareVC },
        set: { if $0 == nil { viewStore(.shareSheetDismissed) }}
      ),
      content: { vc in
        ViewControllerRepresentable {
          vc.value
        }
      }
    )
    .confirmationDialog(
      "Select map app to find route",
      isPresented: Binding(
        get: { viewStore.mapOptionsPresented },
        set: { viewStore(.setMapOptionsVisibility($0)) }
      ),
      titleVisibility: .visible,
      actions: {
        ForEach(MapApp.allCases, id: \.self) { app in
          Button(app.name, action: { viewStore(.mapAppSelected(app)) })
        }
      }
    )
    .fullScreenCover(
      item: Binding(
        get: { viewStore.fullscreenPreview },
        set: { if $0 == nil { viewStore(.fullscreenPreview(.dismiss)) }}
      ),
      content: { identifiedImage in
        ZoomableImage(
          image: identifiedImage.value,
          saveImage: { viewStore(.fullscreenPreview(.saveImage)) }
        )
        .navigationTransition(.zoom(sourceID: titleImageID, in: namespace))
      }
    )
  }

  @ViewBuilder
  private var picture: some View {
    if let uiImage = viewStore.uiImage {
      Image(uiImage: uiImage)
        .resizable()
    } else {
      ZStack {
        Rectangle().fill(.background)
        ProgressView()
      }
    }
  }

  private var textDetails: some View {
    VStack(alignment: .leading, spacing: 10) {
      title

      if let details = viewStore.details {
        if let description = details.description {
          Text(description)
            .font(.body)
        }

        HStack {
          LabeledText(label: "uploaded by", value: AttributedString(details.username))
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
      } else {
        ProgressView()
      }
    }
    .textSelection(.enabled)
  }

  @ViewBuilder
  private var title: some View {
    HStack {
      VStack(alignment: .leading, spacing: 5) {
        Text(viewStore.title)
          .font(.title.bold())

        HStack(spacing: 20) {
          Text(viewStore.date.description)
            .font(.title3.bold())

          DirectionIndicator(direction: viewStore.direction)
        }
        .foregroundStyle(Color(uiColor: UIColor.from(year: viewStore.date.year)))
      }
      Spacer(minLength: 0)
    }
  }

  private func makeButton(action: ImageDetailsAction.Button) -> some View {
    Button {
      viewStore(.button(action))
    } label: {
      HStack {
        Image(systemName: action.iconName(isFavorite: viewStore.isFavorite))
        Text(action.title)
          .lineLimit(1)
        Spacer()
      }
      .padding(10)
      .frame(minHeight: 50)
    }
    .foregroundStyle(action.foreground(isFavorite: viewStore.isFavorite))
    .background(.background)
    .cornerRadius(10)
  }

  private var actionButtons: some View {
    LazyVGrid(columns: [.init(.adaptive(minimum: 175))]) {
      ForEach(visibleActions, id: \.self) {
        makeButton(action: $0)
      }
    }
  }
}

private let titleImageID = "fullscreenPreview"
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
  var value: AttributedString

  var body: some View {
    VStack(alignment: .leading) {
      Text(label)
        .font(.caption.monospaced().bold().smallCaps())
        .opacity(0.5)
      Text(value)
        .font(.body)
        .textSelection(.enabled)
    }
  }
}

extension ImageDetailsAction.Button {
  fileprivate func foreground(isFavorite: Bool) -> SwiftUI.Color {
    switch self {
    case .favorite: isFavorite ? .yellow : .primary
    case .share, .saveImage, .viewOnWeb, .route: .primary
    }
  }

  fileprivate var title: LocalizedStringKey {
    switch self {
    case .favorite: "Favorite"
    case .share: "Share"
    case .saveImage: "Save image"
    case .viewOnWeb: "View on Web"
    case .route: "Find route"
    }
  }

  fileprivate func iconName(isFavorite: Bool) -> String {
    switch self {
    case .favorite: isFavorite ? "star.fill" : "star"
    case .share: "square.and.arrow.up"
    case .saveImage: "square.and.arrow.down"
    case .viewOnWeb: "globe.americas.fill"
    case .route: "map"
    }
  }
}

#if DEBUG
extension SingleFavoriteModel {
  static var mock: SingleFavoriteModel {
    Reducer(
      initial: false,
      reduce: { current, new, _ in
        current = new
      }
    )
  }
}

#Preview("instant") {
  @Previewable @State
  var store = makeImageDetailsModel(
    modelImage: .mock,
    load: Remote { Model.ImageDetails(.mock) },
    image: .mock,
    coordinate: Model.Image.mock.coordinate,
    favoriteModel: .mock,
    canOpenURL: { _ in true },
    urlOpener: { _ in }
  ).viewStore

  ImageDetailsView(
    viewStore: store,
    showCloseButton: true
  )
}

#Preview("loading") {
  @Previewable @State
  var store = makeImageDetailsModel(
    modelImage: .mock,
    load: Remote {
      try await Task.sleep(for: .seconds(1))
      return Model.ImageDetails(.mock)
    },
    image: LoadableUIImage { _ in
      try await Task.sleep(for: .seconds(2))
      return UIImage(named: "cat")!
    },
    coordinate: Model.Image.mock.coordinate,
    favoriteModel: .mock,
    canOpenURL: { _ in true },
    urlOpener: { _ in }
  ).viewStore

  ImageDetailsView(
    viewStore: store,
    showCloseButton: true
  )
}
#endif
