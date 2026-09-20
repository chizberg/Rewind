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
  @State
  private var viewSize = CGSize.zero

  var body: some View {
    ZStack {
      Color.systemBackground.ignoresSafeArea()
        .readSize {
          viewSize = $0
        }

      AxisStack(axis: axis) {
        Spacer(minLength: 0)
        Color.clear
          .aspectRatio(store.aspectRatio, contentMode: .fit)
          .overlay {
            ComparisonViewRepresentable(vc: deps.comparisonVC)
          }
          .modifier(BlinkingModifier(trigger: store.shotsCount))
        Spacer(minLength: 0)
      }

      VStack {
        SavedBanner(savesCount: store.savesCount)
        Spacer()
      }

      AxisStack(axis: axis) {
        Spacer()

        pickers
          .padding(axis == .vertical ? .bottom : .trailing, 20)
        bottomControls
          .padding(axis == .vertical ? .bottom : .trailing, 75)
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
    AxisStack(axis: axis.perpendicular) {
      CustomSegmentedControl(
        axis: axis.perpendicular,
        items: ComparisonState.Style.allCases,
        pickedItem: store.binding(\.style, send: { .setStyle($0) }),
        content: { style, isSelected in
          Image(systemName: style.iconName)
            .padding(10)
            .foregroundStyle(
              isSelected ? .yellow : .primary.opacity(0.7),
            )
        },
      )

      if let currentLens = store.currentLens,
         store.captureMode == .camera,
         store.captureState.isViewfinder,
         store.availableLens.count > 1 {
        CustomSegmentedControl(
          axis: axis.perpendicular,
          items: store.availableLens,
          pickedItem: Binding(get: { currentLens }, set: { store(.setLens($0)) }),
          content: { lens, isSelected in
            Text(lens.title)
              .monospaced()
              .padding(10)
              .foregroundStyle(
                isSelected ? .yellow : .primary.opacity(0.7),
              )
          },
        )
      }
    }
  }

  private var bottomControls: some View {
    ZStack {
      AxisStack(axis: axis.perpendicular) {
        DismissButton()
        Spacer()

        if store.captureState.isTaken {
          OverlayButton(iconName: "square.and.arrow.up") {
            store(.shareSheet(.present))
          }
        }
      }
      .padding(axis == .horizontal ? .vertical : .horizontal, 35)

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

  private var axis: Axis {
    if let viewRatio = viewSize.aspectRatio, viewRatio > store.aspectRatio {
      .horizontal
    } else {
      .vertical
    }
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
    context _: Context,
  ) -> CGSize? {
    uiViewController.view.sizeThatFits(CGSize(
      width: proposal.width ?? .infinity,
      height: proposal.height ?? .infinity,
    ))
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

extension Axis {
  fileprivate var perpendicular: Axis {
    switch self {
    case .horizontal: .vertical
    case .vertical: .horizontal
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

private let shutterButtonSize: CGFloat = 80

#if DEBUG
#Preview("camera") {
  @Previewable @State
  var deps = makeComparisonViewDeps(
    captureMode: .camera,
    oldUIImage: .panorama,
    oldImageData: .mock,
    streetViewAvailability: .mock(.unavailable),
  )

  ComparisonScreen(deps: deps)
}

#Preview("street view") {
  @Previewable @State
  var deps = makeComparisonViewDeps(
    captureMode: .streetView,
    oldUIImage: .panorama,
    oldImageData: .mock,
    streetViewAvailability: .mock(.available(year: 1826)),
  )

  ComparisonScreen(deps: deps)
}

#endif
