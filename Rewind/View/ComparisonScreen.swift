//
//  ComparisonScreen.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 5. 12. 2025..
//

import SwiftUI

struct ComparisonScreen: View {
  var store: ComparisonViewStore

  @State
  private var comparisonViewSize = CGSize.zero

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
              new: { cameraPreview }
            )
            .background(.background)
            .environment(\.colorScheme, .dark)
            .readSize {
              comparisonViewSize = $0
            }
            .rendering(
              onChangeOf: Pair(store.cameraState.isTaken, comparisonViewSize),
              condition: { $0.first },
              size: comparisonViewSize,
              to: { store(.resultRendered($0)) }
            )
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

  @ViewBuilder
  private var cameraPreview: some View {
    switch store.cameraState {
    case let .taken(capture, _):
      ScaleToFillImage(image: capture)
    case let .viewfinder(preview):
      ViewRepresentable { preview }
    case .none:
      Color.clear.overlay { ProgressView() }
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
          .rotating(on: .phone, with: store.orientation)
        Spacer()

        if store.cameraState.isTaken {
          OverlayButton(iconName: "square.and.arrow.up") {
            store(.shareSheet(.present))
          }
          .rotating(on: .phone, with: store.orientation)
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
        }
      }
    }
    .foregroundStyle(.primary)
    .frame(squareSize: shutterButtonSize)
  }
}

private struct ComparisonView<New: View>: View {
  var style: ComparisonState.Style
  var oldImageData: Model.Image
  var oldImage: UIImage
  @ViewBuilder var new: () -> New

  @State
  private var currentYear = Calendar.current.component(.year, from: .now)

  var body: some View {
    switch style {
    case .sideBySide:
      SideBySideView(
        oldYear: oldImageData.date.year,
        currentYear: currentYear,
        old: { ScaleToFillImage(image: oldImage) },
        new: new
      )
    case .cardOnCard:
      CardOnCardView(
        oldYear: oldImageData.date.year,
        currentYear: currentYear,
        oldImageAspectRatio: oldImage.size.aspectRatio ?? 3 / 4,
        old: { ScaleToFillImage(image: oldImage) },
        new: new
      )
    }
  }
}

private struct SideBySideView<Old: View, New: View>: View {
  var oldYear: Int
  var currentYear: Int
  @ViewBuilder var old: () -> Old
  @ViewBuilder var new: () -> New

  var body: some View {
    VStack(spacing: 0) {
      new()
        .aspectRatio(4 / 3, contentMode: .fit)

      HStack {
        Image(systemName: "chevron.up")
        Text(currentYear, format: .number.grouping(.never))
        Spacer()
        Text("Rewind <<")
        Spacer()
        Text(oldYear, format: .number.grouping(.never))
        Image(systemName: "chevron.down")
      }
      .font(.system(size: 11))
      .padding(.horizontal, 8)

      old()
        .aspectRatio(4 / 3, contentMode: .fit)
    }
  }
}

private struct CardOnCardView<Old: View, New: View>: View {
  var oldYear: Int
  var currentYear: Int
  var oldImageAspectRatio: CGFloat

  @ViewBuilder var old: () -> Old
  @ViewBuilder var new: () -> New

  private let scale: CGFloat = 0.6
  private let radius: CGFloat = 10

  var body: some View {
    ZStack {
      makeImageCard(anchor: .topLeading, content: new)
      makeImageCard(anchor: .bottomTrailing, content: old)
      makeLabel(anchor: .topTrailing, text: "< \(currentYear)")
      makeLabel(anchor: .bottomLeading, text: "\(oldYear) >")
    }
    .overlay(alignment: .topTrailing) {
      Text("Rewind <<")
        .font(.caption.monospaced())
        .opacity(0.5)
    }
    .padding(5)
  }

  private func makeLabel(
    anchor: UnitPoint,
    text: String
  ) -> some View {
    Color.clear
      .overlay {
        Text(text)
          // auto-sizing text
          .font(.system(size: 1000).monospaced().bold())
          .lineLimit(1)
          .minimumScaleFactor(0.01)
          .padding(10)
      }
      .aspectRatio(oldImageAspectRatio, contentMode: .fit)
      .scaleEffect(1 - scale, anchor: anchor)
  }

  private func makeImageCard(
    anchor: UnitPoint,
    content: () -> some View
  ) -> some View {
    content()
      .aspectRatio(oldImageAspectRatio, contentMode: .fit)
      .cornerRadius(radius)
      .overlay {
        RoundedRectangle(cornerRadius: radius)
          .stroke(style: StrokeStyle(lineWidth: 1))
      }
      .scaleEffect(scale, anchor: anchor)
  }
}

struct ScaleToFillImage: View {
  var image: UIImage

  var body: some View {
    Color.clear // fill, but only take the **available** space
      .overlay {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
      }
      .clipped()
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

  fileprivate func rendering<V: Equatable>(
    onChangeOf value: V,
    condition: @escaping (V) -> Bool,
    size: CGSize,
    to consumer: @escaping (UIImage?) -> Void
  ) -> some View {
    onChange(of: value) {
      if condition(value) {
        let renderer = ImageRenderer(
          content: self.frame(size: size)
        )
        renderer.scale = UIScreen.main.scale
        renderer.isOpaque = true
        consumer(renderer.uiImage)
      }
    }
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

#Preview("ComparisonView") {
  @Previewable @State
  var style = ComparisonState.Style.cardOnCard

  VStack {
    ComparisonView(
      style: style,
      oldImageData: .mock,
      oldImage: .lyskovo,
      new: { ScaleToFillImage(image: .cat) }
    )
    .background(.background)
    .environment(\.colorScheme, .dark)

    Picker("[Debug] pick a style", selection: $style) {
      ForEach(ComparisonState.Style.allCases, id: \.self) { style in
        Text(String(describing: style)).tag(style)
      }
    }.pickerStyle(.segmented)
      .padding()
  }
}
#endif
