//
//  ImageDetailsView.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 9. 11. 2025.
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
      .sheet(viewStore.binding(\.shareVC, send: { _ in .shareSheetDismissed }))
      .fullScreenCover(
        item: viewStore.binding(\.comparisonDeps, send: { _ in .comparison(.dismiss) }),
        content: { identified in
          let deps = identified.value
          ComparisonScreen(
            deps: deps
          ).modify { view in
            switch deps.store.captureMode {
            case .camera:
              view.navigationTransition(.zoom(
                sourceID: TransitionSource.compareCameraButton,
                in: namespace
              ))
            case .streetView:
              view
            }
          }
        }
      )
      .fullScreenCover(
        item: viewStore.binding(\.fullscreenPreview, send: { _ in
          .fullscreenPreview(.dismiss)
        }),
        content: { identifiedImage in
          ZoomableImageScreen(
            image: identifiedImage.value,
            saveImage: { viewStore(.fullscreenPreview(.saveImage)) }
          )
          .navigationTransition(.zoom(sourceID: TransitionSource.titleImage, in: namespace))
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
    .matchedTransitionSource(id: TransitionSource.titleImage, in: namespace)
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
        Text(viewStore.attributedTitle)
          .font(.title.bold())

        HStack {
          ImageDateView(date: viewStore.image.date)

          if let direction = viewStore.image.dir {
            DirectionView(date: viewStore.image.date, direction: direction)
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
    .ifLet(spec.transitionSource) { view, sourceID in
      view.matchedTransitionSource(id: sourceID, in: namespace)
    }
    .if(action == .route) {
      $0.confirmationDialog(
        "Select map app to find route",
        isPresented: viewStore.binding(
          \.mapOptionsPresented,
          send: { .setMapOptionsVisibility($0) }
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

private enum TransitionSource {
  static let titleImage = "fullscreenPreview"
  static let compareCameraButton = "compareCameraButton"
}

private let visibleActions: [ImageDetailsAction.Button] = Array.build {
  ImageDetailsAction.Button.favorite
  withUIIdiom(phone: ImageDetailsAction.Button.compareCamera, pad: nil)
  withUIIdiom(phone: ImageDetailsAction.Button.compareStreetView, pad: nil)
  [ImageDetailsAction.Button.showOnMap, .share, .saveImage, .viewOnWeb, .route]
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

private struct ButtonSpec {
  var title: LocalizedStringKey
  var iconName: String
  var foreground: SwiftUI.Color
  var background: SwiftUI.Color
  var transitionSource: String?

  init(
    button: ImageDetailsAction.Button,
    isFavorite: Bool,
    isImageSaved: Bool
  ) {
    title = switch button {
    case .favorite: "Favorite"
    case .compareCamera: "Compare"
    case .compareStreetView: "Compare with Google Street View"
    case .showOnMap: "Show on map"
    case .share: "Share"
    case .saveImage: "Save image"
    case .viewOnWeb: "View on Web"
    case .route: "Find route"
    }

    iconName = switch button {
    case .favorite: isFavorite ? "star.fill" : "star"
    case .compareCamera: "camera.viewfinder"
    case .compareStreetView: "pano"
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
    case .showOnMap, .share, .viewOnWeb, .route, .compareCamera, .compareStreetView: .primary
    }

    background = switch button {
    case .favorite: isFavorite ? .yellow.mix(with: .black, by: 0.1) : .systemBackground
    case .saveImage: isImageSaved ? .green.mix(with: .black, by: 0.1) : .systemBackground
    case .showOnMap, .share, .viewOnWeb, .route, .compareCamera,
         .compareStreetView: .systemBackground
    }

    transitionSource = switch button {
    case .compareCamera: TransitionSource.compareCameraButton
    case .compareStreetView: nil // zoom gesture conflicts with matched transition
    case .favorite, .showOnMap, .share, .saveImage, .viewOnWeb, .route:
      nil
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
    openSource: "",
    favoriteModel: .mock,
    showOnMap: { _ in },
    canOpenURL: { _ in true },
    urlOpener: { _ in },
    setOrientationLock: { _ in },
    streetViewAvailability: .mock(.unavailable)
  ).viewStore

  ImageDetailsView(
    viewStore: store
  )
}

#Preview("loading") {
  @Previewable @State
  var store = makeImageDetailsModel(
    modelImage: modified(.mock) {
      $0.image = $0.image.delayed(delay: 2)
    },
    remote: Remote {
      try await Task.sleep(for: .seconds(1))
      return Model.ImageDetails(.mock)
    },
    openSource: "",
    favoriteModel: .mock,
    showOnMap: { _ in },
    canOpenURL: { _ in true },
    urlOpener: { _ in },
    setOrientationLock: { _ in },
    streetViewAvailability: .mock(.unavailable)
  ).viewStore

  ImageDetailsView(
    viewStore: store
  )
}
#endif
