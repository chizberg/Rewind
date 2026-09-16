//
//  MagicOverlay.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 16. 9. 2026.
//

import SwiftUI

struct MagicOverlay: View {
  var image: UIImage
  var origin: CGPoint
  var isActive: Bool
  var tuning: MagicTuning

  @State
  private var isShown = false
  @State
  private var reveal = 0.0
  @State
  private var strength = 1.0
  @State
  private var start = Date()
  @State
  private var activations = 0

  var body: some View {
    ZStack {
      if isShown {
        TimelineView(.animation) { context in
          Image(uiImage: image)
            .resizable()
            .modifier(MagicEffect(
              origin: origin,
              tuning: tuning,
              time: context.date.timeIntervalSince(start),
              reveal: reveal,
              strength: strength,
            ))
        }
        .transition(.identity)
        .onAppear {
          withAnimation(.easeInOut(duration: tuning.duration)) {
            reveal = 1
          }
        }
      }
    }
    .onChange(of: isActive, initial: true) { _, isActive in
      if isActive {
        activations += 1
        start = Date()
        isShown = true
        withAnimation(.easeInOut(duration: tuning.duration)) {
          strength = 1
        }
      } else if isShown {
        let activation = activations
        withAnimation(.easeInOut(duration: tuning.duration)) {
          strength = 0
        } completion: {
          guard activation == activations else { return }
          isShown = false
          reveal = 0
          strength = 1
        }
      }
    }
  }
}
