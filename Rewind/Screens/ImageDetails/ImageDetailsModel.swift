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

  enum ColorizationState: Equatable {
    enum Showing {
      case original
      case colorized
    }

    case none
    case detecting
    case notAvailable
    case available(WatermarkedImage)
    case colorizing(WatermarkedImage)
    case ready(
      colorized: UIImage,
      showing: Showing,
      check: ColorizationCheck
    )
  }

  var image: Model.Image
  var attributedTitle: AttributedString

  var details: Model.ImageDetails?
  var attributedDetails: AttributedDetails?

  var uiImage: UIImage?
  var cachedLowResImage: UIImage?
  var imageSaveCounts: [ColorizationState.Showing: Int]
  var source: TransitionSource
  var isFavorite: Bool
  var mapOptionsPresented: Bool
  var loadingAnotherImage: Bool

  var translationState: TranslationState
  var cachedTranslation: Translation?

  var colorizationState: ColorizationState

  var shareVC: Identified<UIViewController>?
  var colorizationPicker: Identified<ColorizationPickerScreenStore>?
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

  enum Internal {
    case saveImage
    case imageSaved(ImageDetailsState.ColorizationState.Showing)
    case shareSheetLoaded(UIViewController)
    case anotherImageLoadFailed(Error)
    case detailsLoaded(Model.ImageDetails)
    case translationComplete(ImageDetailsState.Translation)
    case translationFailed(Error)
    case bwDetectionCompleted(isBW: Bool, image: WatermarkedImage)
    case colorizationCompleted(colorized: UIImage, check: ColorizationCheck)
    case colorizationFailed(Error)
  }

  enum ColorizationPicker {
    case present
    case dismiss
  }

  enum Alert {
    case present(AlertParams?)
    case dismiss
  }

  case button(Button)
  case fullscreenPreview
  case comparison(ComparisonState.CaptureMode)
  case anotherImage(Model.ImageDetails, TransitionSource)
  case colorizationPicker(ColorizationPicker)
  case alert(Alert)
  case `internal`(Internal)
  case shareSheetDismissed
  case setMapOptionsVisibility(Bool)
  case mapAppSelected(MapApp)
  case translate
  case showTranslationOriginal
  case colorize
  case dismissColorizationCheck
}

