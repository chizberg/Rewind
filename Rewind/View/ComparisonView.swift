//
//  ComparisonView.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 9. 12. 2025..
//

import SwiftUI

struct ComparisonView: View {
  var style: ComparisonState.Style
  var oldImageData: Model.Image
  var oldImage: UIImage
  var captureState: ComparisonState.CaptureState?

  @State
  private var currentYear = Calendar.current.component(.year, from: .now)

  var body: some View {
    switch style {
    case .sideBySide:
      SideBySideView(
        oldYear: oldImageData.date.year,
        currentYear: currentYear,
        old: { ScaleToFillImage(image: oldImage) },
        new: { cameraPreview }
      )
    case .cardOnCard:
      CardOnCardView(
        oldYear: oldImageData.date.year,
        currentYear: currentYear,
        oldImageAspectRatio: oldImage.size.aspectRatio ?? 3 / 4,
        old: { ScaleToFillImage(image: oldImage) },
        new: { cameraPreview }
      )
    }
  }

  @ViewBuilder
  private var cameraPreview: some View {
    switch captureState {
    case let .taken(capture):
      ScaleToFillImage(image: capture)
    case let .viewfinder(view):
      ViewRepresentable { view }
    case .none:
      Color.clear.overlay { ProgressView() }
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

#if DEBUG
#Preview {
  @Previewable @State
  var style = ComparisonState.Style.cardOnCard

  VStack {
    ComparisonView(
      style: style,
      oldImageData: .mock,
      oldImage: .lyskovo,
      captureState: .taken(capture: .cat)
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
