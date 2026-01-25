//
//  SettingsView.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 9. 11. 2025..
//

import SwiftUI
import VGSL

struct SettingsView: View {
  var store: SettingsViewStore

  @Environment(\.dismiss)
  private var dismiss

  var body: some View {
    NavigationStack {
      List {
        Section {
          makeToggle(
            "Show colors in cluster annotations",
            state: \.stored.showYearColorInClusters,
            makeAction: { .setShowYearColorInClusters($0) }
          )
          makeToggle(
            "Open big cluster previews on tap",
            state: \.stored.openClusterPreviews,
            makeAction: { .setOpenClusterPreviews($0) }
          )
        } header: {
          Text("Map")
        }

        if store.supportsAlternateIcons {
          Section {
            iconPicker
          } header: {
            Text("App Icon")
          }
        }

        Section {
          makeButton("View PastVu website", action: .openPastVu)
          makeButton("PastVu rules", action: .pastVuRules)
        } header: {
          Text("PastVu")
        } footer: {
          VStack(alignment: .leading) {
            Text("Rewind uses PastVu API to get the images")
            Text("This app would not be possible without PastVu")
          }
        }

        Section {
          makeButton("Contact developer", action: .contact)
          makeButton("View source code", action: .openRepo)
          makeButton("View in App Store", action: .viewInAppStore)
        } header: {
          Text("About")
        } footer: {
          credits
        }
      }
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          backButton
        }
      }
      .alert(store.binding(\.alert, send: { _ in .alert(.dismiss) }))
    }
  }

  private var credits: some View {
    VStack(alignment: .leading) {
      Text("Made by ") + Text(chizberg.description)
      Text("with a little help from:")
      ForEach(honorableMentions) { contributor in
        Text("• ") + Text(contributor.description)
      }
      Text(String())
      Text("☮️ & ❤️")
      Text("Rewind")
      Text("2026")
    }
  }

  // TODO: use list selection? afaik headers/footers are unavailable then
  private func makeButton(
    _ title: LocalizedStringKey,
    action: SettingsViewAction.UI
  ) -> some View {
    Button {
      store(action)
    } label: {
      HStack {
        Text(title)
        Spacer()
      }.contentShape(Rectangle())
    }
    .buttonStyle(.borderless)
    .foregroundStyle(.primary)
  }

  private func makeToggle(
    _ title: LocalizedStringKey,
    state: KeyPath<SettingsViewState, Bool>,
    makeAction: @escaping (Bool) -> SettingsViewAction.UI
  ) -> some View {
    Toggle(
      title,
      isOn: store.binding(state, send: { makeAction($0) })
    )
  }

  private var backButton: some View {
    Button {
      dismiss()
    } label: {
      Image(systemName: "chevron.left")
    }
    .foregroundStyle(.primary)
  }

  private var iconPicker: some View {
    ScrollView(.horizontal) {
      HStack {
        ForEach(Icon.allCases, id: \.self) { icon in
          IconView(icon: icon, isSelected: store.icon == icon)
            .contentShape(Rectangle())
            .onTapGesture {
              store(.iconSelected(icon))
            }
        }
      }
      .padding(12)
    }
    .showsIndicators(false)
    .listRowInsets(EdgeInsets())
  }
}

private struct IconView: View {
  var icon: Icon
  var isSelected: Bool

  var body: some View {
    VStack {
      Image(uiImage: icon.preview)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 80, height: 80)
        .padding(5)
        .background {
          if isSelected {
            RoundedRectangle(cornerRadius: 26)
              .fill(.blue)
              .transition(.scale)
          }
        }

      Text(icon.displayName)
        .font(isSelected ? .caption.bold() : .caption)
        .padding(.bottom, 5)
    }
    .animation(.smooth(duration: 0.3), value: isSelected)
  }
}

private struct Contributor: Identifiable {
  var username: String
  var rawURL: String

  var description: AttributedString {
    (try? AttributedString(markdown: "[@\(username)](\(rawURL))")) ?? AttributedString()
  }

  var id: String { username }
}

private let chizberg = Contributor(
  username: "chizberg",
  rawURL: "https://github.com/chizberg"
)
private let honorableMentions: [Contributor] = [
  Contributor(username: "lisa.iso", rawURL: "https://www.instagram.com/l.chizberg"),
  Contributor(username: "dmitriitrif", rawURL: "https://github.com/dmitriitrif"),
  Contributor(username: "Xelwow", rawURL: "https://github.com/xelwow"),
]

#if DEBUG
#Preview {
  @Previewable @State
  var store = makeSettingsViewModel(
    settings: ObservableProperty(
      initialValue: .default
    ),
    urlOpener: { _ in }
  ).viewStore.bimap(state: { $0 }, action: { .ui($0) })

  SettingsView(
    store: store
  )
}
#endif // DEBUG
