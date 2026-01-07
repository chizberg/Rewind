//
//  ComparisonModel.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 5. 12. 2025..
//

import AVFoundation
import SwiftUI
import WebKit

import VGSL

typealias ComparisonModel = Reducer<ComparisonState, ComparisonAction>
typealias ComparisonViewStore = ViewStore<ComparisonState, ComparisonAction.External>

struct ComparisonViewDeps {
  var store: ComparisonViewStore
  var comparisonVC: UIViewController
}

struct ComparisonState {
  enum Style: CaseIterable, Equatable {
    case sideBySide
    case cardOnCard
  }

  enum CaptureMode: CaseIterable, Equatable {
    case camera
    case streetView
  }

  enum CaptureState {
    case viewfinder(UIView)
    case taken(capture: UIImage)
  }

  var oldUIImage: UIImage
  var oldImageData: Model.Image
  var captureState: CaptureState?
  var style: Style
  var captureMode: CaptureMode
  var orientation: Orientation
  var alert: Identified<AlertParams>?
  var shareVC: Identified<UIViewController>?
  var streetViewAvailability: StreetViewAvailability?

  var currentLens: Lens?
  var availableLens: [Lens] {
    cameraSession?.availableLens ?? []
  }

  fileprivate var cameraSession: CameraSession?
}

enum ComparisonAction {
  enum External {
    enum Alert {
      case presentAccessError
      case presentLensError(Error)
      case presentSavingImageError(Error)
      case presentSharingImageError(Error)
      case presentStreetViewError(Error)
      case presentStreetViewUnavailable
      case dismiss
    }

    enum ShareSheet {
      case present
      case dismiss
    }

    case setStyle(ComparisonState.Style)
    case shoot
    case retake
    case setLens(Lens)
    case viewWillAppear
    case shareSheet(ShareSheet)
    case alert(Alert)
  }

  enum Internal {
    case sessionReady(CameraSession)
    case videoAccessGranted
    case imageTaken(UIImage)
    case orientationChanged(Orientation)
    case shareSheetLoaded(UIViewController)
    case streetViewAvailabilityLoaded(StreetViewAvailability)
    case setupCapture
  }

  case external(External)
  case `internal`(Internal)
}

