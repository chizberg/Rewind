//
//  MapControls.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 22. 11. 2025.
//

import SwiftUI

struct MapControls: View {
  let mapStore: MapViewModel.Store
  let appStore: AppModel.Store
  let namespace: Namespace.ID
  let hasBottomSafeAreaInset: Bool

  @State
  private var offset: CGFloat = 0
  @State
  private var pullingProgress: CGFloat = 0
  @Environment(\.horizontalSizeClass)
  private var horizontalSizeClass

  var body: some View {
    VStack(alignment: .leading) {
      expandableControls
        .if(horizontalSizeClass == .regular) {
          $0.frame(maxWidth: 450)
        }
        .padding(.horizontal, 25)
        .padding(.bottom, 2)
        .offset(y: offset)

      MapControlsGlassContainer(
        hasBottomSafeAreaInset: hasBottomSafeAreaInset,
        radius: glassCardRadius
      ) {
        content
      }
      .overlay(alignment: .top) { cardToPull }
      .offset(y: offset)
      .minimizable(
        contentHeight: glassCardHeight,
        state: appStore.binding(
          \.mapControls.minimization, send: { .mapControls(.setMinimization($0)) }
        ),
        offset: $offset,
        glimpseHeight: 100,
        pullingProgress: $pullingProgress,
        minPullLength: 300,
        onPull: { appStore(.imageList(.presentCurrentRegionImages(
          source: RootView.TransitionSource.pullUpCard
        )))
        }
      )
    }
    .animation(
      .interactiveSpring(duration: 0.3, extraBounce: 0.1, blendDuration: 1),
      value: offset
    )
  }

  private var expandableControls: some View {
    ExpandableControls(
      yearRange: mapStore.binding(\.yearRange, send: { .yearRangeChanged($0) }),
      mapType: mapStore.binding(\.mapType, send: { .mapTypeSelected($0) }),
      staticItems: [
        ExpandableControls.StaticItem(
          id: "search",
          iconName: "magnifyingglass",
          transitionSource: (id: RootView.TransitionSource.search, namespace: namespace)
        ) {
          appStore(.search(.present))
        },
        ExpandableControls.StaticItem(
          id: "location",
          iconName: mapStore.locationState.isAccessGranted
            ? "location" : "location.slash"
        ) {
          mapStore(.locationButtonTapped)
        },
      ]
    )
  }

  private var cardToPull: some View {
    VStack {
      Spacer().frame(
        height: glassCardHeight + makeBottomPadding(
          hasBottomSafeAreaInset: hasBottomSafeAreaInset
        )
      )

      ZStack(alignment: .top) {
        makeGlassBackground(radius: glassCardRadius)

        RoundedRectangle(cornerRadius: glassCardRadius)
          .fill(Color.systemBackground.opacity(pullingProgress))

        HStack {
          Image(systemName: "list.bullet")
          Text("Pull to view images as list")
        }
        .opacity(0.7)
        .padding()
      }
      .matchedTransitionSource(
        id: RootView.TransitionSource.pullUpCard,
        in: namespace
      )
      .padding(.horizontal, containerPadding)
      .frame(height: 700)
    }
  }

  private var content: some View {
    AutoscrollingScrollView(scrollOnChangeOf: mapStore.previews) {
      horizontalScrollContent
        .padding(.horizontal, glassCardPadding)
    }
    .frame(height: thumbnailSize.height)
    .animation(.spring().speed(2), value: mapStore.previews)
    .padding(.vertical, glassCardPadding)
    .overlay(alignment: .topTrailing) {
      if mapStore.isLoading {
        ProgressView()
          .progressViewStyle(.circular)
          .padding(glassCardPadding + 5)
      }
    }
    .animation(.default, value: mapStore.isLoading)
  }

  private var horizontalScrollContent: some View {
    LazyHStack(spacing: 8) {
      VStack {
        makeBottomScrollButton(
          iconName: "star",
          sourceID: RootView.TransitionSource.favoritesButton
        ) {
          appStore(.imageList(.presentFavorites(
            source: RootView.TransitionSource.favoritesButton
          )))
        }

        makeBottomScrollButton(
          iconName: "list.bullet",
          sourceID: RootView.TransitionSource.viewAsListButton,
          action: {
            appStore(.imageList(.presentCurrentRegionImages(
              source: RootView.TransitionSource.viewAsListButton
            )))
          }
        )

        makeBottomScrollButton(
          iconName: "gearshape",
          sourceID: RootView.TransitionSource.settings
        ) {
          appStore(.settings(.present))
        }
      }.frame(width: 75)

      ForEach(mapStore.previews) { card in
        let transitionID = "\(card.id) \(RootView.TransitionSource.thumbnail)"
        ThumbnailCardView(
          card: card,
          size: thumbnailSize,
          radius: mapControlRadius
        )
        .matchedTransitionSource(
          id: transitionID,
          in: namespace
        )
        .cornerRadius(mapControlRadius) // for transitions
        .onTapGesture {
          switch card {
          case let .image(image):
            appStore(.imageDetails(.present(
              image,
              source: RootView.TransitionSource.thumbnail
            )))
          case .viewAsList:
            appStore(.imageList(.presentCurrentRegionImages(
              source: transitionID
            )))
          case .noImages: break
          }
        }
        .transition(.scale)
      }
    }
  }

