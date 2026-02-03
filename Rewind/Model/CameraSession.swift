//
//  CameraSession.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 9. 12. 2025.
//

import AVFoundation
import SwiftUI
import VGSL

/// Manages the AVFoundation camera capture session lifecycle, including session setup,
/// preview generation, and photo capture. Use this class to start/stop the camera session,
/// create a preview view, and capture photos asynchronously.
final class CameraSession {
  let availableLens: [Lens]
  let mainLens: Lens

  private let device: AVCaptureDevice
  private let captureSession: AVCaptureSession
  private let photoOutput: AVCapturePhotoOutput
  private let capturedImages = SignalPipe<Result<UIImage, Error>>()

  init() throws {
    guard let device = makeDevice() else {
      throw HandlingError("No video device available")
    }
    self.device = device

    let (lens, wide) = try getAvailableLens(device: device)
    availableLens = lens
    mainLens = wide

    photoOutput = AVCapturePhotoOutput()
    captureSession = AVCaptureSession()

    let input = try AVCaptureDeviceInput(device: device)
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

    try setLens(lens: mainLens, animated: false)
  }

  func start() {
    Task(priority: .userInitiated) { captureSession.startRunning() }
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

  func setLens(lens: Lens, animated: Bool) throws {
    let clamped = lens.zoomValue.clamp(
      device.minAvailableVideoZoomFactor...device.maxAvailableVideoZoomFactor
    )
    try device.lockForConfiguration()
    defer { device.unlockForConfiguration() }
    if animated {
      device.ramp(toVideoZoomFactor: clamped, withRate: 6)
    } else {
      device.videoZoomFactor = clamped
    }
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

private func makeDevice() -> AVCaptureDevice? {
  AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back) ??
    AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back) ??
    AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) ??
    AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
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
