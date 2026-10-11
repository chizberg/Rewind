//
//  FloatingMenu.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 4. 7. 2026..
//

import SwiftUI
import VGSLFundamentals

struct FloatingMenu: View {
  enum Item {
    enum Kind {
      case expandable
      case fixed
    }

    case timePicker
    case mapType
    case imageKind
  }

  struct State: Equatable {
    var expandedItems: [FloatingMenu.Item]
    var filters: ImageRequestFilters
    var mapType: MapType
    var locationAccessGranted: Bool
  }

  enum Action {
    case searchTap
    case locationTap
    case setFilters(ImageRequestFilters)
    case setMapType(MapType)
    case setExpandedItems([Item])
  }

  typealias Store = ViewStore<State, Action>

  var store: Store

  var body: some View {
    FloatingMenuImpl(expandedItems: store.expandedItems) {
      makeTimePicker(
        items: store.binding(\.expandedItems, send: { .setExpandedItems($0) }),
        filters: store.binding(\.filters, send: { .setFilters($0) })
      )

      let mapType = store.mapType
      FloatingMenuPicker(
        item: .mapType,
        iconName: mapType.isScheme ? "map" : "globe.europe.africa",
        selection: store.binding(\.mapType, send: { .setMapType($0) }),
        options: [
          .init(value: .scheme, title: "Scheme", iconName: "map"),
          .init(value: .hybrid, title: "Satellite", iconName: "globe.europe.africa"),
        ]
      )

      let imageKind = store.filters.imageKind
      FloatingMenuPicker(
        item: .imageKind,
        iconName: imageKind.isPhoto ? "paintbrush.pointed" : "paintbrush.pointed.fill",
        iconColor: imageKind.isPhoto ? buttonFgColor : .accentColor,
        selection: store.binding(\.filters.imageKind, send: { kind in
          var filters = store.filters
          filters.imageKind = kind
          return .setFilters(filters)
        }),
        options: [
          .init(value: .photo, title: "Photos", iconName: "camera"),
          .init(value: .painting, title: "Paintings", iconName: "paintbrush.pointed"),
        ]
      )
    }
  }
}

func makeFloatingMenuStore(
  appStore: AppModel.Store,
  mapStore: MapViewModel.Store
) -> FloatingMenu.Store {
  FloatingMenu.Store.merge(
    appStore,
    mapStore,
    stateTransform: { _, map in
      FloatingMenu.State(
        expandedItems: map.controls.expandedItems,
        filters: map.filters,
        mapType: map.mapType,
        locationAccessGranted: map.locationState.isAccessGranted,
      )
    },
    actionTransform: { (action: FloatingMenu.Action) in
      switch action {
      case .searchTap: .left(.search(.present))
      case .locationTap: .right(.locationButtonTapped)
      case let .setFilters(f): .right(.filtersChanged(f))
      case let .setMapType(mt): .right(.mapTypeSelected(mt))
      case let .setExpandedItems(i): .right(.controls(.setExpandedItems(i)))
      }
    }
  ).skipRepeats()
}

extension Either where T == AppAction, U == MapAction.External.UI {
  fileprivate func app(_ action: AppAction) -> Self {
    .left(action)
  }

  fileprivate func map(_ action: MapAction.External.UI) -> Self {
    .right(action)
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
    .animation(mapControlsAnimation, value: expandedItems)
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
  var foregroundColor: Color = buttonFgColor
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

private struct FloatingMenuPicker<Value: Hashable>: View {
  struct Option {
    var value: Value
    var title: LocalizedStringKey
    var iconName: String
  }

  var item: FloatingMenu.Item

  var iconName: String
  var iconColor: Color = buttonFgColor
  @Binding
  var selection: Value
  var options: [Option]

  @ScaledMetric(relativeTo: .title2)
  private var iconHeight: CGFloat = 27

  var body: some View {
    Menu {
      Picker(selection: $selection) {
        ForEach(options, id: \.value) { option in
          Label(option.title, systemImage: option.iconName)
            .tag(option.value)
        }
      } label: {
        EmptyView()
      }
    } label: {
      Image(systemName: iconName)
        .font(.title2.weight(.semibold))
        .frame(width: iconHeight, height: iconHeight)
        .foregroundStyle(iconColor)
    }
    .padding(10)
    .contentShape(Rectangle())
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
  var foregroundColor: Color = buttonFgColor
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
    }.foregroundStyle(buttonFgColor)
  }
}

private func makeTimePicker(
  items: Binding<[FloatingMenu.Item]>,
  filters: Binding<ImageRequestFilters>,
) -> some View {
  ExpandableMenuButton(
    item: .timePicker,
    iconName: "clock",
    foregroundColor: filters.wrappedValue.isRangeModified ? .accentColor : buttonFgColor,
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

private let buttonFgColor = Color.primary.opacity(0.8)

#if DEBUG
#Preview {
  @Previewable @State
  var store: ViewStore<FloatingMenu.State, FloatingMenu.Action> = Reducer(
    initial: FloatingMenu.State(
      expandedItems: [],
      filters: ImageRequestFilters.default,
      mapType: MapType.scheme,
      locationAccessGranted: true
    ),
    reduce: { state, action, _, _ in
      switch action {
      case .locationTap: print("location tapped")
      case .searchTap: print("search tapped")
      case let .setExpandedItems(i): state.expandedItems = i
      case let .setFilters(f): state.filters = f
      case let .setMapType(m): state.mapType = m
      }
    }
  ).viewStore

  @Previewable @Namespace
  var namespace

  ZStack(alignment: .bottom) {
    Image(.cat).resizable().ignoresSafeArea()

    FloatingMenu(
      store: store
    ).padding()
  }
}

#Preview("Picker") {
  @Previewable @State
  var mapType = MapType.scheme

  FloatingMenuPicker(
    item: .mapType,
    iconName: mapType.isScheme ? "map" : "globe.europe.africa",
    selection: $mapType,
    options: [
      .init(value: .scheme, title: "Scheme", iconName: "map"),
      .init(value: .hybrid, title: "Satellite", iconName: "globe.europe.africa"),
    ]
  )
}
#endif