  private func makeBottomScrollButton(
    iconName: String,
    sourceID: String,
    action: @escaping () -> Void
  ) -> some View {
    ZStack {
      MapControlBackground(radius: mapControlRadius)

      Image(systemName: iconName)
        .font(.title2.bold())
    }
    .matchedTransitionSource(id: sourceID, in: namespace)
    .cornerRadius(mapControlRadius)
    .onTapGesture(perform: action)
  }
}

extension MapControls {
  // height of controls that covers the map under it
  static let blockingHeight = glassCardHeight + makeBottomPadding(hasBottomSafeAreaInset: true)
}

struct MapControlBackground: View {
  @Environment(\.colorScheme)
  var colorScheme
  var radius: CGFloat

  var body: some View {
    RoundedRectangle(
      cornerRadius: radius
    ).fill(Color(uiColor: .mapControlBackground))
  }
}

extension UIColor {
  fileprivate static var mapControlBackground = UIColor(dynamicProvider: { trait in
    switch trait.userInterfaceStyle {
    case .dark: .black.withAlphaComponent(0.3)
    case .light, .unspecified: fallthrough
    @unknown default: .white.withAlphaComponent(0.6)
    }
  })
}

private struct MapControlsGlassContainer<Content: View>: View {
  @ViewBuilder
  var content: () -> Content
  var radius: CGFloat
  var insets: EdgeInsets

  init(
    hasBottomSafeAreaInset: Bool,
    radius: CGFloat,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.content = content
    self.radius = radius
    let bottomPadding = makeBottomPadding(hasBottomSafeAreaInset: hasBottomSafeAreaInset)
    insets = EdgeInsets(
      top: 0,
      leading: containerPadding,
      bottom: bottomPadding,
      trailing: containerPadding
    )
  }

  var body: some View {
    content()
      .background {
        ZStack {
          makeGlassBackground(radius: radius)

          Rectangle().fill(.primary.opacity(0.05))
        }
      }
      .overlay(alignment: .top) {
        RoundedRectangle(cornerRadius: 2)
          .fill(Color.primary.opacity(0.3))
          .frame(width: 60, height: 4)
          .padding(.top, 6)
      }
      .clipShape(RoundedRectangle(cornerRadius: radius))
      .padding(insets)
      .shadow(color: .black.opacity(0.2), radius: 30, y: 40)
  }
}

private struct AutoscrollingScrollView<Value: Equatable, Content: View>: View {
  var value: Value
  var content: Content

  private let leadingEdge = 0

  init(
    scrollOnChangeOf value: Value,
    @ViewBuilder content: () -> Content
  ) {
    self.value = value
    self.content = content()
  }

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 0) {
          // Empty view to scroll to (including paddings)
          Color.clear.frame(width: 0, height: 0).id(leadingEdge)
          content
        }
      }
      .onChange(of: value) {
        withAnimation {
          proxy.scrollTo(leadingEdge, anchor: .leading)
        }
      }
    }
  }
}

private func makeBottomPadding(hasBottomSafeAreaInset: Bool) -> CGFloat {
  let iOS18HomeBarHeight: CGFloat = 21
  return if #available(iOS 26, *) {
    containerPadding
  } else {
    hasBottomSafeAreaInset ? iOS18HomeBarHeight : containerPadding
  }
}

@ViewBuilder
private func makeGlassBackground(radius: CGFloat) -> some View {
  if #available(iOS 26, *) {
    GlassView(radius: radius)
  } else {
    BlurView(style: .systemThinMaterial, radius: radius)
  }
}

private let thumbnailSize = CGSize(width: 250, height: 187.5)
private let containerPadding: CGFloat = 8
private let mapControlRadius: CGFloat = 25
private let glassCardPadding: CGFloat = 20
private let glassCardHeight = thumbnailSize.height + glassCardPadding * 2
private let glassCardRadius = max(
  DeviceModel.getCurrent().screenRadius() - containerPadding,
  32
)

#if DEBUG
#Preview {
  @Previewable @State
  var mapStore = MapModel.makeMock { initialState in
    initialState.previews = [
      .image(.mock),
      .noImages,
      .viewAsList,
    ]
  }.viewStore.bimap(
    state: { $0 },
    action: { .external(.ui($0)) }
  )
  @Previewable @State
  var appStore = AppModel.mock.viewStore
  @Previewable @Namespace
  var namespace

  ZStack(alignment: .bottom) {
    Color.blue

    MapControls(
      mapStore: mapStore,
      appStore: appStore,
      namespace: namespace,
      hasBottomSafeAreaInset: false
    )
  }.ignoresSafeArea()
}

#Preview("container") {
  ZStack(alignment: .bottom) {
    Color.clear

    MapControlsGlassContainer(
      hasBottomSafeAreaInset: true,
      radius: 35
    ) {
      Color.yellow
        .frame(height: 300)
    }
  }
}
#endif
