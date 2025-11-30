//
//  MapControls.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 22. 11. 2025..
//

import SwiftUI

import BezelKit

struct MapControls: View {
  let mapStore: MapViewModel.Store
  let appStore: AppModel.Store
  let namespace: Namespace.ID
  let hasBottomSafeAreaInset: Bool

  var body: some View {
    VStack {
      ExpandableControls(
        yearRange: mapStore.binding(\.yearRange, send: { .yearRangeChanged($0) }),
        mapType: mapStore.binding(\.mapType, send: { .mapTypeSelected($0) }),
        staticItems: [
          .init(
            id: "location",
            iconName: mapStore.locationState.isAccessGranted
              ? "location" : "location.slash"
          ) {
            mapStore(.locationButtonTapped)
          },
        ]
      )
      .padding(.horizontal, 25)
      .padding(.bottom, 2)

      MapControlsGlassContainer(
        hasBottomSafeAreaInset: hasBottomSafeAreaInset
      ) { content }
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

  @ViewBuilder
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

private let glassCardPadding: CGFloat = 20

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
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.content = content
    radius = max(CGFloat.deviceBezel - containerPadding, 32)
    let bottomPadding: CGFloat = if #available(iOS 26, *) {
      containerPadding
    } else {
      hasBottomSafeAreaInset ? iOS18HomeBarHeight : containerPadding
    }
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
          if #available(iOS 26, *) {
            GlassView(radius: radius)
          } else {
            BlurView(style: .systemThinMaterial, radius: radius)
          }

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

private let thumbnailSize = CGSize(width: 250, height: 187.5)
private let containerPadding: CGFloat = 8
private let mapControlRadius: CGFloat = 25
private let iOS18HomeBarHeight: CGFloat = 21

#if DEBUG
#Preview {
  ZStack(alignment: .bottom) {
    Color.clear

    MapControlsGlassContainer(
      hasBottomSafeAreaInset: true
    ) {
      Color.yellow
        .frame(height: 300)
    }
  }
}
#endif
