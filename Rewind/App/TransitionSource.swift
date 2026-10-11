//
//  TransitionSource.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 26. 9. 2026..
//

import SwiftUI

enum TransitionSource: Hashable {
  enum Image: Hashable {
    case thumbnail(Int)
    case annotation(Int)
    case listRow(Int)
    case link
  }

  enum ImageList {
    case favoritesButton
    case viewAsListButton
    case pullUpCard
    case thumbnail

    case clusterAnnotation
  }

  case imageList(ImageList)
  case image(TransitionSource.Image)

  case fullscreenPreview
  case compareCamera

  case searchButton
  case settingsButton
  case colorizeButton

  #if DEBUG
  case mock
  #endif
}

extension EnvironmentValues {
  @Entry
  var rootNamespace: Namespace.ID?
}

@propertyWrapper
struct RootNamespace: DynamicProperty {
  @Environment(\.rootNamespace)
  private var root
  @Namespace
  private var fallback

  var wrappedValue: Namespace.ID {
    root ?? fallback
  }
}

extension View {
  func zoomed(
    from source: TransitionSource,
    namespace: Namespace.ID
  ) -> some View {
    navigationTransition(.zoom(sourceID: source, in: namespace))
  }

  func zoomTransitionSource(_ source: TransitionSource) -> some View {
    ZoomSource(source: source, content: self)
  }

  func zoomTransitionSource(
    _ source: TransitionSource,
    namespace: Namespace.ID
  ) -> some View {
    matchedTransitionSource(id: source, in: namespace)
  }
}
