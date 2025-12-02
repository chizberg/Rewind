//
//  MapControlsHiding.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 30. 11. 2025..
//

import SwiftUI
import VGSL

enum MinimizationState {
  case normal
  case minimized(byUser: Bool = false) // can be minimized automatically or by user

  var isNormal: Bool {
    if case .normal = self { true } else { false }
  }

  var isMinimized: Bool {
    if case .minimized = self { true } else { false }
  }

  var isMinimizedByUser: Bool {
    if case .minimized(byUser: true) = self { true } else { false }
  }
}

private struct MinimizableContainer: ViewModifier {
  @Binding
  private var state: MinimizationState
  @Binding
  private var offset: CGFloat
  @Binding
  private var externalPullingProgress: CGFloat
  private var contentHeight: CGFloat
  private var glimpseHeight: CGFloat
  private var minPullLength: CGFloat
  private var onPull: Action

  private struct Pulling: Equatable {
    var progress: CGFloat
    var handled: Bool
  }

  @GestureState
  private var translation: CGFloat = 0
  @GestureState
  private var isVerticalDrag = false
  @GestureState
  private var pulling = Pulling(progress: 0, handled: false)

  init(
    contentHeight: CGFloat,
    state: Binding<MinimizationState>,
    offset: Binding<CGFloat>,
    glimpseHeight: CGFloat,
    pullingProgress: Binding<CGFloat>,
    minPullLength: CGFloat,
    onPull: @escaping Action
  ) {
    _state = state
    _offset = offset
    _externalPullingProgress = pullingProgress
    self.contentHeight = contentHeight
    self.glimpseHeight = glimpseHeight
    self.minPullLength = minPullLength
    self.onPull = onPull
  }

  func body(content: Content) -> some View {
    content
      .overlay {
        if state.isMinimized {
          Color.clear
            .contentShape(Rectangle())
            .onTapGesture {
              state = .normal
            }
        }
      }
      .scrollDisabled(isVerticalDrag)
      .simultaneousGesture(gesture)
      .onChange(of: state.isMinimized) {
        updateOffset(state: state, translation: translation)
      }
      .onChange(of: translation) {
        updateOffset(state: state, translation: translation)
      }
      .onChange(of: pulling) {
        externalPullingProgress = pulling.progress
      }
  }

  var gesture: some Gesture {
    DragGesture()
      .updating($translation) { value, state, _ in
        state = if value.isVertical, value.isNotAccidental {
          value.translation.height
        } else { 0 }
      }
      .updating($isVerticalDrag) { value, state, _ in
        state = value.isVertical && value.isNotAccidental
      }
      .updating($pulling) { value, pulling, _ in
        if value.isVertical,
           state.isNormal {
          pulling.progress = (value.translation.height / -minPullLength).clamped(in: 0...1)
          if pulling.progress.isApproximatelyEqualTo(1), !pulling.handled {
            onPull()
            pulling.handled = true
          }
        } else {
          pulling.progress = 0
        }
      }
      .onEnded { gesture in
        guard gesture.isVertical else { return }
        switch state {
        case .normal:
          let diff = offset(for: .minimized()) - offset(for: .normal)
          if gesture.translation.height >= diff * minimizeCoefficient
            || gesture.predictedEndLocation.y >= diff * minimizeAccelerationCoefficient {
            state = .minimized(byUser: true)
          }
        case .minimized:
          let diff = offset(for: .normal) - offset(for: .minimized())
          if gesture.translation.height <= diff * maximizeCoefficient
            || gesture.predictedEndLocation.y <= diff {
            state = .normal
          }
        }
      }
  }

  private func updateOffset(
    state: MinimizationState, translation: CGFloat
  ) {
    offset = offset(for: state) + translation
  }

  private func offset(for state: MinimizationState) -> CGFloat {
    switch state {
    case .normal: 0
    case .minimized: contentHeight - glimpseHeight
    }
  }
}

private let minimizeCoefficient: CGFloat = 0.6
private let minimizeAccelerationCoefficient: CGFloat = 2
private let maximizeCoefficient: CGFloat = 0.3
private let translationThreshold: CGFloat = 10

extension DragGesture.Value {
  fileprivate var isVertical: Bool {
    abs(translation.height) > abs(translation.width)
  }

  fileprivate var isNotAccidental: Bool {
    abs(translation.height) > translationThreshold
  }
}

extension View {
  func minimizable(
    contentHeight: CGFloat,
    state: Binding<MinimizationState>,
    offset: Binding<CGFloat>,
    glimpseHeight: CGFloat,
    pullingProgress: Binding<CGFloat>,
    minPullLength: CGFloat,
    onPull: @escaping Action
  ) -> some View {
    modifier(
      MinimizableContainer(
        contentHeight: contentHeight,
        state: state,
        offset: offset,
        glimpseHeight: glimpseHeight,
        pullingProgress: pullingProgress,
        minPullLength: minPullLength,
        onPull: onPull
      )
    )
  }
}

#if DEBUG
#Preview {
  @Previewable @State
  var state: MinimizationState = .normal
  @Previewable @State
  var offset: CGFloat = 0
  @Previewable @State
  var pullingProgress: CGFloat = 0

  VStack {
    Spacer()
    Text("Pulling progress: \(pullingProgress)")
    Spacer()

    LinearGradient(
      colors: [.blue, .white],
      startPoint: .top,
      endPoint: .bottom
    )
    .frame(height: 325)
    .offset(y: offset)
    .minimizable(
      contentHeight: 325,
      state: $state,
      offset: $offset,
      glimpseHeight: 100,
      pullingProgress: $pullingProgress,
      minPullLength: 200,
      onPull: { print("pulled") }
    )
    .animation(.default, value: offset)
  }
}
#endif
