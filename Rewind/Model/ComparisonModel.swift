//
//  ComparisonModel.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 5. 12. 2025..
//

import AVFoundation
import SwiftUI

import VGSL

typealias ComparisonModel = Reducer<ComparisonState, ComparisonAction>
typealias ComparisonViewStore = ViewStore<ComparisonState, ComparisonAction.External>

struct ComparisonState {
  enum Style: CaseIterable, Equatable {
    case sideBySide
    case cardOnCard
  }

  enum CameraState {
    case viewfinder(UIView)
    case taken(capture: UIImage)
  }

  var oldUIImage: UIImage
  var oldImageData: Model.Image
  var cameraState: CameraState?
  var style: Style
  var orientation: Orientation
  var alert: Identified<AlertParams>?
  var shareVC: Identified<UIViewController>?
  var comparisonViewSize: CGSize

  fileprivate var session: CameraSession?
}

enum ComparisonAction {
  enum External {
    enum Alert {
      case presentAccessError
      case presentSavingImageError(Error)
      case presentSharingImageError(Error)
      case dismiss
    }

    enum ShareSheet {
      case present
      case dismiss
    }

    case setStyle(ComparisonState.Style)
    case shoot
    case retake
    case viewWillAppear
    case comparisonViewSizeChanged(CGSize)
    case shareSheet(ShareSheet)
    case alert(Alert)
  }

  enum Internal {
    case sessionReady(CameraSession)
    case videoAccessGranted
    case imageTaken(UIImage)
    case orientationChanged(Orientation)
    case shareSheetLoaded(UIViewController)
  }

  case external(External)
  case `internal`(Internal)
}

func makeComparisonModel(
  oldUIImage: UIImage,
  oldImageData: Model.Image
) -> ComparisonModel {
  let orientationTracker = OrientationTracker()
  return ComparisonModel(
    initial: ComparisonState(
      oldUIImage: oldUIImage,
      oldImageData: oldImageData,
      cameraState: nil,
      style: .sideBySide,
      orientation: orientationTracker.orientation,
      comparisonViewSize: .zero,
      session: nil
    ),
    reduce: { state, action, enqueueEffect in
      switch action {
      case let .external(externalAction):
        switch externalAction {
        case let .setStyle(style):
          state.style = style
        case .shoot:
          guard let session = state.session else { return }
          enqueueEffect(.perform { anotherAction in
            do {
              let image = try await session.capturePhoto()
              await anotherAction(.internal(.imageTaken(image)))
            } catch {
              await anotherAction(.external(.alert(.presentAccessError)))
            }
          })
        case .retake:
          guard let session = state.session else { return }
          state.cameraState = .viewfinder(session.makePreview())
          enqueueEffect(.perform { _ in session.start() })
        case .viewWillAppear:
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
        case let .comparisonViewSizeChanged(size):
          state.comparisonViewSize = size
        case let .shareSheet(shareSheetAction):
          switch shareSheetAction {
          case .present:
            enqueueEffect(.perform { [state] anotherAction in
              do {
                guard let result = renderComparisonView(state: state) else {
                  throw HandlingError("Unable to render an image")
                }
                let item = ImageShareItem(image: result, text: state.oldImageData.title)
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
          case .dismiss:
            state.alert = nil
          }
        }
      case let .internal(internalAction):
        switch internalAction {
        case .videoAccessGranted:
          do {
            guard let device = AVCaptureDevice.default(for: .video) else {
              throw HandlingError("No video device available")
            }
            let session = try CameraSession(device: device)
            enqueueEffect(.anotherAction(.internal(.sessionReady(session))))
          } catch {
            enqueueEffect(.anotherAction(.external(.alert(.presentAccessError))))
          }
        case let .sessionReady(session):
          state.session = session
          state.cameraState = .viewfinder(session.makePreview())
          enqueueEffect(.perform { _ in session.start() })
        case let .imageTaken(image):
          state.cameraState = .taken(capture: image)
          state.session?.stop()
          enqueueEffect(.perform { [state] anotherAction in
            do {
              if let result = renderComparisonView(state: state) {
                try await save(image: result)
              } else {
                throw HandlingError("Unable to render the image")
              }
            } catch {
              await anotherAction(.external(.alert(.presentSavingImageError(error))))
            }
          })
        case let .orientationChanged(orientation):
          state.orientation = orientation
        case let .shareSheetLoaded(vc):
          state.shareVC = Identified(value: vc)
        }
      }
    }
  ).adding(
    signal: orientationTracker.$orientation.newValues.retaining(object: orientationTracker),
    makeAction: { .internal(.orientationChanged($0)) }
  )
}

@MainActor
private func renderComparisonView(
  state: ComparisonState
) -> UIImage? {
  let view = ComparisonView(
    style: state.style,
    oldImageData: state.oldImageData,
    oldImage: state.oldUIImage,
    cameraState: state.cameraState
  )
  .frame(size: state.comparisonViewSize)
  .background(.background)
  .environment(\.colorScheme, .dark)

  let renderer = ImageRenderer(
    content: view
  )
  renderer.scale = 3
  renderer.isOpaque = true
  return renderer.uiImage
}

extension ComparisonState.CameraState? {
  var isTaken: Bool {
    if case .taken = self { true } else { false }
  }

  var isViewfinder: Bool {
    if case .viewfinder = self { true } else { false }
  }
}
