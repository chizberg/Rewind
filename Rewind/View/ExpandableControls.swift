//
//  MapExpandableControls.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 16.2.25..
//

import SwiftUI

struct ExpandableControls: View {
  @Binding
  var yearRange: ClosedRange<Int>
  @Binding
  var mapType: MapType
  
  var body: some View {
    ExpandableStack(
      items: [
        .init(id: "year selector") { isExpanded in
          expandableItemView(
            iconName: "clock",
            expandedContent: {
              YearSelector(yearRange: $yearRange)
            },
            isExpanded: isExpanded
          )
        },
        .init(id: "map type picker") { isExpanded in
          expandableItemView(
            iconName: "map",
            expandedContent: {
              MapTypePicker(mapType: $mapType)
                .padding(.leading, 5)
            },
            isExpanded: isExpanded
          )
        }
      ]
    )
  }
  
  private func expandableItemView<Expanded: View>(
    iconName: String,
    @ViewBuilder expandedContent: @escaping () -> Expanded,
    isExpanded: Binding<Bool>
  ) -> some View {
    ExpandableView(
      isExpanded: isExpanded,
      minimized: { expand in
        Button(action: expand) {
          Image(systemName: iconName)
            .font(.title2.bold())
            .padding(10)
            .background(.black.opacity(0.3))
            .contentShape(Rectangle())
        }.foregroundStyle(.white)
      },
      expanded: { minimize in
        HStack {
          expandedContent()
          
          closeButton(action: minimize)
        }
        .padding(3)
      },
      background: { BlurView(style: .regular) },
      radius: isExpanded.wrappedValue ? 15 : 25
    )
  }
  
  private func closeButton(action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: "xmark")
        .padding()
        .contentShape(Rectangle())
        .background {
          RoundedRectangle(cornerRadius: 12)
            .fill(Color.systemBackground.opacity(0.3))
        }
    }
  }
}

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
                         
private struct ExpandableStack: View {
  struct Item: Identifiable, Equatable {
    typealias ID = String
    
    var id: ID
    var view: (Binding<Bool>) -> AnyView
    
    init<Content: View>(
      id: String,
      @ViewBuilder content: @escaping (Binding<Bool>) -> Content
    ) {
      self.id = id
      self.view = { binding in
        AnyView(content(binding))
      }
    }
    
    static func == (lhs: Item, rhs: Item) -> Bool {
      lhs.id == rhs.id
    }
  }
  
  var items: [Item]
  
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
      }
      // expanded
      VStack {
        ForEach(expandedItems.reversed()) { item in
          item.view(expansionBinding(item))
            .matchedGeometryEffect(id: item.id, in: namespace)
        }
      }
    }.animation(.spring(.init(duration: 0.4)), value: expandedItems)
  }
  
  private func expansionBinding(_ item: Item) -> Binding<Bool> {
    Binding(
      get: { expandedItems.contains(item) },
      set: { isExpanded in
        if isExpanded {
          expandedItems.append(item)
        } else {
          expandedItems.removeAll { $0 == item }
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
  var radius: CGFloat
  
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
    .clipShape(RoundedRectangle(cornerRadius: radius))
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
    
    ExpandableControls(yearRange: $yearRange, mapType: $mapType)
      .padding()
  }
}

#Preview("Picker") {
  @Previewable @State
  var mapType = MapType.standard
  
  MapTypePicker(mapType: $mapType)
}
