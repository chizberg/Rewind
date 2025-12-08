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
    case taken(capture: UIImage, renderedResult: UIImage?)
  }

  var oldUIImage: UIImage
  var oldImageData: Model.Image
  var cameraState: CameraState?
  var style: Style
  var orientation: Orientation
  var alert: Identified<AlertParams>?
  var shareVC: Identified<UIViewController>?

  fileprivate var session: CameraSession?
}

enum ComparisonAction {
  enum External {
    enum Alert {
      case presentAccessError
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
    case resultRendered(UIImage?)
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
        case let .resultRendered(result):
          guard case let .taken(capture, _) = state.cameraState,
                let result
          else {
            assertionFailure()
            return
          }
          state.cameraState = .taken(capture: capture, renderedResult: result)
        case let .shareSheet(shareSheetAction):
          switch shareSheetAction {
          case .present:
            guard case let .taken(_, result) = state.cameraState,
                  let result
            else {
              assertionFailure()
              return
            }
            let item = ImageShareItem(image: result, text: state.oldImageData.title)
            enqueueEffect(.perform { anotherAction in
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
          state.cameraState = .taken(capture: image, renderedResult: nil)
          state.session?.stop()
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

/// Manages the AVFoundation camera capture session lifecycle, including session setup,
/// preview generation, and photo capture. Use this class to start/stop the camera session,
/// create a preview view, and capture photos asynchronously.
final class CameraSession: NSObject, AVCapturePhotoCaptureDelegate {
  private let captureSession: AVCaptureSession
  private let photoOutput: AVCapturePhotoOutput

  private let capturedImages = SignalPipe<Result<UIImage, Error>>()

  init(
    device: AVCaptureDevice
  ) throws {
    let input = try AVCaptureDeviceInput(device: device)

    photoOutput = AVCapturePhotoOutput()
    captureSession = AVCaptureSession()

    if captureSession.canAddInput(input) {
      captureSession.addInput(input)
    } else {
      assertionFailure("can't add capture input")
    }
    if captureSession.canAddOutput(photoOutput) {
      captureSession.addOutput(photoOutput)
    } else {
      assertionFailure("can't add capture output")
    }
  }

  func start() {
    captureSession.startRunning()
  }

  func stop() {
    captureSession.stopRunning()
  }

  func makePreview() -> UIView {
    let preview = CameraPreview()
    preview.videoPreviewLayer?.session = captureSession
    preview.videoPreviewLayer?.videoGravity = .resizeAspectFill
    return preview
  }

  func capturePhoto() async throws -> UIImage {
    let photo = try await photoOutput.capturePhoto(with: AVCapturePhotoSettings())
    if let data = photo.fileDataRepresentation(),
       let image = UIImage(data: data) {
      return image
    } else {
      throw HandlingError("Failed to decode image")
    }
  }

  deinit {
    stop()
  }
}

private final class CameraPreview: UIView {
  override static var layerClass: AnyClass {
    AVCaptureVideoPreviewLayer.self
  }

  var videoPreviewLayer: AVCaptureVideoPreviewLayer? {
    layer as? AVCaptureVideoPreviewLayer
  }
}

extension AVCapturePhotoOutput {
  fileprivate func capturePhoto(
    with settings: AVCapturePhotoSettings
  ) async throws -> AVCapturePhoto {
    let delegate = PhotoCaptureDelegate()
    let result: AVCapturePhoto = try await withCheckedThrowingContinuation { continuation in
      delegate.completion = { photo, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: photo)
        }
      }
      self.capturePhoto(with: settings, delegate: delegate)
    }
    _ = delegate // keep delegate alive
    return result
  }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
  var completion: ((AVCapturePhoto, Error?) -> Void)?

  func photoOutput(
    _: AVCapturePhotoOutput,
    didFinishProcessingPhoto photo: AVCapturePhoto,
    error: (any Error)?
  ) {
    completion?(photo, error)
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
