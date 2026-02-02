//
//  CustomSegmentedControl.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 6. 1. 2026.
//

import SwiftUI

struct CustomSegmentedControl<Item: Identifiable, Content: View>: View {
  var items: [Item]
  @Binding
  var pickedItem: Item
  var content: (Item, Bool) -> Content
  var spacing: CGFloat = 0
  @Namespace
  private var namespace

  var body: some View {
    HStack(spacing: spacing) {
      ForEach(items) { item in
        let isSelected = item.id == pickedItem.id
        content(item, isSelected)
          .contentShape(Rectangle())
          .onTapGesture {
            pickedItem = item
          }
          .background {
            if isSelected {
              Capsule().fill(.background.opacity(0.9))
                .matchedGeometryEffect(id: "selected-bg", in: namespace)
            }
          }
      }
    }
    .animation(.default, value: pickedItem.id)
    .padding(3)
    .modify { view in
      if #available(iOS 26.0, *) {
        view.glassEffect(in: Capsule())
      } else {
        view.background(.ultraThinMaterial, in: Capsule())
      }
    }
  }
}

#if DEBUG
private var items = ["foo", "bar", "baz"].map { Identified(value: $0) }

#Preview {
  @Previewable @State
  var pickedItem = items[0]

  ZStack {
    Image(uiImage: .cat).resizable().ignoresSafeArea()

    CustomSegmentedControl(
      items: items,
      pickedItem: $pickedItem
    ) { item, isSelected in
      Text(item.value)
        .font(isSelected ? .body.bold() : .body)
        .foregroundStyle(isSelected ? .yellow : .gray)
        .padding(10)
    }
  }
}
#endif
