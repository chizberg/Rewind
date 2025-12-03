//
//  ImageDetailsModel.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 08.02.2025.
//

import Foundation
import Photos
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
  var cachedLowResImage: UIImage?
  var isImageSaved: Bool
  var openSource: String
  var isFavorite: Bool
  var shareVC: Identified<UIViewController>?
  var mapOptionsPresented: Bool
  var fullscreenPreview: Identified<UIImage>?
  var alertModel: Identified<AlertParams>?
}

enum ImageDetailsAction {
  case willBePresented
  case dataLoaded(Model.ImageDetails)
  case cachedLowResImageLoaded(UIImage)
  case imageLoaded(UIImage)

  enum Button {
    case favorite
    case showOnMap
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
    case imageSaved
    case shareSheetLoaded(UIViewController)
  }

  enum Alert {
    case present(AlertParams?)
    case dismiss
  }

  case button(Button)
  case fullscreenPreview(FullscreenPreview)
  case alert(Alert)
  case `internal`(Internal)
  case shareSheetDismissed
  case setMapOptionsVisibility(Bool)
  case mapAppSelected(MapApp)
}

func makeImageDetailsModel(
  modelImage: Model.Image,
  remote: Remote<Void, Model.ImageDetails>,
  image: LoadableUIImage,
  coordinate: Coordinate,
  openSource: String,
  favoriteModel: SingleFavoriteModel,
  showOnMap: @escaping (Coordinate) -> Void,
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
      cachedLowResImage: nil,
      isImageSaved: false,
      openSource: openSource,
      isFavorite: favoriteModel.state,
      shareVC: nil,
      mapOptionsPresented: false
    ),
    reduce: { state, action, enqueueEffect in
      switch action {
      case .willBePresented:
        enqueueEffect(.perform { anotherAction in
          do {
            let data = try await remote.load()
            await anotherAction(.dataLoaded(data))
          } catch {
            await anotherAction(.alert(.present(.error(
              title: "Unable to load image info",
              error: error
            ))))
          }
        })
        enqueueEffect(.perform { anotherAction in
          do {
            let medium = try await image.load(
              ImageLoadingParams(
                quality: .medium,
                cachedOnly: true
              )
            )
            await anotherAction(.cachedLowResImageLoaded(medium))
          } catch {}
        })
        enqueueEffect(.perform { anotherAction in
          do {
            let img = try await image.load(.high)
            await anotherAction(.imageLoaded(img))
          } catch {
            await anotherAction(.alert(.present(.error(
              title: "Unable to load image in high resolution",
              error: error
            ))))
          }
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
      case let .cachedLowResImageLoaded(image):
        state.cachedLowResImage = image
      case let .alert(alert):
        switch alert {
        case let .present(alertParams):
          guard let alertParams else { return }
          state.alertModel = Identified(value: alertParams)
        case .dismiss:
          state.alertModel = nil
        }
      case let .button(button):
        switch button {
        case .viewOnWeb:
          var components = URLComponents()
          components.scheme = "https"
          components.host = "pastvu.com"
          components.path = "/\(state.cid)"
          if let url = components.url {
            urlOpener(url)
          }
        case .favorite:
          state.isFavorite.toggle()
          enqueueEffect(.perform { [isFavorite = state.isFavorite] _ in
            await favoriteModel(isFavorite)
            await UIImpactFeedbackGenerator(style: .light).impactOccurred()
          })
        case .showOnMap:
          showOnMap(modelImage.coordinate)
        case .saveImage:
          enqueueEffect(.anotherAction(.internal(.saveImage)))
        case .share:
          guard let details = state.details,
                let image = state.uiImage
          else { return }
          enqueueEffect(.perform { [title = state.title] anotherAction in
            let vc = await UIActivityViewController(
              activityItems: [
                image,
                [
                  String(title.characters),
                  details.description.map { String($0.characters) },
                ].compactMap(\.self).joined(separator: "\n"),
              ],
              applicationActivities: nil
            )
            await anotherAction(.internal(.shareSheetLoaded(vc)))
          })
        case .route:
          enqueueEffect(.anotherAction(.setMapOptionsVisibility(true)))
        }
      case .shareSheetDismissed:
        state.shareVC = nil
      case let .setMapOptionsVisibility(visible):
        state.mapOptionsPresented = visible
      case let .mapAppSelected(app):
        if let link = app.coordinateLink(
          latitude: coordinate.latitude,
          longitude: coordinate.longitude
        ),
          canOpenURL(link) {
          urlOpener(link)
        } else {
          UINotificationFeedbackGenerator().notificationOccurred(.error)
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
        enqueueEffect(.perform { anotherAction in
          do {
            let library = PHPhotoLibrary.shared()
            try await library.performChanges {
              PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            await anotherAction(.internal(.imageSaved))
          } catch {
            await anotherAction(.alert(.present(.error(
              title: "Unable to save image",
              error: error
            ))))
          }
        })
      case .internal(.imageSaved):
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        state.isImageSaved = true
      case let .internal(.shareSheetLoaded(vc)):
        state.shareVC = Identified(value: vc)
      }
    }
  )
}
