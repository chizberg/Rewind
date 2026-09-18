//
//  ImageDetailsView.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 9. 11. 2025.
//

import SwiftUI
import VGSL

struct ImageDetailsView: View {
  enum TransitionSource {
    static let titleImage = "fullscreenPreview"
    static let compareCameraButton = "compareCameraButton"
    static let descriptionLink = "descriptionLink"
    static let colorizeButton = "colorizeButton"
  }

  var viewStore: ImageDetailsModel.Store

  @Namespace
  private var namespace
  @Environment(\.horizontalSizeClass)
  private var horizontalSizeClass
  @State
  private var colorizeButtonFrame = CGRect.zero
  @State
  private var pictureFrame = CGRect.zero

  private var isSplitView: Bool { horizontalSizeClass == .regular }

  var body: some View {
    content
      .animation(.smooth, value: viewStore.translationState)
      .overlay(alignment: .topLeading) {
        HStack {
          DismissButton()

          Spacer()

          if let state = viewStore.colorizationState.button {
            ColorizeButton(
              namespace: namespace,
              state: state,
            ) {
              viewStore(.colorize)
            }
            .readFrame(in: .named(spaceName)) { colorizeButtonFrame = $0 }
            .transition(.scale)
          }

          if isSplitView {
            Spacer()
              .frame(width: splitViewScrollWidth)
          }
        }
        .padding()
        .animation(.spring, value: viewStore.colorizationState)
      }
      .coordinateSpace(.named(spaceName))
      .task {
        viewStore(.willBePresented)
      }
      .sheet(viewStore.binding(\.shareVC, send: { _ in .shareSheetDismissed }))
      .fullScreenCover(
        item: viewStore.binding(\.comparisonDeps, send: { _ in .comparison(.dismiss) }),
        content: { identified in
          let deps = identified.value
          ComparisonScreen(
            deps: deps,
          ).modify { view in
            switch deps.store.captureMode {
            case .camera:
              view.navigationTransition(.zoom(
                sourceID: TransitionSource.compareCameraButton,
                in: namespace,
              ))
            case .streetView:
              view
            }
          }
        },
      )
      .fullScreenCover(
        item: viewStore.binding(\.fullscreenPreview, send: { _ in
          .fullscreenPreview(.dismiss)
        }),
        content: { identifiedImage in
          ZoomableImageScreen(
            image: identifiedImage.value,
            savesCount: viewStore.imageSaveCount,
            saveImage: { viewStore(.fullscreenPreview(.saveImage)) },
          )
          .navigationTransition(.zoom(sourceID: TransitionSource.titleImage, in: namespace))
        },
      )
      .fullScreenCover(
        item: viewStore.binding(\.anotherImageModel, send: { _ in .anotherImage(.dismiss) }),
        content: { anotherImage in
          let store = anotherImage.value
          ImageDetailsView(viewStore: store)
            .navigationTransition(
              .zoom(
                sourceID: store.openSource,
                in: namespace,
              ),
            )
        },
      )
      .sheet(
        item: viewStore.binding(\.colorizationPicker, send: { _ in .colorizationPicker(.dismiss) }),
        content: { picker in
          ColorizationPickerScreen(store: picker.value)
            .overlay(alignment: .topLeading) {
              DismissButton().padding()
            }
            .navigationTransition(
              .zoom(sourceID: TransitionSource.colorizeButton, in: namespace),
            )
            .environment(\.dismissButtonKind, .close)
        },
      )
      .alert(
        Binding(
          get: { viewStore.alertModel },
          set: { _ in viewStore(.alert(.dismiss)) },
        ),
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
          .frame(width: splitViewScrollWidth)
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
      SwiftUI.Color.secondarySystemBackground.edgesIgnoringSafeArea(
        isSplitView ? .bottom : .vertical,
      )
    }
  }

  private var picture: some View {
    ZStack {
      if let image = viewStore.uiImage {
        Image(uiImage: image)
          .resizable()
          .overlay {
            if let colorized = viewStore.colorizedImage {
              Image(uiImage: colorized)
                .resizable()
            }
          }
          .overlay {
            MagicOverlay(
              image: image,
              origin: CGPoint(
                x: colorizeButtonFrame.midX - pictureFrame.minX,
                y: colorizeButtonFrame.midY - pictureFrame.minY,
              ),
              isActive: viewStore.isColorizing,
              tuning: .default,
            )
          }
          .readFrame(in: .named(spaceName)) { pictureFrame = $0 }
          .animation(.default, value: viewStore.colorizationState)
      } else {
        if let cachedPreview = viewStore.cachedLowResImage {
          Image(uiImage: cachedPreview)
            .resizable()
        } else {
          SwiftUI.Color.clear
        }

        ProgressView()
          .scaleEffect(1.5)
      }
    }
    .scaledToFit()
    .onTapGesture { showFullscreenPreview() }
    .gesture(
      MagnificationGesture(minimumScaleDelta: 1.3)
        .onChanged { _ in showFullscreenPreview() },
    )
    .matchedTransitionSource(id: TransitionSource.titleImage, in: namespace)
  }

