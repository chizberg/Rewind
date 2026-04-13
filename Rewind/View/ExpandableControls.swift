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
    var transitionSource: (id: String, namespace: Namespace.ID)?
    var action: () -> Void
  }

  @Binding
  var filters: ImageRequestFilters
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
              YearSelector(
                yearRange: $filters.yearRange,
                maxRange: filters.imageKind.maxRange,
              )
              .padding(.leading, 10)
            },
            isExpanded: isExpanded,
            isAccent: filters.isRangeModified,
          )
        },
        .init(id: "map type picker") { isExpanded in
          expandableItemView(
            iconName: "square.3.layers.3d.top.filled",
            expandedContent: {
              MapTypePicker(mapType: $mapType)
                .padding(.leading, 10)
            },
            isExpanded: isExpanded,
            isAccent: false,
          )
        },
        .init(id: "image kind picker") { isExpanded in
          expandableItemView(
            iconName: "paintbrush.pointed.fill",
            expandedContent: {
              ImageKindPicker(imageKind: $filters.imageKind)
                .padding(.leading, 10)
            },
            isExpanded: isExpanded,
            isAccent: filters.imageKind == .painting
          )
        },
      ],
      staticContent: {
        ForEach(staticItems) {
          minimizedButton(
            iconName: $0.iconName,
            action: $0.action,
            isAccent: false,
          )
          .ifLet($0.transitionSource) { view, source in
            view.matchedTransitionSource(
              id: source.id,
              in: source.namespace,
            )
          }
          .modifier(BackgroundModifier(
            radius: minimizedRadius,
            isInteractive: true
          ))
          .clipShape(Circle())
        }
      },
    ).modify { view in
      if #available(iOS 26, *) {
        GlassEffectContainer { view }
      } else {
        view
      }
    }
  }

  private func expandableItemView(
    iconName: String,
    @ViewBuilder expandedContent: @escaping () -> some View,
    isExpanded: Binding<Bool>,
    isAccent: Bool,
  ) -> some View {
    ExpandableView(
      isExpanded: isExpanded,
      minimized: { expand in
        minimizedButton(
          iconName: iconName,
          action: expand,
          isAccent: isAccent,
        )
      },
      expanded: { minimize in
        HStack {
          expandedContent()
          closeButton(action: minimize)
        }
        .padding(3)
      },
      background: BackgroundModifier(
        radius: isExpanded.wrappedValue ? expandedRadius : minimizedRadius,
        isInteractive: !isExpanded.wrappedValue,
      ),
    )
  }

  private func minimizedButton(
    iconName: String,
    action: @escaping () -> Void,
    isAccent: Bool,
  ) -> some View {
    Button(action: action) {
      Image(systemName: iconName)
        .font(.title2.weight(.semibold))
        .padding(10)
        .contentShape(Rectangle())
    }
    .foregroundStyle(isAccent ? Color.accentColor : iconColor)
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

private struct BackgroundModifier: ViewModifier {
  var radius: CGFloat
  var isInteractive: Bool

  func body(content: Content) -> some View {
    if #available(iOS 26, *) {
      content
        .glassEffect(
          .regular.interactive(isInteractive),
          in: RoundedRectangle(cornerRadius: radius)
        )
    } else {
      content
        .background {
          BlurView(style: .systemThinMaterial, radius: radius)
        }
    }
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

private struct ImageKindPicker: View {
  @Binding
  var imageKind: ImageRequestFilters.ImageKind

  var body: some View {
    Picker("Image kind", selection: $imageKind) {
      Text("Photos").tag(ImageRequestFilters.ImageKind.photo)
      Text("Paintings").tag(ImageRequestFilters.ImageKind.painting)
    }
    .pickerStyle(.segmented)
  }
}

extension View {
  @ViewBuilder
  fileprivate func glassID<ID: Hashable>(
    _ id: ID, in namespace: Namespace.ID
  ) -> some View {
    if #available(iOS 26, *) {
      self.glassEffectID(id, in: namespace)
    } else {
      self
    }
  }
}

private struct ExpandableStack<StaticContent: View>: View {
  struct Item: Identifiable, Equatable {
    typealias ID = String

    var id: ID
    var view: (Binding<Bool>) -> AnyView

    init(
      id: String,
      @ViewBuilder content: @escaping (Binding<Bool>) -> some View,
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
    @ViewBuilder staticContent: () -> StaticContent,
  ) {
    self.items = items
    self.staticContent = staticContent()
  }

  private var items: [Item]
  private var staticContent: StaticContent

  @Namespace
  private var namespace
  @State
  private var expandedIDs = [Item.ID]()

  var body: some View {
    VStack(alignment: .leading) {
      // minimized
      HStack {
        ForEach(items) { item in
          if !expandedIDs.contains(item.id) {
            item.view(expansionBinding(item))
              .glassID(item.id, in: namespace)
              .matchedGeometryEffect(id: item.id, in: namespace)
          }
        }

        Spacer()

        staticContent
      }
      // expanded
      VStack {
        ForEach(expandedIDs.reversed(), id: \.self) { id in
          if let item = items.first(where: { $0.id == id }) {
            item.view(expansionBinding(item))
              .glassID(item.id, in: namespace)
              .matchedGeometryEffect(id: item.id, in: namespace)
          }
        }
      }
    }
  }

  private func expansionBinding(_ item: Item) -> Binding<Bool> {
    Binding(
      get: { expandedIDs.contains(item.id) },
      set: { isExpanded in
        withAnimation(.spring(duration: 0.4)) {
          if isExpanded {
            expandedIDs.append(item.id)
          } else {
            expandedIDs.removeAll { $0 == item.id }
          }
        }
      },
    )
  }
}

// TODO: fix animations
private struct ExpandableView<
  Minimized: View,
  Expanded: View,
  Background: ViewModifier
>: View {
  @Binding
  var isExpanded: Bool
  @ViewBuilder
  var minimized: (_ expand: @escaping () -> Void) -> Minimized
  @ViewBuilder
  var expanded: (_ minimize: @escaping () -> Void) -> Expanded
  var background: Background

  var body: some View {
    VStack {
      if isExpanded {
        expanded( /* minimize: */ { isExpanded = false })
      }
      if !isExpanded {
        minimized( /* expand: */ { isExpanded = true })
      }
    }
    .modifier(background)
  }
}

#if DEBUG
#Preview {
  @Previewable @State
  var filters = ImageRequestFilters.default

  @Previewable @State
  var mapType = MapType.standard

  ZStack(alignment: .bottom) {
    Image(.cat).resizable().ignoresSafeArea()

    ExpandableControls(
      filters: $filters,
      mapType: $mapType,
      staticItems: [
        .init(id: "search", iconName: "magnifyingglass", action: {}),
        .init(id: "location", iconName: "location", action: {}),
      ],
    )
    .padding()
  }
}

#Preview("Picker") {
  @Previewable @State
  var mapType = MapType.standard

  MapTypePicker(mapType: $mapType)
}
#endif
