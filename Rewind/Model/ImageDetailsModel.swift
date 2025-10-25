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
  var fullscreenPreview: Identified<UIImage>?
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

  enum FullscreenPreview {
    case present
    case dismiss
    case saveImage
  }

  enum Internal {
    case saveImage
    case shareSheetLoaded(UIViewController)
  }

  case button(Button)
  case fullscreenPreview(FullscreenPreview)
  case `internal`(Internal)
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
    reduce: { state, action, enqueueEffect in
      switch action {
      case .willBePresented:
        enqueueEffect(.regular { anotherAction in
          let data = try await load()
          await anotherAction(.dataLoaded(data))
        })
        enqueueEffect(.regular { anotherAction in
          let img = try await image(.high)
          await anotherAction(.imageLoaded(img))
        })
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
        enqueueEffect(.regular { anotherAction in
          await anotherAction(.internal(.saveImage))
        })
      case .button(.share):
        guard let data = state.data,
              let image = state.image
        else { return }
        let itemsToShare = [
          image,
          "\(data.title), \(data.description ?? "")",
        ]
        enqueueEffect(.regular { anotherAction in
          let vc = await UIActivityViewController(
            activityItems: itemsToShare,
            applicationActivities: nil
          )
          await anotherAction(.internal(.shareSheetLoaded(vc)))
        })
      case .button(.route):
        enqueueEffect(.regular { anotherAction in
          await anotherAction(.setMapOptionsVisibility(false))
        })
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
      case .fullscreenPreview(.present):
        if let image = state.image {
          state.fullscreenPreview = Identified(value: image)
        }
      case .fullscreenPreview(.dismiss):
        state.fullscreenPreview = nil
      case .fullscreenPreview(.saveImage):
        enqueueEffect(.regular { anotherAction in
          await anotherAction(.internal(.saveImage))
        })
      case .internal(.saveImage):
        guard let image = state.image else { return }
        UIImageWriteToSavedPhotosAlbum(
          image,
          nil,
          nil,
          nil
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
      case let .internal(.shareSheetLoaded(vc)):
        state.shareVC = Identified(value: vc)
      }
    }
  )
}
