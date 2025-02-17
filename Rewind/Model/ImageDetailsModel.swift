//
//  ImageDetailsModel.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 08.02.2025.
//

import Foundation
import UIKit
import VGSL

typealias ImageDetailsModel = Reducer<ImageDetailsState, ImageDetailsAction>

struct ImageDetailsState {
  var data: Model.ImageDetails?
  var image: UIImage?
  var isFavorite: Bool
  var shareVC: Identified<UIViewController>?
  var mapOptionsPresented: Bool
}

enum ImageDetailsAction {
  case willBePresented
  case dataLoaded(Model.ImageDetails)
  case imageLoaded(UIImage)

  enum Button {
    case favorite
    case share
    case saveImage
    case viewOnWeb
    case route
  }

  case button(Button)
  case shareSheetLoaded(UIViewController)
  case shareSheetDismissed
  case setMapOptionsVisibility(Bool)
  case mapAppSelected(MapApp)
}

func makeImageDetailsModel(
  load: Remote<Void, Model.ImageDetails>,
  image: LoadableImage,
  coordinate: Coordinate,
  isFavorite: Property<Bool>,
  canOpenURL: @escaping (URL) -> Bool,
  urlOpener: @escaping (URL) -> Void
) -> ImageDetailsModel {
  Reducer(
    initial: ImageDetailsState(
      data: nil,
      image: nil,
      isFavorite: isFavorite.value,
      shareVC: nil,
      mapOptionsPresented: false
    ),
    reduce: { state, action, effect, loadEffect in
      switch action {
      case .willBePresented:
        loadEffect {
          try await .dataLoaded(load())
        }
        loadEffect {
          try await .imageLoaded(image(.high))
        }
      case let .dataLoaded(data):
        state.data = data
      case let .imageLoaded(image):
        state.image = image
      case .button(.viewOnWeb):
        guard let data = state.data else { return }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "pastvu.com"
        components.path = "/\(data.cid)"
        if let url = components.url {
          urlOpener(url)
        }
      case .button(.favorite):
        state.isFavorite.toggle()
        isFavorite.value = state.isFavorite
      case .button(.saveImage):
        guard let image = state.image else { return }
        UIImageWriteToSavedPhotosAlbum(
          image,
          nil,
          nil,
          nil
        )
      case .button(.share):
        guard let data = state.data,
              let image = state.image
        else { return }
        let itemsToShare = [
          image,
          "\(data.title), \(data.description ?? "")"
        ]
        loadEffect {
          let vc = await UIActivityViewController(
            activityItems: itemsToShare,
            applicationActivities: nil
          )
          return .shareSheetLoaded(vc)
        }
      case .button(.route):
        effect(.setMapOptionsVisibility(true))
      case let .shareSheetLoaded(vc):
        state.shareVC = Identified(id: UUID(), value: vc)
      case .shareSheetDismissed:
        state.shareVC = nil
      case let .setMapOptionsVisibility(visible):
        state.mapOptionsPresented = visible
      case let .mapAppSelected(app):
        guard let link = app.coordinateLink(
          latitude: coordinate.latitude,
          longitude: coordinate.longitude
        ) else { return }
        if canOpenURL(link) {
          urlOpener(link)
        } else if let downloadLink = app.downloadLink {
          urlOpener(downloadLink)
        }
      }
    }
  )
}
