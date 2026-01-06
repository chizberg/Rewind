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
  var comparisonVC: UIViewController!

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
    case comparisonViewLoaded(UIViewController)
  }

  case external(External)
  case `internal`(Internal)
}

func makeComparisonModel(
  oldUIImage: UIImage,
  oldImageData: Model.Image
) -> ComparisonModel {
  let orientationTracker = OrientationTracker()
  let model = ComparisonModel(
    initial: ComparisonState(
      oldUIImage: oldUIImage,
      oldImageData: oldImageData,
      cameraState: nil,
      style: .sideBySide,
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
          guard let session = state.cameraSession else { return }
          enqueueEffect(.perform { anotherAction in
            do {
              let image = try await session.capturePhoto()
              await anotherAction(.internal(.imageTaken(image)))
            } catch {
              await anotherAction(.external(.alert(.presentAccessError)))
            }
          })
        case .retake:
          guard let session = state.cameraSession else { return }
          state.cameraState = .viewfinder(session.makePreview())
          enqueueEffect(.perform { _ in session.start() })
        case let .setLens(lens):
          do {
            try state.cameraSession?.setLens(lens: lens, animated: true)
            state.currentLens = lens
          } catch {
            enqueueEffect(.anotherAction(.external(.alert(.presentLensError(error)))))
          }
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
        case let .shareSheet(shareSheetAction):
          switch shareSheetAction {
          case .present:
            enqueueEffect(.perform { [state] anotherAction in
              let item = ImageShareItem(
                image: renderComparisonView(view: state.comparisonVC.view),
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
          state.cameraState = .viewfinder(session.makePreview())
          enqueueEffect(.perform { _ in session.start() })
        case let .imageTaken(image):
          state.cameraState = .taken(capture: image)
          state.cameraSession?.stop()
          enqueueEffect(.perform { [state] anotherAction in
            do {
              try await save(image: renderComparisonView(view: state.comparisonVC.view))
            } catch {
              await anotherAction(.external(.alert(.presentSavingImageError(error))))
            }
          })
        case let .orientationChanged(orientation):
          state.orientation = orientation
        case let .shareSheetLoaded(vc):
          state.shareVC = Identified(value: vc)
        case let .comparisonViewLoaded(vc):
          state.comparisonVC = vc
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
        cameraState: state.cameraState
      )
    }
  )
  vc.sizingOptions = [.intrinsicContentSize]
  model.viewStore(.internal(.comparisonViewLoaded(vc)))

  return model
}

@MainActor
private func renderComparisonView(
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

extension ComparisonState.CameraState? {
  var isTaken: Bool {
    if case .taken = self { true } else { false }
  }

  var isViewfinder: Bool {
    if case .viewfinder = self { true } else { false }
  }
}
