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
  struct LoadableDetails {
    // making attributed strings is slow, should be done once in model
    var description: AttributedString?
    var source: AttributedString?
    var address: AttributedString?
    var author: AttributedString?
    var username: String
  }

  // Model.Image fields
  var date: ImageDate
  var title: AttributedString
  var direction: Direction?
  var cid: Int

  var details: LoadableDetails?

  var uiImage: UIImage?
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
  modelImage: Model.Image,
  load: Remote<Void, Model.ImageDetails>,
  image: LoadableUIImage,
  coordinate: Coordinate,
  favoriteModel: SingleFavoriteModel,
  canOpenURL: @escaping (URL) -> Bool,
  urlOpener: @escaping (URL) -> Void
) -> ImageDetailsModel {
  Reducer(
    initial: ImageDetailsState(
      date: modelImage.date,
      title: modelImage.title.makeAttrString(),
      direction: modelImage.dir,
      cid: modelImage.cid,
      details: nil,
      uiImage: nil,
      isFavorite: favoriteModel.state,
      shareVC: nil,
      mapOptionsPresented: false
    ),
    reduce: { state, action, enqueueEffect in
      switch action {
      case .willBePresented:
        enqueueEffect(.perform { anotherAction in
          let data = try await load()
          await anotherAction(.dataLoaded(data))
        })
        enqueueEffect(.perform { anotherAction in
          let img = try await image(.high)
          await anotherAction(.imageLoaded(img))
        })
      case let .dataLoaded(data):
        state.details = ImageDetailsState.LoadableDetails(
          description: data.description?.makeAttrString(),
          source: data.source?.makeAttrString(),
          address: data.address?.makeAttrString(),
          author: data.author?.makeAttrString(),
          username: data.username
        )
      case let .imageLoaded(image):
        state.uiImage = image
      case .button(.viewOnWeb):
        var components = URLComponents()
        components.scheme = "https"
        components.host = "pastvu.com"
        components.path = "/\(state.cid)"
        if let url = components.url {
          urlOpener(url)
        }
      case .button(.favorite):
        state.isFavorite.toggle()
        favoriteModel(state.isFavorite)
      case .button(.saveImage):
        enqueueEffect(.anotherAction(.internal(.saveImage)))
      case .button(.share):
        guard let details = state.details,
              let image = state.uiImage
        else { return }
        enqueueEffect(.perform { [title = state.title] anotherAction in
          let vc = await UIActivityViewController(
            activityItems: [
              image,
              "\(title), \(details.description ?? "")",
            ],
            applicationActivities: nil
          )
          await anotherAction(.internal(.shareSheetLoaded(vc)))
        })
      case .button(.route):
        enqueueEffect(.anotherAction(.setMapOptionsVisibility(false)))
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
        if let image = state.uiImage {
          state.fullscreenPreview = Identified(value: image)
        }
      case .fullscreenPreview(.dismiss):
        state.fullscreenPreview = nil
      case .fullscreenPreview(.saveImage):
        enqueueEffect(.anotherAction(.internal(.saveImage)))
      case .internal(.saveImage):
        guard let image = state.uiImage else { return }
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
