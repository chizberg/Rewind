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
    case timePicker
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
    FloatingMenuImpl {
      makeTimePicker(
        items: store.binding(\.expandedItems, send: { .setExpandedItems($0) }),
        filters: store.binding(\.filters, send: { .setFilters($0) })
      )

      let mapType = store.mapType
      FloatingMenuPicker(
        iconName: mapType.isScheme ? "map" : "globe.europe.africa",
        selection: store.binding(\.mapType, send: { .setMapType($0) }),
        options: [
          .init(value: .scheme, title: "Scheme", iconName: "map"),
          .init(value: .hybrid, title: "Satellite", iconName: "globe.europe.africa"),
        ]
      )

      let imageKind = store.filters.imageKind
      FloatingMenuPicker(
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
  @ViewBuilder
  var content: Content

  var body: some View {
    HStack {
      content
    }
    .modify { view in
      if #available(iOS 26, *) {
        GlassEffectContainer { view }
      } else {
        view
      }
    }
  }
}

private struct FloatingMenuButton: View {
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
  }
}

private struct FloatingMenuPicker<Value: Hashable>: View {
  struct Option {
    var value: Value
    var title: LocalizedStringKey
    var iconName: String
  }

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
  }
}

private func makeTimePicker(
  items: Binding<[FloatingMenu.Item]>,
  filters: Binding<ImageRequestFilters>,
) -> some View {
  let isPresented = makeExpansionBinding(expandedItems: items, item: .timePicker)
  return FloatingMenuButton(
    iconName: "clock",
    foregroundColor: filters.wrappedValue.isRangeModified ? .accentColor : buttonFgColor,
    action: { isPresented.wrappedValue = true }
  )
  .popover(isPresented: isPresented, arrowEdge: .bottom) {
    YearSelector(yearRange: filters.yearRange)
      .frame(width: 320)
      .padding()
      .presentationCompactAdaptation(.popover)
  }
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
    iconName: mapType.isScheme ? "map" : "globe.europe.africa",
    selection: $mapType,
    options: [
      .init(value: .scheme, title: "Scheme", iconName: "map"),
      .init(value: .hybrid, title: "Satellite", iconName: "globe.europe.africa"),
    ]
  )
}
#endif