func makeComparisonViewDeps(
  captureMode: ComparisonState.CaptureMode,
  oldUIImage: UIImage,
  oldImageData: Model.Image,
  streetViewAvailability: Remote<Void, StreetViewAvailability>
) -> ComparisonViewDeps {
  let orientationTracker = OrientationTracker()
  weak var comparisonVC: UIViewController?
  let model = ComparisonModel(
    initial: ComparisonState(
      oldUIImage: oldUIImage,
      oldImageData: oldImageData,
      captureState: nil,
      style: .sideBySide,
      captureMode: captureMode,
      orientation: orientationTracker.orientation,
      cameraSession: nil
    ),
    reduce: { state, action, enqueueEffect in
      switch action {
      case let .external(externalAction):
        switch externalAction {
        case let .setStyle(style):
          state.style = style
        case .shoot:
          enqueueEffect(.perform { [state] anotherAction in
            do {
              let image: UIImage
              switch state.captureMode {
              case .camera:
                guard let session = state.cameraSession else { return }
                image = try await session.capturePhoto()
              case .streetView:
                guard case let .viewfinder(webView) = state.captureState else { return }
                image = renderView(view: webView)
              }
              await anotherAction(.internal(.imageTaken(image)))
            } catch {
              await anotherAction(.external(.alert(.presentAccessError)))
            }
          })
        case .retake:
          enqueueEffect(.anotherAction(.internal(.setupCapture)))
        case let .setLens(lens):
          do {
            try state.cameraSession?.setLens(lens: lens, animated: true)
            state.currentLens = lens
          } catch {
            enqueueEffect(.anotherAction(.external(.alert(.presentLensError(error)))))
          }
        case .viewWillAppear:
          switch state.captureMode {
          case .camera:
            let access = AVCaptureDevice.authorizationStatus(for: .video)
            switch access {
            case .authorized:
              enqueueEffect(.anotherAction(.internal(.videoAccessGranted)))
            case .notDetermined:
              enqueueEffect(.perform { anotherAction in
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                await anotherAction(
                  granted
                    ? .internal(.videoAccessGranted)
                    : .external(.alert(.presentAccessError))
                )
              })
            case .restricted, .denied: fallthrough
            @unknown default:
              enqueueEffect(.anotherAction(.external(.alert(.presentAccessError))))
            }
          case .streetView:
            enqueueEffect(.perform { anotherAction in
              do {
                let availability = try await streetViewAvailability.load()
                await anotherAction(.internal(.streetViewAvailabilityLoaded(availability)))
              } catch {
                assertionFailure()
                // we block user actions only if streetView is surely not available
              }
            })
            enqueueEffect(.anotherAction(.internal(.setupCapture)))
          }
        case let .shareSheet(shareSheetAction):
          switch shareSheetAction {
          case .present:
            enqueueEffect(.perform { [state] anotherAction in
              do {
                guard let comparisonVC else {
                  assertionFailure()
                  throw HandlingError("Comparison VC is missing")
                }
                let item = ImageShareItem(
                  image: renderView(view: comparisonVC.view),
                  text: state.oldImageData.title
                )
                await anotherAction(.internal(.shareSheetLoaded(
                  UIActivityViewController(
                    activityItems: [
                      item,
                      oldImageData.title,
                    ],
                    applicationActivities: nil
                  )
                )))
              } catch {
                await anotherAction(.external(.alert(.presentSharingImageError(error))))
              }
            })
          case .dismiss:
            state.shareVC = nil
          }
        case let .alert(alertAction):
          switch alertAction {
          case .presentAccessError:
            state.alert = Identified(value: .info(
              title: "Unable to use the camera",
              message: "You can check camera permissions in Settings"
            ))
          case let .presentLensError(error):
            state.alert = Identified(value: .error(
              title: "Unable to switch lens",
              error: error
            ))
          case let .presentSavingImageError(error):
            state.alert = Identified(value: .error(
              title: "Unable to save image",
              error: error
            ))
          case let .presentSharingImageError(error):
            state.alert = Identified(value: .error(
              title: "Unable to share image",
              error: error
            ))
          case let .presentStreetViewError(error):
            state.alert = Identified(value: .error(
              title: "Street View Error",
              error: error
            ))
          case .presentStreetViewUnavailable:
            state.alert = Identified(value: .info(
              title: "Google Street View Unavailable",
              message: "Google Street View is not available for this location."
            ))
          case .dismiss:
            state.alert = nil
          }
        }
      case let .internal(internalAction):
        switch internalAction {
        case .videoAccessGranted:
          do {
            let session = try CameraSession()
            enqueueEffect(.anotherAction(.internal(.sessionReady(session))))
          } catch {
            enqueueEffect(.anotherAction(.external(.alert(.presentAccessError))))
          }
        case let .sessionReady(session):
          state.cameraSession = session
          state.currentLens = session.mainLens
          enqueueEffect(.anotherAction(.internal(.setupCapture)))
        case let .imageTaken(image):
          UINotificationFeedbackGenerator().notificationOccurred(.success)
          state.captureState = .taken(capture: image)
          state.cameraSession?.stop()
          enqueueEffect(.perform { anotherAction in
            do {
              guard let comparisonVC else {
                assertionFailure()
                throw HandlingError("Comparison VC is missing")
              }
              try await save(image: renderView(view: comparisonVC.view))
            } catch {
              await anotherAction(.external(.alert(.presentSavingImageError(error))))
            }
          })
        case let .orientationChanged(orientation):
          state.orientation = orientation
        case let .shareSheetLoaded(vc):
          state.shareVC = Identified(value: vc)
        case .setupCapture:
          switch state.captureMode {
          case .camera:
            guard let session = state.cameraSession else { return }
            state.captureState = .viewfinder(session.makePreview())
            session.start()
          case .streetView:
            do {
              let streetView = try makeStreetView(image: state.oldImageData)
              state.cameraSession?.stop()
              state.captureState = .viewfinder(streetView)
            } catch {
              enqueueEffect(.anotherAction(.external(.alert(.presentStreetViewError(error)))))
            }
          }
        case let .streetViewAvailabilityLoaded(availability):
          state.streetViewAvailability = availability
          if case .unavailable = availability {
            enqueueEffect(.anotherAction(.external(.alert(.presentStreetViewUnavailable))))
          }
        }
      }
    }
  ).adding(
    signal: orientationTracker.$orientation.newValues.retaining(object: orientationTracker),
    makeAction: { .internal(.orientationChanged($0)) }
  )

  let vc = UIHostingController(
    rootView: model.$state.asObservedVariable().observe { state in
      ComparisonView(
        style: state.style,
        oldImageData: state.oldImageData,
        oldImage: state.oldUIImage,
        captureState: state.captureState,
        streetViewYear: state.streetViewAvailability?.year
      )
    }
  )
  vc.sizingOptions = UIHostingControllerSizingOptions.intrinsicContentSize
  comparisonVC = vc

  return ComparisonViewDeps(
    store: model.viewStore.bimap(state: { $0 }, action: { .external($0) }),
    comparisonVC: vc
  )
}

@MainActor
private func renderView(
  view: UIView
) -> UIImage {
  let format = UIGraphicsImageRendererFormat()
  format.scale = 3
  format.opaque = true

  let renderer = UIGraphicsImageRenderer(
    size: view.bounds.size,
    format: format
  )
  return renderer.image { _ in
    view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
  }
}

extension ComparisonState.CaptureState? {
  var isTaken: Bool {
    if case .taken = self { true } else { false }
  }

  var isViewfinder: Bool {
    if case .viewfinder = self { true } else { false }
  }
}

extension StreetViewAvailability {
  fileprivate var year: Int? {
    switch self {
    case let .available(year): year
    case .unavailable: nil
    }
  }
}
