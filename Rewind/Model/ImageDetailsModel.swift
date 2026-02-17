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
  // making attributed strings is slow, should be done once in model
  struct AttributedDetails {
    var description: AttributedString?
    var source: AttributedString?
    var address: AttributedString?
    var author: AttributedString?
  }

  struct Translation: Equatable {
    var title: AttributedString
    var description: AttributedString
  }

  enum TranslationState: Equatable {
    case notAvailable
    case available
    case translating
    case translated(Translation)
  }

  var image: Model.Image
  var attributedTitle: AttributedString

  var details: Model.ImageDetails?
  var attributedDetails: AttributedDetails?

  var uiImage: UIImage?
  var cachedLowResImage: UIImage?
  var isImageSaved: Bool
  var openSource: String
  var isFavorite: Bool
  var mapOptionsPresented: Bool
  var loadingAnotherImage: Bool

  var translationState: TranslationState
  var cachedTranslation: Translation?

  var fullscreenPreview: Identified<UIImage>?
  var comparisonDeps: Identified<ComparisonViewDeps>?
  var shareVC: Identified<UIViewController>?
  var anotherImageModel: Identified<ImageDetailsModel.Store>?
  var alertModel: Identified<AlertParams>?
  var actionButtons: [ImageDetailsAction.Button]
}

enum ImageDetailsAction {
  case willBePresented
  case cachedLowResImageLoaded(UIImage)
  case imageLoaded(UIImage)
  case descriptionLink(URL)

  enum Button {
    case favorite
    case compareCamera
    case compareStreetView
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
    case anotherImageLoadFailed(Error)
    case detailsLoaded(Model.ImageDetails)
    case translationComplete(ImageDetailsState.Translation)
    case translationFailed(Error)
  }

  enum ImageComparison {
    case present(ComparisonState.CaptureMode)
    case dismiss
  }

  enum AnotherImage {
    case present(Model.ImageDetails, String)
    case dismiss
  }

  enum Alert {
    case present(AlertParams?)
    case dismiss
  }

  case button(Button)
  case fullscreenPreview(FullscreenPreview)
  case comparison(ImageComparison)
  case anotherImage(AnotherImage)
  case alert(Alert)
  case `internal`(Internal)
  case shareSheetDismissed
  case setMapOptionsVisibility(Bool)
  case mapAppSelected(MapApp)
  case translate
  case showTranslationOriginal
}

