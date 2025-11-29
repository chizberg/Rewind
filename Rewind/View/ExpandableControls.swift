//
//  ExpandableControls.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 16.2.25..
//

import SwiftUI

struct ExpandableControls: View {
  struct StaticItem: Identifiable {
    var id: String
    var iconName: String
    var action: () -> Void
  }

  @Binding
  var yearRange: ClosedRange<Int>
  @Binding
  var mapType: MapType
  var staticItems: [StaticItem]

  var body: some View {
    ExpandableStack(
      items: [
        .init(id: "year selector") { isExpanded in
          expandableItemView(
            iconName: "calendar.badge.clock",
            expandedContent: {
              YearSelector(yearRange: $yearRange)
                .padding(.leading, 10)
            },
            isExpanded: isExpanded
          )
        },
        .init(id: "map type picker") { isExpanded in
          expandableItemView(
            iconName: "square.3.layers.3d.top.filled",
            expandedContent: {
              MapTypePicker(mapType: $mapType)
                .padding(.leading, 10)
            },
            isExpanded: isExpanded
          )
        },
      ],
      staticContent: {
        ForEach(staticItems) {
          minimizedButton(
            iconName: $0.iconName,
            action: $0.action
          ).background {
            makeBackground(radius: minimizedRadius)
          }
        }
      }
    )
  }

  private func expandableItemView(
    iconName: String,
    @ViewBuilder expandedContent: @escaping () -> some View,
    isExpanded: Binding<Bool>
  ) -> some View {
    ExpandableView(
      isExpanded: isExpanded,
      minimized: { expand in
        minimizedButton(
          iconName: iconName,
          action: expand
        )
      },
      expanded: { minimize in
        HStack {
          expandedContent()

          closeButton(action: minimize)
        }
        .padding(3)
      },
      background: {
        makeBackground(radius: isExpanded.wrappedValue ? expandedRadius : minimizedRadius)
      }
    )
  }

  @ViewBuilder
  private func makeBackground(radius: CGFloat) -> some View {
    if #available(iOS 26, *) {
      GlassView(radius: radius)
    } else {
      BlurView(style: .systemThickMaterial, radius: radius)
    }
  }

  private func minimizedButton(
    iconName: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: iconName)
        .font(.title2.weight(.semibold))
        .padding(10)
        .contentShape(Rectangle())
    }.foregroundStyle(iconColor)
  }

  private func closeButton(action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: "xmark")
        .font(.title2)
        .padding()
        .contentShape(Rectangle())
        .background {
          RoundedRectangle(cornerRadius: expandedRadius - 3)
            .fill(Color.systemBackground.opacity(0.5))
        }
    }.foregroundStyle(iconColor)
  }

  private var iconColor: Color {
    .primary.opacity(0.8)
  }
}

private let minimizedRadius: CGFloat = 25
private let expandedRadius: CGFloat = 30

private struct MapTypePicker: View {
  @Binding
  var mapType: MapType

  var body: some View {
    Picker("Map type", selection: $mapType) {
      Text("Scheme").tag(MapType.standard)
      Text("Satellite").tag(MapType.satellite)
      Text("Hybrid").tag(MapType.hybrid)
    }
    .pickerStyle(.segmented)
  }
}

private struct ExpandableStack<StaticContent: View>: View {
  struct Item: Identifiable, Equatable {
    typealias ID = String

    var id: ID
    var view: (Binding<Bool>) -> AnyView

    init(
      id: String,
      @ViewBuilder content: @escaping (Binding<Bool>) -> some View
    ) {
      self.id = id
      self.view = { binding in
        AnyView(content(binding))
      }
    }

    static func ==(lhs: Item, rhs: Item) -> Bool {
      lhs.id == rhs.id
    }
  }

  init(
    items: [Item],
    @ViewBuilder staticContent: () -> StaticContent
  ) {
    self.items = items
    self.staticContent = staticContent()
  }

  private var items: [Item]
  private var staticContent: StaticContent

  @Namespace
  private var namespace
  @State
  private var expandedItems = [Item]()

  var body: some View {
    VStack(alignment: .leading) {
      // minimized
      HStack {
        ForEach(items) { item in
          if !expandedItems.contains(item) {
            item.view(expansionBinding(item))
              .matchedGeometryEffect(id: item.id, in: namespace)
          }
        }

        Spacer()

        staticContent
      }
      // expanded
      VStack {
        ForEach(expandedItems.reversed()) { item in
          item.view(expansionBinding(item))
            .matchedGeometryEffect(id: item.id, in: namespace)
        }
      }
    }
  }

  private func expansionBinding(_ item: Item) -> Binding<Bool> {
    Binding(
      get: { expandedItems.contains(item) },
      set: { isExpanded in
        withAnimation(.spring(duration: 0.4)) {
          if isExpanded {
            expandedItems.append(item)
          } else {
            expandedItems.removeAll { $0 == item }
          }
        }
      }
    )
  }
}

// TODO: fix animations
private struct ExpandableView<Minimized: View, Expanded: View, Background: View>: View {
  @Binding
  var isExpanded: Bool
  @ViewBuilder
  var minimized: (_ expand: @escaping () -> Void) -> Minimized
  @ViewBuilder
  var expanded: (_ minimize: @escaping () -> Void) -> Expanded
  @ViewBuilder
  var background: () -> Background

  var body: some View {
    VStack {
      if isExpanded {
        expanded( /* minimize: */ { isExpanded = false })
      }
      if !isExpanded {
        minimized( /* expand: */ { isExpanded = true })
      }
    }
    .background(background())
  }
}

#Preview {
  @Previewable @State
  var yearRange = 1826...2000

  @Previewable @State
  var mapType = MapType.standard

  ZStack(alignment: .bottom) {
    Image("cat")
      .resizable()
      .ignoresSafeArea()

    ExpandableControls(
      yearRange: $yearRange,
      mapType: $mapType,
      staticItems: [
        .init(id: "search", iconName: "magnifyingglass", action: {}),
        .init(id: "location", iconName: "location", action: {}),
      ]
    )
    .padding()
  }
}

#Preview("Picker") {
  @Previewable @State
  var mapType = MapType.standard

  MapTypePicker(mapType: $mapType)
}
