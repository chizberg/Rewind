//
//  TwoColumnLayout.swift
//  Rewind
//
//  Created by Aleksei Sherstnev & ChatGPT on 23. 11. 2025.
//

import SwiftUI

// ai-generated
// https://chatgpt.com/share/692374a9-5138-8004-bce8-cd1ea6349151
struct TwoColumnLayout: Layout {
  var columnSpacing: CGFloat = 8
  var rowSpacing: CGFloat = 8

  func sizeThatFits(
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache _: inout (),
  ) -> CGSize {
    guard let width = proposal.width else { return .zero }
    let frames = makeFrames(width: width, subviews: subviews)
    return CGSize(width: width, height: frames.map(\.maxY).max() ?? 0)
  }

  func placeSubviews(
    in bounds: CGRect,
    proposal _: ProposedViewSize,
    subviews: Subviews,
    cache _: inout (),
  ) {
    let frames = makeFrames(width: bounds.width, subviews: subviews)
    for (subview, frame) in zip(subviews, frames) {
      subview.place(
        at: CGPoint(
          x: bounds.minX + frame.minX,
          y: bounds.minY + frame.minY,
        ),
        proposal: ProposedViewSize(frame.size),
      )
    }
  }

  private func makeFrames(
    width: CGFloat,
    subviews: Subviews,
  ) -> [CGRect] {
    let columnWidth = (width - columnSpacing) / 2
    let fitsColumn = subviews.map {
      $0.sizeThatFits(.unspecified).width <= columnWidth
    }

    var frames: [CGRect] = []
    var y: CGFloat = 0
    var index = 0
    while index < subviews.count {
      let isPair = index + 1 < subviews.count
        && fitsColumn[index] && fitsColumn[index + 1]
      let row = isPair ? [index, index + 1] : [index]
      let itemWidth = isPair ? columnWidth : width
      let rowHeight = row.map {
        subviews[$0].sizeThatFits(.init(width: itemWidth, height: nil)).height
      }.max() ?? 0

      for column in row.indices {
        frames.append(CGRect(
          x: CGFloat(column) * (columnWidth + columnSpacing),
          y: y,
          width: itemWidth,
          height: rowHeight,
        ))
      }
      y += rowHeight + rowSpacing
      index += row.count
    }
    return frames
  }
}

#Preview {
  let titles = [
    "Favorite", "Compare", "Compare with Google Street View",
    "Show on map", "Share", "Save image", "View on Web",
    "A very long button title that surely doesn't fit in one line of the screen width",
    "Find route",
  ]
  ScrollView {
    TwoColumnLayout {
      ForEach(titles, id: \.self) { title in
        HStack {
          Image(systemName: "star")
          Text(title)
          Spacer()
        }
        .padding(10)
        .frame(minHeight: 50)
        .background(Color.white)
        .cornerRadius(15)
      }
    }
    .background(.yellow)
    .padding(10)
    .background(Color.gray)
    .padding(.horizontal, 5)
  }
}
