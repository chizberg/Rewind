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

  var image: Model.Image
  var attributedTitle: AttributedString

  var details: LoadableDetails?

  var uiImage: UIImage?
  var cachedLowResImage: UIImage?
  var isImageSaved: Bool
  var openSource: String
  var isFavorite: Bool
  var mapOptionsPresented: Bool

  var fullscreenPreview: Identified<UIImage>?
  var comparisonDeps: Identified<ComparisonViewDeps>?
  var shareVC: Identified<UIViewController>?
  var alertModel: Identified<AlertParams>?
}

enum ImageDetailsAction {
  case willBePresented
  case dataLoaded(Model.ImageDetails)
  case cachedLowResImageLoaded(UIImage)
  case imageLoaded(UIImage)

  enum Button {
    case favorite
    case compare
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

  enum ImageComparison {
    case present
    case dismiss
  }

  enum Alert {
    case present(AlertParams?)
    case dismiss
  }

  case button(Button)
  case fullscreenPreview(FullscreenPreview)
  case comparison(ImageComparison)
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
  urlOpener: @escaping (URL) -> Void,
  setOrientationLock: @escaping ResultAction<OrientationLock?>
) -> ImageDetailsModel {
  Reducer(
    initial: ImageDetailsState(
      image: modelImage,
      attributedTitle: modelImage.title.makeAttrString(),
      details: nil,
      uiImage: nil,
      cachedLowResImage: nil,
      isImageSaved: false,
      openSource: openSource,
      isFavorite: favoriteModel.state,
      mapOptionsPresented: false,
      fullscreenPreview: nil,
      comparisonDeps: nil,
      shareVC: nil,
      alertModel: nil
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
      case let .comparison(comparisonAction):
        switch comparisonAction {
        case .present:
          guard let image = state.uiImage else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
          }
          setOrientationLock(.portrait)
          state.comparisonDeps = Identified(
            value: makeComparisonViewDeps(
              oldUIImage: image,
              oldImageData: modelImage
            )
          )
        case .dismiss:
          setOrientationLock(nil)
          state.comparisonDeps = nil
        }
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
          components.path = "/\(state.image.cid)"
          if let url = components.url {
            urlOpener(url)
          }
        case .favorite:
          state.isFavorite.toggle()
          enqueueEffect(.perform { [isFavorite = state.isFavorite] _ in
            favoriteModel(isFavorite)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
          })
        case .compare:
          enqueueEffect(.anotherAction(.comparison(.present)))
        case .showOnMap:
          showOnMap(modelImage.coordinate)
        case .saveImage:
          enqueueEffect(.anotherAction(.internal(.saveImage)))
        case .share:
          guard let details = state.details,
                let image = state.uiImage
          else { return }
          enqueueEffect(.perform { [title = state.attributedTitle] anotherAction in
            let item = ImageShareItem(
              image: image,
              text: String(title.characters)
            )
            let vc = UIActivityViewController(
              activityItems: [
                item,
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
            try await save(image: image)
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

func save(image: UIImage) async throws {
  let library = PHPhotoLibrary.shared()
  try await library.performChanges {
    PHAssetChangeRequest.creationRequestForAsset(from: image)
  }
}
