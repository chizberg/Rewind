//
//  ImageDetailsView.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 9. 11. 2025..
//

import SwiftUI
import VGSL

struct ImageDetailsView: View {
  var viewStore: ImageDetailsModel.Store

  @Namespace
  private var namespace
  @Environment(\.horizontalSizeClass)
  private var horizontalSizeClass

  private var isSplitView: Bool { horizontalSizeClass == .regular }

  var body: some View {
    content
      .overlay(alignment: .topLeading) {
        BackButton()
          .padding()
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
      .alert(
        Binding(
          get: { viewStore.alertModel },
          set: { _ in viewStore(.alert(.dismiss)) }
        )
      )
  }

  @ViewBuilder
  private var content: some View {
    if isSplitView {
      HStack(spacing: 0) {
        ZStack {
          Rectangle().fill(.black).ignoresSafeArea()
          picture
        }
        scroll
          .frame(width: 325)
      }
    } else {
      scroll
    }
  }

  private var scroll: some View {
    ScrollView {
      VStack(spacing: 0) {
        if !isSplitView {
          picture
        }
        textDetails
          .padding()
          .background {
            Rectangle().fill(.background).ignoresSafeArea()
          }
        actionButtons
          .padding()
      }
    }
    .background {
      Color.secondarySystemBackground.edgesIgnoringSafeArea(
        isSplitView ? .bottom : .vertical
      )
    }
  }

  private var picture: some View {
    ZStack {
      if let uiImage = viewStore.uiImage {
        Image(uiImage: uiImage)
          .resizable()
      } else {
        if let cachedPreview = viewStore.cachedLowResImage {
          Image(uiImage: cachedPreview)
            .resizable()
        } else {
          Color.clear
        }

        ProgressView()
          .scaleEffect(1.5)
      }
    }
    .aspectRatio(contentMode: .fit)
    .onTapGesture { showFullscreenPreview() }
    .gesture(
      MagnificationGesture(minimumScaleDelta: 1.3)
        .onChanged { _ in showFullscreenPreview() }
    )
    .matchedTransitionSource(id: titleImageID, in: namespace)
  }

  private var textDetails: some View {
    VStack(alignment: .leading, spacing: 10) {
      title

      if let details = viewStore.details {
        if let description = details.description {
          Text(description)
            .font(.body)
        }

        HStack(alignment: .top) {
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

        HStack {
          ImageDateView(date: viewStore.date)

          if let direction = viewStore.direction {
            DirectionView(date: viewStore.date, direction: direction)
          }
        }
      }
      Spacer(minLength: 0)
    }
  }

  @ViewBuilder
  private func makeButton(action: ImageDetailsAction.Button) -> some View {
    let spec = ButtonSpec(
      button: action,
      isFavorite: viewStore.isFavorite,
      isImageSaved: viewStore.isImageSaved
    )
    Button {
      viewStore(.button(action))
    } label: {
      HStack {
        Image(systemName: spec.iconName)
        Text(spec.title)
          .lineLimit(1)
        Spacer()
      }
      .padding(10)
      .frame(minHeight: 50)
    }
    .foregroundStyle(spec.foreground)
    .background(spec.background)
    .cornerRadius(15)
    .if(action == .route) {
      $0.confirmationDialog(
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
    }
  }

  private var actionButtons: some View {
    TwoColumnLayout {
      ForEach(visibleActions, id: \.self) {
        makeButton(action: $0)
      }
    }
  }

  private func showFullscreenPreview() {
    guard viewStore.fullscreenPreview == nil,
          viewStore.uiImage != nil
    else {
      return
    }
    viewStore(.fullscreenPreview(.present))
  }
}

private let titleImageID = "fullscreenPreview"
private let visibleActions: [ImageDetailsAction.Button] = [
  .favorite,
  .showOnMap,
  .share,
  .saveImage,
  .viewOnWeb,
  .route,
]

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

private struct ButtonSpec {
  var title: LocalizedStringKey
  var iconName: String
  var foreground: SwiftUI.Color
  var background: SwiftUI.Color

  init(
    button: ImageDetailsAction.Button,
    isFavorite: Bool,
    isImageSaved: Bool
  ) {
    title = switch button {
    case .favorite: "Favorite"
    case .showOnMap: "Show on map"
    case .share: "Share"
    case .saveImage: "Save image"
    case .viewOnWeb: "View on Web"
    case .route: "Find route"
    }

    iconName = switch button {
    case .favorite: isFavorite ? "star.fill" : "star"
    case .showOnMap: "mappin.and.ellipse"
    case .share: "square.and.arrow.up"
    case .saveImage: isImageSaved
      ? "square.and.arrow.down.badge.checkmark"
      : "square.and.arrow.down"
    case .viewOnWeb: "globe.americas.fill"
    case .route: "point.bottomleft.forward.to.arrow.triangle.scurvepath.fill"
    }

    foreground = switch button {
    case .favorite: isFavorite ? .white : .primary
    case .saveImage: isImageSaved ? .white : .primary
    case .showOnMap, .share, .viewOnWeb, .route: .primary
    }

    background = switch button {
    case .favorite: isFavorite ? .yellow.mix(with: .black, by: 0.1) : .systemBackground
    case .saveImage: isImageSaved ? .green.mix(with: .black, by: 0.1) : .systemBackground
    case .showOnMap, .share, .viewOnWeb, .route: .systemBackground
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
    remote: Remote { Model.ImageDetails(.mock) },
    image: .mock,
    coordinate: Model.Image.mock.coordinate,
    openSource: "",
    favoriteModel: .mock,
    showOnMap: { _ in },
    canOpenURL: { _ in true },
    urlOpener: { _ in }
  ).viewStore

  ImageDetailsView(
    viewStore: store
  )
}

#Preview("loading") {
  @Previewable @State
  var store = makeImageDetailsModel(
    modelImage: .mock,
    remote: Remote {
      try await Task.sleep(for: .seconds(1))
      return Model.ImageDetails(.mock)
    },
    image: LoadableUIImage { _ in
      try await Task.sleep(for: .seconds(2))
      return UIImage(named: "cat")!
    },
    coordinate: Model.Image.mock.coordinate,
    openSource: "",
    favoriteModel: .mock,
    showOnMap: { _ in },
    canOpenURL: { _ in true },
    urlOpener: { _ in }
  ).viewStore

  ImageDetailsView(
    viewStore: store
  )
}
#endif