func makeImageDetailsModel(
  modelImage: Model.Image,
  remote: Remote<Int, Model.ImageDetails>,
  cachedDetails: Model.ImageDetails?,
  source: TransitionSource,
  favoritesModel: FavoritesModel,
  showOnMap: @escaping (Coordinate) -> Void,
  canOpenURL: @escaping (URL) -> Bool,
  urlOpener: @escaping (URL) -> Void,
  streetViewAvailability: Remote<Coordinate, StreetViewAvailability>,
  translate: Remote<TranslateParams, String>,
  colorizationModel: Variable<ColorizationModel?>,
  extractModelImage: @escaping (Model.ImageDetails) -> (Model.Image),
  makeColorizationPicker: @escaping (@escaping () -> Void) -> ColorizationPickerScreenStore,
  pushScreen: @escaping (Screen) -> Void,
  imageDetailsFactory: @escaping ImageDetailsFactory,
  isLastScreen: Variable<Bool>,
) -> ImageDetailsModel {
  let favoriteModel = favoritesModel.isFavorite(modelImage)
  var initialState = ImageDetailsState(
    image: modelImage,
    attributedTitle: modelImage.title.makeAttrString(),
    details: nil,
    uiImage: nil,
    cachedLowResImage: nil,
    imageSaveCounts: [:],
    source: source,
    isFavorite: favoriteModel.state.wrappedValue,
    mapOptionsPresented: false,
    loadingAnotherImage: false,
    translationState: .notAvailable,
    cachedTranslation: nil,
    colorizationState: .none,
    shareVC: nil,
    colorizationPicker: nil,
    alertModel: nil,
    actionButtons: Array.build {
      [ImageDetailsAction.Button.favorite, .compareCamera]
      if modelImage.coordinate != nil {
        [ImageDetailsAction.Button.compareStreetView, .showOnMap]
      }
      [ImageDetailsAction.Button.share, .saveImage, .viewOnWeb]
      if modelImage.coordinate != nil {
        ImageDetailsAction.Button.route
      }
    },
  )
  if let cachedDetails {
    apply(details: cachedDetails, to: &initialState)
  }
  weak var modelRef: ImageDetailsModel?
  let model = ImageDetailsModel(
    initial: initialState,
    reduce: { state, action, effect, asyncEffect in
      switch action {
      case .willBePresented:
        if state.details == nil {
          asyncEffect(.perform { anotherAction in
            do {
              let data = try await remote.load(modelImage.cid)
              await anotherAction(.internal(.detailsLoaded(data)))
            } catch {
              await anotherAction(.alert(.present(.error(
                title: "Unable to load image info",
                error: error,
              ))))
            }
          })
        }
        asyncEffect(.perform { anotherAction in
          do {
            let medium = try await modelImage.image.load(
              ImageLoadingParams(
                quality: .medium,
                cachedOnly: true,
              ),
            )
            await anotherAction(.cachedLowResImageLoaded(medium))
          } catch {}
        })
        asyncEffect(.perform { anotherAction in
          do {
            let img = try await modelImage.image.load(.high)
            await anotherAction(.imageLoaded(img))
          } catch {
            await anotherAction(.alert(.present(.error(
              title: "Unable to load image in high resolution",
              error: error,
            ))))
          }
        })
      case let .cachedLowResImageLoaded(image):
        state.cachedLowResImage = image
      case let .imageLoaded(image):
        state.uiImage = image
        checkColorizationAvailability(state: &state, asyncEffect: asyncEffect)
      case let .descriptionLink(link):
        guard isLastScreen.value else { return }
        let pathComponents = link.pathComponents

        // example: https://pastvu.com/p/2223969
        if let host = link.host(), host == pastvuCom.host(),
           pathComponents.count == 3, pathComponents[1] == "p", // [0] is "/"
           let cid = pathComponents.last.flatMap({ Int($0) }) {
          state.loadingAnotherImage = true
          asyncEffect(.perform { anotherAction in
            do {
              let details = try await remote.load(cid)
              await anotherAction(.anotherImage(
                details, .image(.link),
              ))
            } catch {
              await anotherAction(.internal(.anotherImageLoadFailed(error)))
            }
          })
        } else {
          effect { urlOpener(link) }
        }
      case let .comparison(mode):
        guard isLastScreen.value else { return }
        guard let image = state.displayedImage else {
          UINotificationFeedbackGenerator().notificationOccurred(.error)
          return
        }
        let source: TransitionSource? = switch mode {
        case .camera: TransitionSource.compareCamera
        case .streetView: nil
        }
        let comparisonDeps = makeComparisonViewDeps(
          captureMode: mode,
          oldUIImage: image,
          oldImageData: modelImage,
          streetViewAvailability: Remote {
            guard let coordinate = modelImage.coordinate else {
              assertionFailure("should not be called on images without geo")
              return .unavailable
            }
            return try await streetViewAvailability.load(coordinate)
          },
          source: source,
        )
        effect { pushScreen(Screen(.comparison(comparisonDeps))) }
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
            effect { urlOpener(url) }
          }
        case .favorite:
          state.isFavorite.toggle()
          asyncEffect(.perform { [isFavorite = state.isFavorite] _ in
            favoriteModel(isFavorite)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
          })
        case .compareCamera:
          asyncEffect(.anotherAction(.comparison(.camera)))
        case .compareStreetView:
          asyncEffect(.anotherAction(.comparison(.streetView)))
        case .showOnMap:
          guard let coordinate = modelImage.coordinate else {
            assertionFailure("should not be called on images without geo")
            return
          }
          effect { showOnMap(coordinate) }
        case .saveImage:
          asyncEffect(.anotherAction(.internal(.saveImage)))
        case .share:
          guard let attrDetails = state.attributedDetails,
                let image = state.displayedImage
          else { return }
          let title = state.attributedTitle
          let cid = state.image.cid
          asyncEffect(.perform { anotherAction in
            let vc = makeShareVC(
              image: image,
              title: String(title.characters),
              description: attrDetails.description.map { String($0.characters) },
              url: pastVuURL(cid: cid),
            )
            await anotherAction(.internal(.shareSheetLoaded(vc)))
          })
        case .route:
          asyncEffect(.anotherAction(.setMapOptionsVisibility(true)))
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
          asyncEffect(.perform { anotherAction in
            do {
              async let translatedDesc = try await translate.load(TranslateParams(
                text: description, target: appLang,
              ))
              async let translatedTitle = try await translate.load(TranslateParams(
                text: modelImage.title, target: appLang,
              ))
              try await anotherAction(.internal(.translationComplete(
                ImageDetailsState.Translation(
                  title: translatedTitle.makeAttrString(),
                  description: translatedDesc.makeAttrString(),
                ),
              )))
            } catch {
              await anotherAction(.internal(.translationFailed(error)))
            }
          })
        }
      case .showTranslationOriginal:
        state.translationState = .available
      case .colorize:
        switch state.colorizationState {
        case let .available(image):
          guard let model = colorizationModel.value else {
            asyncEffect(.anotherAction(.colorizationPicker(.present)))
            return
          }
          state.colorizationState = .colorizing(image)
          asyncEffect(.perform(id: colorizationEffectID) { anotherAction in
            do {
              let (colorized, check) = try await colorize(image: image.content, model: model)
              try Task.checkCancellation()
              let stitched = await modified(image) { $0.content = colorized }.stitched()
              await anotherAction(.internal(.colorizationCompleted(
                colorized: stitched,
                check: check,
              )))
            } catch {
              await anotherAction(.internal(.colorizationFailed(error)))
            }
          })
        case let .ready(colorized, showing, check):
          state.colorizationState = .ready(
            colorized: colorized,
            showing: showing == .colorized ? .original : .colorized,
            check: check,
          )
        case .none, .detecting, .notAvailable, .colorizing:
          break
        }
      case .dismissColorizationCheck:
        guard case let .ready(image, showing, _) = state.colorizationState else {
          assertionFailure("trying to dismiss nonexistent check")
          return
        }
        state.colorizationState = .ready(colorized: image, showing: showing, check: .ok)
      case .colorizationPicker(.present):
        guard state.colorizationPicker == nil else { return }
        state.colorizationPicker = Identified(value: makeColorizationPicker {
          modelRef?(.colorizationPicker(.dismiss))
          modelRef?(.colorize)
        })
      case .colorizationPicker(.dismiss):
        state.colorizationPicker = nil
      case .shareSheetDismissed:
        state.shareVC = nil
      case let .setMapOptionsVisibility(visible):
        state.mapOptionsPresented = visible
      case let .mapAppSelected(app):
        if let coordinate = modelImage.coordinate,
           let link = app.coordinateLink(
             latitude: coordinate.latitude,
             longitude: coordinate.longitude,
           ),
           canOpenURL(link) {
          effect { urlOpener(link) }
        } else {
          UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
      case .fullscreenPreview:
        guard isLastScreen.value else { return }
        if let image = state.displayedImage {
          let showing = state.displayedVersion
          let store = makeFullscreenPreviewStore(
            image: image,
            savesCount: state.imageSaveCount,
            saveImage: {
              try await save(image: image)
              modelRef?(.internal(.imageSaved(showing)))
            },
            source: .fullscreenPreview
          )
          effect { pushScreen(Screen(.fullscreenPreview(store))) }
        }
      case let .anotherImage(details, source):
        state.loadingAnotherImage = false
        let anotherModelImage = extractModelImage(details)
        effect {
          pushScreen(imageDetailsFactory(anotherModelImage, source))
        }
      case let .internal(internalAction):
        switch internalAction {
        case .saveImage:
          guard let image = state.displayedImage else { return }
          let version = state.displayedVersion
          asyncEffect(.perform { anotherAction in
            do {
              try await save(image: image)
              await anotherAction(.internal(.imageSaved(version)))
            } catch {
              await anotherAction(.alert(.present(.error(
                title: "Unable to save image",
                error: error,
              ))))
            }
          })
        case let .imageSaved(version):
          UINotificationFeedbackGenerator().notificationOccurred(.success)
          state.imageSaveCounts[version, default: 0] += 1
        case let .shareSheetLoaded(vc):
          state.shareVC = Identified(value: vc)
        case let .detailsLoaded(details):
          apply(details: details, to: &state)
          checkColorizationAvailability(state: &state, asyncEffect: asyncEffect)
        case let .translationComplete(translation):
          state.translationState = .translated(translation)
          state.cachedTranslation = translation
        case let .translationFailed(error):
          state.translationState = .available
          asyncEffect(.anotherAction(.alert(.present(.error(
            title: "Unable to translate description", error: error,
          )))))
        case let .anotherImageLoadFailed(error):
          state.loadingAnotherImage = false
          asyncEffect(.anotherAction(.alert(.present(.error(
            title: "Unable to load image data", error: error,
          )))))
        case let .bwDetectionCompleted(isBW, image):
          state.colorizationState = isBW ? .available(image) : .notAvailable
        case let .colorizationCompleted(colorized, check):
          state.colorizationState = .ready(
            colorized: colorized,
            showing: .colorized,
            check: check,
          )
          UINotificationFeedbackGenerator().notificationOccurred(.success)
        case let .colorizationFailed(error):
          if case let .colorizing(image) = state.colorizationState {
            state.colorizationState = .available(image)
          }
          asyncEffect(.anotherAction(.alert(.present(.nonCancelledError(
            title: "Unable to colorize image", error: error,
          )))))
        }
      }
    },
    tetheredEffects: [colorizationEffectID],
  )
  modelRef = model
  return model
}

