//
//  Lens.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 6. 1. 2026..
//

import AVFoundation
import SwiftUI

struct Lens: Identifiable, Equatable {
  let id = UUID()
  let title: String
  let zoomValue: Double

  static func ==(lhs: Lens, rhs: Lens) -> Bool {
    lhs.id == rhs.id
  }
}

func getAvailableLens(device: AVCaptureDevice) throws -> ([Lens], wide: Lens) {
  guard device.isVirtualDevice else {
    throw HandlingError("Expected virtual device")
  }

  // virtualDeviceSwitchOverVideoZoomFactors has always 1 less element than constituentDevices
  // so we add 1.0 at the beginning (i.e. first device activates at 1.0 zoom)
  let zoomValues = [1.0] + device.virtualDeviceSwitchOverVideoZoomFactors.map(\.doubleValue)

  guard
    let wideIndex = device.constituentDevices.firstIndex(where: {
      $0.deviceType == .builtInWideAngleCamera
    }),
    wideIndex < zoomValues.count
  else {
    throw HandlingError("No wide angle camera found")
  }

  let wideZoomValue = zoomValues[wideIndex]
  let lens = zoomValues.map { zoom in
    Lens(
      title: makeZoomLabel(zoom / wideZoomValue),
      zoomValue: zoom
    )
  }
  let wideLens = lens[wideIndex]

  return (lens, wideLens)
}

private func makeZoomLabel(_ x: Double) -> String {
  let rounded = (x * 10).rounded() / 10
  return if rounded.truncatingRemainder(dividingBy: 1) == 0 {
    "\(Int(rounded))x"
  } else {
    "\(rounded)x"
  }
}
