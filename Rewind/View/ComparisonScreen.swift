//
//  ComparisonScreen.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 5. 12. 2025.
//

import AVKit
import SwiftUI

struct ComparisonScreen: View {
  var deps: ComparisonViewDeps
  var store: ComparisonViewStore { deps.store }
  @Environment(\.dismiss)
  private var dismiss

  var body: some View {
    ZStack {
      Color.systemBackground.ignoresSafeArea()

      VStack {
        Color.clear
          .aspectRatio(4 / 6, contentMode: .fit) // two 4/3 images
          .overlay {
            ComparisonViewRepresentable(vc: deps.comparisonVC)
          }
        Spacer(minLength: 0)
      }

      VStack {
        SavedBanner(savesCount: store.savesCount)
        Spacer()
        pickers
          .padding(.bottom, 20)
        bottomControls
          .padding(.bottom, 75)
      }
    }
    .alert(store.binding(\.alert, send: { _ in .alert(.dismiss) }))
    .environment(\.colorScheme, .dark)
    .sheet(store.binding(\.shareVC, send: { _ in .shareSheet(.dismiss) }))
    .onCameraCaptureEvent { event in
      if event.phase == .ended {
        store(.shoot)
      }
    }
    .task {
      store(.viewWillAppear)
    }
    .onChange(of: store.shouldDismiss) {
      if store.shouldDismiss {
        dismiss()
      }
    }
  }

  private var pickers: some View {
    HStack {
      CustomSegmentedControl(
        items: ComparisonState.Style.allCases,
        pickedItem: store.binding(\.style, send: { .setStyle($0) }),
        content: { style, isSelected in
          Image(systemName: style.iconName)
            .padding(10)
            .foregroundStyle(
              isSelected ? .yellow : .primary.opacity(0.7)
            )
            .rotating(on: .phone, with: store.orientation)
        }
      )

      if let currentLens = store.currentLens,
         store.captureMode == .camera,
         store.captureState.isViewfinder,
         store.availableLens.count > 1 {
        CustomSegmentedControl(
          items: store.availableLens,
          pickedItem: Binding(get: { currentLens }, set: { store(.setLens($0)) }),
          content: { lens, isSelected in
            Text(lens.title)
              .monospaced()
              .padding(10)
              .foregroundStyle(
                isSelected ? .yellow : .primary.opacity(0.7)
              )
              .rotating(on: .phone, with: store.orientation)
          }
        )
      }
    }
  }

  private var bottomControls: some View {
    ZStack {
      HStack {
        BackButton()
        Spacer()

        if store.captureState.isTaken {
          OverlayButton(iconName: "square.and.arrow.up") {
            store(.shareSheet(.present))
          }
        }
      }
      .padding(.horizontal, 35)

      makeShutterButton(retake: store.captureState.isTaken)
    }
  }

  private func makeShutterButton(retake: Bool) -> some View {
    Button {
      store(retake ? .retake : .shoot)
    } label: {
      ZStack {
        let radius = shutterButtonSize / 2
        if #available(iOS 26, *) {
          GlassView(radius: radius)
        } else {
          BlurView(radius: radius)
        }

        Circle()
          .fill(.primary)
          .padding(6)

        if retake {
          Image(systemName: "arrow.clockwise")
            .font(.title)
            .foregroundStyle(.background)
            .offset(y: -2)
        }
      }
    }
    .foregroundStyle(.primary)
    .frame(squareSize: shutterButtonSize)
  }
}

private struct ComparisonViewRepresentable: UIViewControllerRepresentable {
  var vc: UIViewController

  func makeUIViewController(context _: Context) -> UIViewController {
    vc
  }

  func updateUIViewController(_: UIViewController, context _: Context) {}

  func sizeThatFits(
    _ proposal: ProposedViewSize,
    uiViewController: UIViewController,
    context _: Context
  ) -> CGSize? {
    uiViewController.view.sizeThatFits(CGSize(
      width: proposal.width ?? .infinity,
      height: proposal.height ?? .infinity
    ))
  }
}

private struct SavedBanner: View {
  var savesCount: Int

  var body: some View {
    HStack {
      Image(systemName: "photo.badge.checkmark")
      Text("Saved to Photos")
    }
    .padding()
    .blurBackground(in: Capsule())
    .padding(.top, 5)
    .modifier(AnimatedTopBanner(trigger: savesCount))
  }
}

private struct AnimatedTopBanner<T: Equatable>: ViewModifier {
  var trigger: T

  enum Phase: CaseIterable {
    case initial
    case shown
    case pause
    case hidden

    var yOffset: CGFloat {
      switch self {
      case .initial, .hidden: -200
      case .shown: 0
      case .pause: -5 // 🐞 if values are the same, they get ignored
      }
    }

    var opacity: CGFloat {
      switch self {
      case .initial, .hidden: 0
      case .shown, .pause: 1
      }
    }
  }

  func body(content: Content) -> some View {
    content
      .phaseAnimator(
        Phase.allCases,
        trigger: trigger,
        content: { content, currentPhase in
          content
            .offset(y: currentPhase.yOffset)
            .opacity(currentPhase.opacity)
        },
        animation: { nextPhase in
          switch nextPhase {
          case .initial: nil
          case .shown: .smooth
          case .pause: .smooth(duration: 2)
          case .hidden: .smooth
          }
        }
      )
  }
}

extension ComparisonState.Style: Identifiable {
  var id: Self { self }

  fileprivate var iconName: String {
    switch self {
    case .sideBySide: "rectangle.split.1x2"
    case .cardOnCard: "rectangle.on.rectangle"
    }
  }
}

private struct PickedStyleBackground: View {
  var body: some View {
    if #available(iOS 26, *) {
      Color.clear.glassEffect(in: Circle())
    } else {
      BlurView().clipShape(Circle())
    }
  }
}

extension View {
  // phone and pad have different orientation lock logic
  fileprivate func rotating(
    on idiom: UIUserInterfaceIdiom,
    with orientation: Orientation
  ) -> some View {
    modifyWithUIIdiom(idiom, transform: { $0.rotating(with: orientation) })
  }

  fileprivate func rotating(
    with orientation: Orientation
  ) -> some View {
    rotationEffect(.degrees(orientation.rotationAngle))
      .animation(.default, value: orientation)
  }
}

extension Orientation {
  var rotationAngle: CGFloat {
    switch self {
    case .portrait: 0
    case .landscapeLeft: 90
    case .landscapeRight: -90
    case .upsideDown: 180
    }
  }
}

private let shutterButtonSize: CGFloat = 80

#if DEBUG
#Preview("camera") {
  @Previewable @State
  var deps = makeComparisonViewDeps(
    captureMode: .camera,
    oldUIImage: .panorama,
    oldImageData: .mock,
    streetViewAvailability: .mock(.unavailable)
  )

  ComparisonScreen(deps: deps)
}

#Preview("street view") {
  @Previewable @State
  var deps = makeComparisonViewDeps(
    captureMode: .streetView,
    oldUIImage: .panorama,
    oldImageData: .mock,
    streetViewAvailability: .mock(.available(year: 1826))
  )

  ComparisonScreen(deps: deps)
}

#Preview("saved banner") {
  @Previewable @State
  var savesCount = 0

  ZStack {
    Image(.cat).resizable().ignoresSafeArea()

    VStack {
      SavedBanner(savesCount: savesCount)
      Spacer()
      Button("Simulate save") {
        savesCount += 1
      }.buttonStyle(.borderedProminent)
    }
  }
}
#endif
