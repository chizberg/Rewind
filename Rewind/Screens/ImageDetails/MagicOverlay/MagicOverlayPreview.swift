//
//  MagicOverlayPreview.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 16. 9. 2026.
//

import SwiftUI

#if DEBUG
#Preview("magic overlay") {
  MagicOverlayPreview()
}

private struct MagicOverlayPreview: View {
  @State
  private var tuning = MagicTuning.default
  @State
  private var colorizing = false
  @State
  private var origin = CGPoint.zero

  var body: some View {
    VStack(spacing: 0) {
      Image(.colorizationDemoBefore)
        .resizable()
        .overlay {
          MagicOverlay(
            image: UIImage(resource: .colorizationDemoBefore),
            origin: origin,
            isActive: colorizing,
            tuning: tuning,
          )
        }
        .scaledToFit()
        .onTapGesture { location in
          origin = location
          colorizing.toggle()
        }

      Text("Tap the photo to start or finish")
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.vertical, 8)

      ScrollView {
        VStack(spacing: 4) {
          slider("Blur", $tuning.blur, 0...60)
          slider("Glow", $tuning.glow, 0...1)
          slider("Blob size", $tuning.blobSize, 0.05...1)
          slider("Blob spread", $tuning.blobSpread, 0...0.6)
          slider("Blob speed", $tuning.blobSpeed, 0...2)
          slider("Hue speed", $tuning.hueSpeed, 0...0.5)
          slider("Dust gray", $tuning.dustGray, 0...1)
          slider("Dust amount", $tuning.dustAmount, 0...1)
          slider("Dust gap", $tuning.dustGap, 15...200)
          slider("Dust size", $tuning.dustSize, 0.2...4)
          slider("Dust life", $tuning.dustLife, 0.5...10)
          slider("Dust speed", $tuning.dustSpeed, 0...3)
          slider("Dust wander", $tuning.dustWander, 0...100)
          slider("Dust flow", $tuning.dustFlow, 0...600)
          slider("Sparkle share", $tuning.sparkleShare, 0...1)
          slider("Sparkle life", $tuning.sparkleLife, 0.1...2)
          slider("Exposure", $tuning.exposure, 0...4)
          slider("Wind", $tuning.wind, 0...300)
          slider("Edge", $tuning.edge, 1...400)
          slider("Duration", $tuning.duration, 0.1...4)
        }
        .padding(.horizontal)
      }
    }
  }

  private func slider(
    _ name: String,
    _ value: Binding<Double>,
    _ range: ClosedRange<Double>,
  ) -> some View {
    HStack {
      Text(name)
        .frame(width: 100, alignment: .leading)
      Slider(value: value, in: range)
      Text(value.wrappedValue.formatted(.number.precision(.fractionLength(2))))
        .monospacedDigit()
        .frame(width: 56, alignment: .trailing)
    }
    .font(.footnote)
  }
}
#endif