  private var textDetails: some View {
    VStack(alignment: .leading, spacing: 10) {
      title

      if let attrDetails = viewStore.attributedDetails, let details = viewStore.details {
        if let desc = attrDetails.description {
          makeDescription(desc: desc)
            .animation(.smooth, value: viewStore.loadingAnotherImage)
        }

        HStack(alignment: .top) {
          LabeledText(label: "uploaded by", value: AttributedString(details.username))
          Spacer()
          if let author = attrDetails.author {
            LabeledText(label: "author", value: author)
            Spacer()
          }
        }

        if let source = attrDetails.source {
          LabeledText(label: "source", value: source)
        }
        if let address = attrDetails.address {
          LabeledText(label: "address", value: address)
        }
      } else {
        ProgressView()
      }
    }
    .textSelection(.enabled)
  }

  @ViewBuilder
  private func makeDescription(desc: AttributedString) -> some View {
    let disabled = viewStore.loadingAnotherImage
      || viewStore.translationState == .translating

    VStack(alignment: .leading, spacing: 3) {
      Text(viewStore.translation?.description ?? desc)
        .font(.body)
        .matchedTransitionSource(id: TransitionSource.descriptionLink, in: namespace)
        .environment(\.openURL, OpenURLAction {
          viewStore(.descriptionLink($0))
          return .handled
        })
        .blur(radius: disabled ? 7 : 0)
        .allowsHitTesting(!disabled)
        .overlay {
          if disabled {
            ProgressView()
          }
        }

      switch viewStore.translationState {
      case .available:
        TextAccessoryButton("Translate") { viewStore(.translate) }
      case .translated:
        TextAccessoryButton("Show Original") { viewStore(.showTranslationOriginal) }
      case .translating, .notAvailable:
        EmptyView()
      }
    }
  }

  private var title: some View {
    HStack {
      VStack(alignment: .leading, spacing: 5) {
        Text(viewStore.translation?.title ?? viewStore.attributedTitle)
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
      isImageSaved: viewStore.isImageSaved,
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
          send: { .setMapOptionsVisibility($0) },
        ),
        titleVisibility: .visible,
        actions: {
          ForEach(MapApp.allCases, id: \.self) { app in
            Button(app.name, action: { viewStore(.mapAppSelected(app)) })
          }
        },
      )
    }
  }

  private var actionButtons: some View {
    TwoColumnLayout {
      ForEach(viewStore.actionButtons, id: \.self) {
        makeButton(action: $0)
      }
    }
  }

  private func showFullscreenPreview() {
    guard viewStore.fullscreenPreview == nil,
          viewStore.displayedImage != nil
    else {
      return
    }
    viewStore(.fullscreenPreview(.present))
  }
}

private let splitViewScrollWidth = 325.0
private let spaceName = "image-details"

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
    isImageSaved: Bool,
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
    case .compareCamera: ImageDetailsView.TransitionSource.compareCameraButton
    case .compareStreetView: nil // zoom gesture conflicts with matched transition
    case .favorite, .showOnMap, .share, .saveImage, .viewOnWeb, .route:
      nil
    }
  }
}

private struct TextAccessoryButton: View {
  var title: LocalizedStringKey
  var action: () -> Void

  init(_ title: LocalizedStringKey, action: @escaping () -> Void) {
    self.title = title
    self.action = action
  }

  var body: some View {
    Button(action: action, label: {
      Text(title)
        .font(.caption.smallCaps())
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
          Capsule().fill(SwiftUI.Color.secondarySystemBackground)
        }
    }).foregroundStyle(.primary)
  }
}

private struct ColorizeButton: View {
  enum State: String, CaseIterable {
    case available
    case colorizing
    case done
  }

  var namespace: Namespace.ID
  var state: State
  var action: () -> Void

  var shadowExposure = 2.0
  var rainbowShadowDuration = 2.0
  var rainbowShadowRotationDuration = 1.0

  @State
  private var showsRainbow = false
  @State
  private var rainbowAngle = Angle.zero
  @ScaledMetric(relativeTo: .title2)
  private var radius = 44

  @Environment(\.colorScheme)
  private var colorScheme

  var body: some View {
    Button(action: action, label: {
      content
        .frame(squareSize: radius)
        .transition(.blurReplace)

    })
    .matchedTransitionSource(
      id: ImageDetailsView.TransitionSource.colorizeButton,
      in: namespace
    )
    .clipShape(Circle())
    .blurBackground(in: Circle())
    .background {
      if showsRainbow {
        makeRainbow(exposure: shadowExposure)
          .clipShape(Circle())
          .blur(radius: 10)
          .rotationEffect(rainbowAngle)
          .scaleEffect(1.3)
      }
    }
    .animation(.default, value: showsRainbow)
    .animation(.default, value: state)
    .task {
      showsRainbow = true
      withAnimation(
        .linear(duration: rainbowShadowRotationDuration)
          .repeatForever(autoreverses: false)
      ) {
        rainbowAngle = .degrees(360)
      }
      try? await Task.sleep(for: .seconds(rainbowShadowDuration))
      showsRainbow = false
      rainbowAngle = .degrees(0)
    }
  }