func makeImageDetailsModel(
  modelImage: Model.Image,
  remote: Remote<Int, Model.ImageDetails>,
  openSource: String,
  favoritesModel: FavoritesModel,
  showOnMap: @escaping (Coordinate) -> Void,
  canOpenURL: @escaping (URL) -> Bool,
  urlOpener: @escaping (URL) -> Void,
  setOrientationLock: @escaping ResultAction<OrientationLock?>,
  streetViewAvailability: Remote<Coordinate, StreetViewAvailability>,
  translate: Remote<TranslateParams, String>,
  extractModelImage: @escaping (Model.ImageDetails) -> (Model.Image)
) -> ImageDetailsModel {
  let favoriteModel = favoritesModel.isFavorite(modelImage)
  return Reducer(
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
      loadingAnotherImage: false,
      translationState: .notAvailable,
      cachedTranslation: nil,
      fullscreenPreview: nil,
      comparisonDeps: nil,
      shareVC: nil,
      anotherImageModel: nil,
      alertModel: nil,
      actionButtons: Array.build {
        ImageDetailsAction.Button.favorite
        withUIIdiom(phone: ImageDetailsAction.Button.compareCamera, pad: nil)
        withUIIdiom(phone: ImageDetailsAction.Button.compareStreetView, pad: nil)
        [ImageDetailsAction.Button.showOnMap, .share, .saveImage, .viewOnWeb, .route]
      }
    ),
    reduce: { state, action, enqueueEffect in
      switch action {
      case .willBePresented:
        enqueueEffect(.perform { anotherAction in
          do {
            let data = try await remote.load(modelImage.cid)
            await anotherAction(.internal(.detailsLoaded(data)))
          } catch {
            await anotherAction(.alert(.present(.error(
              title: "Unable to load image info",
              error: error
            ))))
          }
        })
        enqueueEffect(.perform { anotherAction in
          do {
            let medium = try await modelImage.image.load(
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
            let img = try await modelImage.image.load(.high)
            await anotherAction(.imageLoaded(img))
          } catch {
            await anotherAction(.alert(.present(.error(
              title: "Unable to load image in high resolution",
              error: error
            ))))
          }
        })
      case let .cachedLowResImageLoaded(image):
        state.cachedLowResImage = image
      case let .imageLoaded(image):
        state.uiImage = image
      case let .descriptionLink(link):
        let pathComponents = link.pathComponents

        // example: https://pastvu.com/p/2223969
        if let host = link.host(), host == pastvuCom.host(),
           pathComponents.count == 3, pathComponents[1] == "p", // [0] is "/"
           let cid = pathComponents.last.flatMap({ Int($0) }) {
          state.loadingAnotherImage = true
          enqueueEffect(.perform { anotherAction in
            do {
              let details = try await remote.load(cid)
              await anotherAction(.anotherImage(.present(
                details, ImageDetailsView.TransitionSource.descriptionLink
              )))
            } catch {
              await anotherAction(.internal(.anotherImageLoadFailed(error)))
            }
          })
        } else {
          urlOpener(link)
        }
      case let .comparison(comparisonAction):
        switch comparisonAction {
        case let .present(mode):
          guard let image = state.uiImage else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
          }
          setOrientationLock(.portrait)
          state.comparisonDeps = Identified(
            value: makeComparisonViewDeps(
              captureMode: mode,
              oldUIImage: image,
              oldImageData: modelImage,
              streetViewAvailability: streetViewAvailability.mapArgs {
                modelImage.coordinate
              }
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
          if let url = pastVuURL(cid: state.image.cid) {
            urlOpener(url)
          }
        case .favorite:
          state.isFavorite.toggle()
          enqueueEffect(.perform { [isFavorite = state.isFavorite] _ in
            favoriteModel(isFavorite)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
          })
        case .compareCamera:
          enqueueEffect(.anotherAction(.comparison(.present(.camera))))
        case .compareStreetView:
          enqueueEffect(.anotherAction(.comparison(.present(.streetView))))
        case .showOnMap:
          showOnMap(modelImage.coordinate)
        case .saveImage:
          enqueueEffect(.anotherAction(.internal(.saveImage)))
        case .share:
          guard let attrDetails = state.attributedDetails,
                let image = state.uiImage
          else { return }
          let title = state.attributedTitle
          let cid = state.image.cid
          enqueueEffect(.perform { anotherAction in
            let vc = makeShareVC(
              image: image,
              title: String(title.characters),
              description: attrDetails.description.map { String($0.characters) },
              url: pastVuURL(cid: cid)
            )
            await anotherAction(.internal(.shareSheetLoaded(vc)))
          })
        case .route:
          enqueueEffect(.anotherAction(.setMapOptionsVisibility(true)))
        }
      case .translate:
        guard let description = state.details?.description else {
          assertionFailure("trying to translate non-existent description")
          return
        }
        if let cached = state.cachedTranslation {
          state.translationState = .translated(cached)
        } else {
          state.translationState = .translating
          enqueueEffect(.perform { anotherAction in
            do {
              async let translatedDesc = try await translate.load(TranslateParams(
                text: description, target: appLang
              ))
              async let translatedTitle = try await translate.load(TranslateParams(
                text: modelImage.title, target: appLang
              ))
              try await anotherAction(.internal(.translationComplete(
                ImageDetailsState.Translation(
                  title: translatedTitle.makeAttrString(),
                  description: translatedDesc.makeAttrString()
                )
              )))
            } catch {
              await anotherAction(.internal(.translationFailed(error)))
            }
          })
        }
      case .showTranslationOriginal:
        state.translationState = .available
      case .shareSheetDismissed:
        state.shareVC = nil
      case let .setMapOptionsVisibility(visible):
        state.mapOptionsPresented = visible
      case let .mapAppSelected(app):
        if let link = app.coordinateLink(
          latitude: modelImage.coordinate.latitude,
          longitude: modelImage.coordinate.longitude
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
      case let .anotherImage(anotherImageAction):
        switch anotherImageAction {
        case let .present(details, source):
          state.loadingAnotherImage = false
          let anotherModelImage = extractModelImage(details)
          state.anotherImageModel = Identified(value:
            makeImageDetailsModel(
              modelImage: anotherModelImage,
              remote: Remote { cid in
                if cid == details.cid { return details }
                return try await remote.load(cid)
              },
              openSource: source,
              favoritesModel: favoritesModel,
              showOnMap: showOnMap,
              canOpenURL: canOpenURL,
              urlOpener: urlOpener,
              setOrientationLock: setOrientationLock,
              streetViewAvailability: streetViewAvailability,
              translate: translate,
              extractModelImage: extractModelImage
            ).viewStore
          )
        case .dismiss:
          state.anotherImageModel = nil
        }
      case let .internal(internalAction):
        switch internalAction {
        case .saveImage:
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
        case .imageSaved:
          UINotificationFeedbackGenerator().notificationOccurred(.success)
          state.isImageSaved = true
        case let .shareSheetLoaded(vc):
          state.shareVC = Identified(value: vc)
        case let .detailsLoaded(details):
          state.attributedDetails = ImageDetailsState.AttributedDetails(
            description: details.description?.makeAttrString(),
            source: details.source?.makeAttrString(),
            address: details.address?.makeAttrString(),
            author: details.author?.makeAttrString()
          )
          state.details = details
          if let description = details.description,
             let descriptionLang = detectLanguage(description),
             descriptionLang.confidence >= 0.9 {
            state.translationState =
              appLang == descriptionLang.languageCode ? .notAvailable : .available
          } else {
            state.translationState = .available
          }
        case let .translationComplete(translation):
          state.translationState = .translated(translation)
          state.cachedTranslation = translation
        case let .translationFailed(error):
          state.translationState = .available
          enqueueEffect(.anotherAction(.alert(.present(.error(
            title: "Unable to translate description", error: error
          )))))
        case let .anotherImageLoadFailed(error):
          state.loadingAnotherImage = false
          enqueueEffect(.anotherAction(.alert(.present(.error(
            title: "Unable to load image data", error: error
          )))))
        }
      }
    }
  )
}

func pastVuURL(cid: Int) -> URL? {
  var components = URLComponents()
  components.scheme = "https"
  components.host = "pastvu.com"
  components.path = "/\(cid)"
  return components.url
}

func save(image: UIImage) async throws {
  let library = PHPhotoLibrary.shared()
  try await library.performChanges {
    PHAssetChangeRequest.creationRequestForAsset(from: image)
  }
}

private let appLang: String = {
  let appLocalizations = Bundle.main.preferredLocalizations
  if appLocalizations.isEmpty { assertionFailure("app localizations are empty") }
  let appLang = appLocalizations.first ?? "en"
  return appLang.split(separator: "-").first.map(String.init) ?? appLang
}()
