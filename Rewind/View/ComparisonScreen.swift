//
//  ComparisonScreen.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 5. 12. 2025..
//

import SwiftUI

struct ComparisonScreen: View {
  var store: ComparisonViewStore

  var body: some View {
    ZStack {
      Color.systemBackground.ignoresSafeArea()

      VStack {
        Color.clear
          .aspectRatio(4 / 6, contentMode: .fit) // two 4/3 images
          .overlay {
            ComparisonView(
              style: store.style,
              oldImageData: store.oldImageData,
              oldImage: store.oldUIImage,
              cameraState: store.cameraState
            )
            .readSize { store(.comparisonViewSizeChanged($0)) }
          }
        Spacer(minLength: 0)
      }

      VStack {
        Spacer()
        stylePicker
          .padding(.bottom, 10)
        bottomControls
          .padding(.bottom, 75)
      }
    }
    .alert(store.binding(\.alert, send: { _ in .alert(.dismiss) }))
    .environment(\.colorScheme, .dark)
    .sheet(store.binding(\.shareVC, send: { _ in .shareSheet(.dismiss) }))
    .task {
      store(.viewWillAppear)
    }
  }

  private var stylePicker: some View {
    HStack(spacing: 0) {
      ForEach(ComparisonState.Style.allCases, id: \.self) { style in
        let isSelected = store.style == style
        Button {
          store(.setStyle(style))
        } label: {
          Image(systemName: style.iconName)
            .padding(10)
            .rotating(on: .phone, with: store.orientation)
            .if(isSelected) { view in
              view.background {
                PickedStyleBackground()
              }
            }
        }
        .foregroundStyle(
          isSelected ? .yellow : .primary.opacity(0.7)
        )
      }
    }
    .padding(3)
    .background {
      Capsule().fill(.background.opacity(0.5))
    }
    .padding(.bottom, 10)
  }

  private var bottomControls: some View {
    ZStack {
      HStack {
        BackButton()
        Spacer()

        if store.cameraState.isTaken {
          OverlayButton(iconName: "square.and.arrow.up") {
            store(.shareSheet(.present))
          }
        }
      }
      .padding(.horizontal, 35)

      makeShutterButton(retake: store.cameraState.isTaken)
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

extension ComparisonState.Style {
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
#Preview {
  @Previewable @State
  var store = makeComparisonModel(
    oldUIImage: .panorama,
    oldImageData: .mock
  ).viewStore.bimap(state: { $0 }, action: { .external($0) })

  ComparisonScreen(store: store)
}
#endif