  @ViewBuilder
  private var content: some View {
    switch state {
    case .available:
      Text("🎨")
        .font(.title2)
        .shadow(
          color: .white.opacity(colorScheme == .dark ? 0.7 : 0),
          radius: 10
        )
    case .colorizing:
      ProgressView()
    case .done:
      ZStack {
        makeRainbow(exposure: 0)

        Image(systemName: "paintpalette.fill")
          .foregroundStyle(.white)
      }
    }
  }

  private func makeRainbow(exposure: CGFloat) -> some View {
    AngularGradient(
      gradient: makeRainbowGradient(exposureAdjust: exposure),
      center: .center
    )
  }
}

extension ImageDetailsState {
  fileprivate var translation: ImageDetailsState.Translation? {
    if case let .translated(translation) = translationState { translation } else { nil }
  }

  fileprivate var isColorizing: Bool {
    if case .colorizing = colorizationState { true } else { false }
  }
}

extension ImageDetailsState.ColorizationState {
  fileprivate var button: ColorizeButton.State? {
    switch self {
    case .available: .available
    case .colorizing: .colorizing
    case let .ready(_, showing):
      switch showing {
      case .colorized: .done
      case .original: .available
      }
    case .none, .detecting, .notAvailable:
      nil
    }
  }
}

func makeRainbowGradient(exposureAdjust: Double = 2.0) -> SwiftUI.Gradient {
  let colors = [
    SwiftUI.Color.red, .orange, .yellow, .green, .blue, .purple, .red
  ].map {
    if #available(iOS 26.0, *) {
      $0.exposureAdjust(exposureAdjust)
    } else {
      $0
    }
  }
  let stops = colors.enumerated().map { index, color in
    SwiftUI.Gradient.Stop(color: color, location: Double(index) / Double(colors.count - 1))
  }
  return SwiftUI.Gradient(stops: stops)
}

#if DEBUG
extension FavoritesModel {
  static var mock: FavoritesModel {
    Reducer(
      initial: [],
      reduce: { _, _, _, _ in },
    )
  }
}

#Preview("instant") {
  @Previewable @State
  var store = makeImageDetailsModel(
    modelImage: .mock,
    remote: Remote { _ in Model.ImageDetails(.mock) },
    cachedDetails: nil,
    openSource: "",
    favoritesModel: .mock,
    showOnMap: { _ in },
    canOpenURL: { _ in true },
    urlOpener: { _ in },
    streetViewAvailability: .mock(.unavailable),
    translate: .mock("translated text"),
    colorizationModel: .constant(nil),
    extractModelImage: { _ in .mock },
    makeColorizationPicker: { _ in .mock(.mock) },
  ).viewStore

  ImageDetailsView(
    viewStore: store,
  )
}

#Preview("loading") {
  @Previewable @State
  var store = makeImageDetailsModel(
    modelImage: modified(.mock) {
      $0.image = $0.image.delayed(delay: 2)
    },
    remote: Remote { _ in
      try await Task.sleep(for: .seconds(1))
      return Model.ImageDetails(.mock)
    },
    cachedDetails: nil,
    openSource: "",
    favoritesModel: .mock,
    showOnMap: { _ in },
    canOpenURL: { _ in true },
    urlOpener: { _ in },
    streetViewAvailability: .mock(.unavailable),
    translate: .mock("translated text").delayed(delay: 1),
    colorizationModel: .constant(nil),
    extractModelImage: { _ in .mock },
    makeColorizationPicker: { _ in .mock(.mock) },
  ).viewStore

  ImageDetailsView(
    viewStore: store,
  )
}

#Preview("text accessory button") {
  TextAccessoryButton("Translate", action: { print("foo") })
}

#Preview("colorize button") {
  ColorizationButtonPreview()
}

private struct ColorizationButtonPreview: View {
  @State
  var isShown = true
  @State
  var duration = 4.0
  @State
  var exposure = 2.0
  @State
  var buttonState = ColorizeButton.State.available
  @Namespace
  var namespace

  var body: some View {
    VStack {
      let action = {
        withAnimation {
          isShown.toggle()
        }
      }

      ZStack {
        Image(.lyskovo)
          .resizable()
          .aspectRatio(contentMode: .fit)

        if isShown {
          ColorizeButton(
            namespace: namespace,
            state: buttonState,
            action: action,
            shadowExposure: exposure,
            rainbowShadowDuration: duration
          )
          .transition(.scale)
        }
      }

      Button(action: action) {
        Text("toggle")
      }.buttonStyle(.bordered)
        .padding(.bottom, 20)

      Text("exposure \(exposure)")
      Slider(value: $exposure, in: 0...5)
        .padding(.bottom, 10)

      Text("duration \(duration)")
      Slider(value: $duration, in: 0...10)

      Picker("", selection: $buttonState, content: {
        ForEach(ColorizeButton.State.allCases, id: \.self) { s in
          Text(s.rawValue).tag(s)
        }
      })
      .pickerStyle(.segmented)
    }.padding()
  }
}

#endif