private let colorizationEffectID = "colorization"

private func checkColorizationAvailability(
  state: inout ImageDetailsState,
  asyncEffect: (ImageDetailsModel.AsyncEffect) -> Void,
) {
  guard state.colorizationState == .none,
        let image = state.uiImage,
        let details = state.details else { return }
  state.colorizationState = .detecting
  asyncEffect(.perform { anotherAction in
    let image = await splitWatermark(
      from: image,
      watermarkHeight: details.watermarkHeight,
      contentHeight: details.contentHeight,
    )
    do {
      let isBW = try await isMonochrome(image: image.content)
      await anotherAction(.internal(.bwDetectionCompleted(isBW: isBW, image: image)))
    } catch {
      assertionFailure("BW detection failed: \(error)")
    }
  })
}

private func apply(details: Model.ImageDetails, to state: inout ImageDetailsState) {
  state.attributedDetails = ImageDetailsState.AttributedDetails(
    description: details.description?.makeAttrString(),
    source: details.source?.makeAttrString(),
    address: details.address?.makeAttrString(),
    author: details.author?.makeAttrString(),
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
}

extension ImageDetailsState {
  var displayedVersion: ColorizationState.Showing {
    if case .ready(_, .colorized, _) = colorizationState { .colorized } else { .original }
  }

  var imageSaveCount: Int { imageSaveCounts[displayedVersion, default: 0] }

  var isImageSaved: Bool { imageSaveCount > 0 }

  var displayedImage: UIImage? {
    colorizedImage ?? uiImage
  }

  var colorizedImage: UIImage? {
    if case let .ready(colorized, .colorized, _) = colorizationState { colorized } else { nil }
  }
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
