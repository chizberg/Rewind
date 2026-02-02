//
//  SearchView.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 3. 12. 2025.
//

import SwiftUI

struct SearchView: View {
  var store: SearchViewStore

  @FocusState
  var searchFieldFocused: Bool
  @Environment(\.colorScheme)
  var colorScheme

  var body: some View {
    NavigationStack {
      List(store.suggests) { suggest in
        SuggestCell(
          suggest: suggest,
          onSelected: { store(.suggestSelected(suggest)) },
          addToQuery: { store(.addSuggestToQuery(suggest)) }
        )
      }
      .allowsHitTesting(!store.suggests.isEmpty)
      .overlay { overlayView }
      .navigationTitle("Search")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          ToolbarBackButton()
        }
      }
      .safeAreaInset(edge: .bottom) { searchBar }
      .alert(store.binding(\.alertModel, send: { _ in .dismissAlert }))
      .onAppear {
        searchFieldFocused = true
      }
    }
  }

  private var searchBar: some View {
    HStack {
      HStack {
        TextField(
          "Search for location",
          text: store.binding(\.query, send: { .updateQuery($0) })
        ).focused($searchFieldFocused)
          .submitLabel(.search)
          .onSubmit {
            store(.submit)
          }

        if !store.query.isEmpty {
          Button {
            store(.updateQuery(""))
          } label: {
            Image(systemName: "xmark.circle.fill")
          }.foregroundStyle(.secondary)
        }
      }
      .padding(10)
      .padding(.horizontal, 5)
      .background { searchBarBackground }

      if searchFieldFocused {
        Button {
          searchFieldFocused = false
        } label: {
          Image(systemName: "xmark")
            .padding(10)
        }
        .foregroundStyle(.primary)
        .background { searchBarBackground }
        .transition(.scale)
      }
    }
    .shadow(
      color: colorScheme == .light ? .black.opacity(0.1) : .clear,
      radius: 20, x: 0, y: 0
    )
    .padding()
    .animation(.spring, value: searchFieldFocused)
  }

  @ViewBuilder
  private var overlayView: some View {
    if let (emoji, title) = makeOverlayContents() {
      VStack(spacing: 10) {
        Text(emoji).font(.largeTitle)
        Text(title).fontWeight(.semibold)
      }.padding()
    }
  }

  private func makeOverlayContents() -> (String, LocalizedStringKey)? {
    if store.suggests.isEmpty, store.query.isEmpty {
      ("🔎", "Start typing")
    } else {
      nil
    }
  }

  @ViewBuilder
  private var searchBarBackground: some View {
    if #available(iOS 26, *) {
      GlassView(radius: searchBarRadius)
    } else {
      BlurView(radius: searchBarRadius)
    }
  }
}

private let searchBarRadius: CGFloat = 20

private struct SuggestCell: View {
  var suggest: SearchState.Suggest
  var onSelected: () -> Void
  var addToQuery: () -> Void

  var body: some View {
    HStack {
      HStack {
        VStack(alignment: .leading) {
          Text(suggest.title)
          if !suggest.subtitle.isEmpty {
            Text(suggest.subtitle)
              .font(.caption)
          }
        }

        Color.clear
      }
      .contentShape(Rectangle())
      .onTapGesture {
        onSelected()
      }

      Button {
        addToQuery()
      } label: {
        Image(systemName: "arrow.down.left.circle")
          .padding(5)
      }
      .foregroundColor(.primary)
    }
  }
}

#if DEBUG
#Preview {
  @Previewable @State
  var store = makeSearchModel(
    onLocationFound: { print("woohoo location", $0) }
  ).viewStore.bimap(
    state: { $0 },
    action: { .external($0) }
  )

  SearchView(store: store)
}

#Preview("cell") {
  List {
    SuggestCell(
      suggest: SearchState.Suggest(
        title: "Belgrade",
        subtitle: "Serbia"
      ),
      onSelected: { print("selected") },
      addToQuery: { print("add to query") }
    )
  }
}
#endif
