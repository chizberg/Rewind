//
//  Lens.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 6. 1. 2026.
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

// ai-generated
func getAvailableLens(device: AVCaptureDevice) throws -> ([Lens], wide: Lens) {
  guard device.isVirtualDevice else {
    throw HandlingError("Expected virtual device")
  }

  // Physical switch points (1.0 + switchover factors)
  let physicalZoomValues =
    [1.0] + device.virtualDeviceSwitchOverVideoZoomFactors.map(\.doubleValue)

  guard
    let wideIndex = device.constituentDevices
    .firstIndex(where: { $0.deviceType == .builtInWideAngleCamera }),
    wideIndex < physicalZoomValues.count
  else {
    throw HandlingError("No wide angle camera found")
  }

  // videoZoomFactor -> UI "x" (so that wide is 1x)
  let displayMultiplier = device.displayVideoZoomFactorMultiplier

  func makeLens(displayZoom: Double) -> Lens {
    Lens(
      title: makeZoomLabel(displayZoom),
      zoomValue: displayZoom / displayMultiplier
    )
  }

  // 1) Physical lenses
  var lenses: [Lens] = physicalZoomValues.map { zoom in
    makeLens(displayZoom: zoom * displayMultiplier)
  }
  let wideLens = lenses[wideIndex]

  // 2) Virtual crop lenses (e.g. 2x on 48MP wide)
  for (idx, physicalDevice) in device.constituentDevices.enumerated() {
    guard idx < physicalZoomValues.count else {
      assertionFailure("More constituent devices than physical zoom values")
      continue
    }
    let base = physicalZoomValues[idx]
    let cropFactors = Set(physicalDevice.formats.flatMap(\.secondaryNativeResolutionZoomFactors))
    for f in cropFactors {
      let displayZoom = base * f * displayMultiplier
      if displayZoom < 1 { continue } // 0.9x on 17 Pro
      lenses.append(makeLens(displayZoom: displayZoom))
    }
  }

  // Dedup by label
  var seenTitles = Set<String>()
  lenses = lenses
    .sorted(using: KeyPathComparator(\.zoomValue))
    .filter { lens in
      seenTitles.insert(lens.title).inserted
    }

  return (lenses, wideLens)
}

private func makeZoomLabel(_ x: Double) -> String {
  let rounded = (x * 10).rounded() / 10
  return if rounded.truncatingRemainder(dividingBy: 1) == 0 {
    "\(Int(rounded))x"
  } else {
    "\(rounded)x"
  }
}
