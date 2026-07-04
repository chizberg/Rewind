//
//  FloatingMenu.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 4. 7. 2026..
//

import SwiftUI

struct FloatingMenu: View {
  enum Item {
    enum Kind {
      case expandable
      case fixed
    }

    case timePicker
    case mapType
    case imageKind
    case search
    case location
  }

  @Binding
  var expandedItems: [Item]
  @Binding
  var filters: ImageRequestFilters
  @Binding
  var mapType: MapType
  var onSearchTap: () -> Void
  var locationAccessGranted: Bool
  var onLocationTap: () -> Void
  var namespace: Namespace.ID

  var body: some View {
    FloatingMenuImpl(expandedItems: expandedItems) {
      makeTimePicker(items: $expandedItems, filters: $filters)

      FloatingMenuButton(
        item: .mapType,
        iconName: mapType.isScheme ? "map" : "globe.europe.africa",
        action: {
          switch mapType {
          case .scheme: mapType = .satellite
          case .satellite: mapType = .scheme
          }
        }
      )
      FloatingMenuButton(
        item: .imageKind,
        iconName: filters.imageKind.isPhoto ? "camera" : "paintbrush.pointed",
        foregroundColor: filters.imageKind.isPainting ? .accentColor : iconColor,
        action: {
          switch filters.imageKind {
          case .painting: filters.imageKind = .photo
          case .photo: filters.imageKind = .painting
          }
        }
      )

      Spacer()

      FloatingMenuButton(
        item: .search,
        iconName: "magnifyingglass",
        action: onSearchTap
      )
      .overlay { // 🩼 otherwise transitionSource conflicts with liquid glass effect
        Color.clear
          .contentShape(Rectangle())
          .allowsHitTesting(false)
          .matchedTransitionSource(
            id: RootView.TransitionSource.search,
            in: namespace
          )
      }

      FloatingMenuButton(
        item: .location,
        iconName: locationAccessGranted ? "location" : "location.slash",
        action: onLocationTap
      )
    }
  }
}

private struct FloatingMenuImpl<Content: View>: View {
  var expandedItems: [FloatingMenu.Item]
  @ViewBuilder
  var content: Content

  @Namespace
  private var namespace

  var body: some View {
    VStack(alignment: .leading) {
      HStack {
        ForEach(subviews: content) { subview in
          let id = subview.containerValues.itemID
          switch subview.containerValues.kind {
          case .fixed:
            subview
              .ifLet(id) { view, id in
                view.glassID(id, in: namespace)
              }
          case .expandable:
            if let id, !expandedItems.contains(id) {
              subview
                .glassID(id, in: namespace)
                .matchedGeometryEffect(id: id, in: namespace)
            }
          }
        }
      }
      ForEach(subviews: content) { subview in
        if let id = subview.containerValues.itemID,
           expandedItems.contains(id) {
          subview
            .glassID(id, in: namespace)
            .matchedGeometryEffect(id: id, in: namespace)
        }
      }
    }
    .modify { view in
      if #available(iOS 26, *) {
        GlassEffectContainer { view }
      } else {
        view
      }
    }
    .animation(.smooth, value: expandedItems)
  }
}

extension ContainerValues {
  @Entry
  fileprivate var itemID: FloatingMenu.Item? = nil
  @Entry
  fileprivate var kind: FloatingMenu.Item.Kind = .fixed
}

private struct FloatingMenuButton: View {
  var item: FloatingMenu.Item
  var iconName: String
  var foregroundColor: Color = iconColor
  var action: () -> Void

  @ScaledMetric(relativeTo: .title2)
  private var iconSize: CGFloat = 27

  var body: some View {
    Button(action: action) {
      Image(systemName: iconName)
        .font(.title2.weight(.semibold))
        .frame(width: iconSize, height: iconSize)
        .padding(10)
        .contentShape(Rectangle())
    }
    .foregroundStyle(foregroundColor)
    .modifier(
      BackgroundModifier(isInteractive: true)
    )
    .containerValue(\.itemID, item)
    .containerValue(\.kind, .fixed)
  }
}

private struct ExpandableMenuButton<Expanded: View>: View {
  var item: FloatingMenu.Item
  var iconName: String
  var foregroundColor: Color = iconColor
  @Binding
  var isExpanded: Bool
  @ViewBuilder
  var expandedView: (Binding<Bool>) -> Expanded

  var body: some View {
    VStack {
      if isExpanded {
        expandedView($isExpanded)
      } else {
        FloatingMenuButton(
          item: item,
          iconName: iconName,
          foregroundColor: foregroundColor
        ) { isExpanded = true }
      }
    }
    .containerValue(\.itemID, item)
    .containerValue(\.kind, .expandable)
  }
}

private struct CloseButton: View {
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: "xmark")
        .font(.title2)
        .padding()
        .contentShape(Rectangle())
        .background {
          Capsule()
            .fill(Color.systemBackground.opacity(0.5))
        }
    }.foregroundStyle(iconColor)
  }
}

private func makeTimePicker(
  items: Binding<[FloatingMenu.Item]>,
  filters: Binding<ImageRequestFilters>,
) -> some View {
  ExpandableMenuButton(
    item: .timePicker,
    iconName: "clock",
    foregroundColor: filters.wrappedValue.isRangeModified ? .accentColor : iconColor,
    isExpanded: makeExpansionBinding(
      expandedItems: items,
      item: .timePicker
    ),
    expandedView: { isExpanded in
      HStack {
        YearSelector(
          yearRange: filters.yearRange
        )
        CloseButton(
          action: { isExpanded.wrappedValue = false }
        )
      }
      .padding(.leading, 10)
      .padding(3)
      .modifier(
        BackgroundModifier(isInteractive: false)
      )
    }
  )
}

private func makeExpansionBinding(
  expandedItems: Binding<[FloatingMenu.Item]>,
  item: FloatingMenu.Item
) -> Binding<Bool> {
  Binding(
    get: {
      expandedItems.wrappedValue.contains(item)
    },
    set: { isExpanded in
      if isExpanded {
        if !expandedItems.wrappedValue.contains(item) {
          expandedItems.wrappedValue.append(item)
        }
      } else {
        expandedItems.wrappedValue.removeAll { $0 == item }
      }
    },
  )
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

private struct BackgroundModifier: ViewModifier {
  var isInteractive: Bool

  func body(content: Content) -> some View {
    if #available(iOS 26, *) {
      content
        .glassEffect(
          .regular.interactive(isInteractive),
          in: Capsule()
        )
    } else {
      content
        .background {
          BlurView(style: .systemThinMaterial)
            .clipShape(Capsule())
        }
    }
  }
}

private let iconColor = Color.primary.opacity(0.8)

#if DEBUG
#Preview {
  @Previewable @State
  var expandedItems = [FloatingMenu.Item]()
  @Previewable @State
  var filters = ImageRequestFilters.default
  @Previewable @State
  var mapType = MapType.scheme
  @Previewable @State
  var locationAccessGranted = true
  @Previewable @Namespace
  var namespace

  ZStack(alignment: .bottom) {
    Image(.cat).resizable().ignoresSafeArea()

    FloatingMenu(
      expandedItems: $expandedItems,
      filters: $filters,
      mapType: $mapType,
      onSearchTap: { print("search tapped") },
      locationAccessGranted: locationAccessGranted,
      onLocationTap: { print("location tapped") },
      namespace: namespace
    ).padding()
  }
}
#endif
