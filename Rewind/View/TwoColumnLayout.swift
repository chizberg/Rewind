//
//  TwoColumnLayout.swift
//  Rewind
//
//  Created by Aleksei Sherstnev & ChatGPT on 23. 11. 2025..
//

import SwiftUI

// ai-generated
// https://chatgpt.com/share/692374a9-5138-8004-bce8-cd1ea6349151
struct TwoColumnLayout: Layout {
  var columnSpacing: CGFloat = 8
  var rowSpacing: CGFloat = 8

  struct Cache {
    var size: CGSize = .zero
    var frames: [CGRect] = []
    var width: CGFloat = 0
  }

  func makeCache(subviews _: Subviews) -> Cache { .init() }

  func sizeThatFits(
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout Cache
  ) -> CGSize {
    guard let width = proposal.width else { return .zero }

    if cache.width != width || cache.frames.count != subviews.count {
      let (size, frames) = computeLayout(width: width, subviews: subviews)
      cache.width = width
      cache.size = size
      cache.frames = frames
    }

    return cache.size
  }

  func placeSubviews(
    in bounds: CGRect,
    proposal _: ProposedViewSize,
    subviews: Subviews,
    cache: inout Cache
  ) {
    for (i, subview) in subviews.enumerated() {
      let f = cache.frames[i]
      subview.place(
        at: CGPoint(
          x: bounds.minX + f.minX,
          y: bounds.minY + f.minY
        ),
        proposal: ProposedViewSize(width: f.width, height: f.height)
      )
    }
  }

  private func computeLayout(
    width: CGFloat,
    subviews: Subviews
  ) -> (CGSize, [CGRect]) {
    var frames = Array(repeating: CGRect.zero, count: subviews.count)

    let columnWidth = (width - columnSpacing) / 2
    var y: CGFloat = 0
    var index = 0

    func isWide(_ idx: Int) -> Bool {
      let natural = subviews[idx].sizeThatFits(.unspecified)
      return natural.width > columnWidth
    }

    while index < subviews.count {
      // last element
      if index == subviews.count - 1 {
        let size = subviews[index]
          .sizeThatFits(.init(width: width, height: nil))
        frames[index] = CGRect(x: 0, y: y, width: width, height: size.height)
        y += size.height
        break
      }

      let left = index
      let right = index + 1

      // if the left one doesn't fit in the column — left on a full-width row
      if isWide(left) {
        let size = subviews[left]
          .sizeThatFits(.init(width: width, height: nil))
        frames[left] = CGRect(x: 0, y: y, width: width, height: size.height)
        y += size.height + rowSpacing
        index += 1
        continue
      }

      // if the right one doesn't fit in the column —
      // both left and right on separate full-width rows
      if isWide(right) {
        let leftSize = subviews[left]
          .sizeThatFits(.init(width: width, height: nil))
        frames[left] = CGRect(x: 0, y: y, width: width, height: leftSize.height)
        y += leftSize.height + rowSpacing

        let rightSize = subviews[right]
          .sizeThatFits(.init(width: width, height: nil))
        frames[right] = CGRect(x: 0, y: y, width: width, height: rightSize.height)
        y += rightSize.height + rowSpacing

        index += 2
        continue
      }

      // regular row
      let leftSize = subviews[left]
        .sizeThatFits(.init(width: columnWidth, height: nil))
      let rightSize = subviews[right]
        .sizeThatFits(.init(width: columnWidth, height: nil))

      let rowHeight = max(leftSize.height, rightSize.height)

      frames[left] = CGRect(
        x: 0,
        y: y,
        width: columnWidth,
        height: rowHeight
      )

      frames[right] = CGRect(
        x: columnWidth + columnSpacing,
        y: y,
        width: columnWidth,
        height: rowHeight
      )

      y += rowHeight + rowSpacing
      index += 2
    }

    if y > 0 { y -= rowSpacing } // remove last spacing

    return (CGSize(width: width, height: y), frames)
  }
}
