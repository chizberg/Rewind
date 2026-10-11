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

  enum ImageList: Hashable {
    case favoritesButton
    case viewAsListButton
    case pullUpCard
    case thumbnail

    case clusterAnnotation
    case localCluster(UUID)
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
