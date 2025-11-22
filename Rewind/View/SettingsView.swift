//
//  SettingsView.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 9. 11. 2025..
//

import SwiftUI
import VGSL

struct SettingsView: View {
  var store: ViewStore<SettingsState, SettingsViewAction.UI>

  @Environment(\.dismiss)
  private var dismiss

  var body: some View {
    NavigationStack {
      List {
        Section {
          makeToggle(
            "Show colors in cluster annotations",
            state: store.showYearColorInClusters,
            makeAction: { .setShowYearColorInClusters($0) }
          )
          makeToggle(
            "Open big cluster previews on tap",
            state: store.openClusterPreviews,
            makeAction: { .setOpenClusterPreviews($0) }
          )
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
          makeButton("Contact Support", action: .contactSupport)
          makeButton("View source code", action: .openRepo)
        } header: {
          Text("Links")
        } footer: {
          credits
        }
      }
      .navigationTitle("Settings")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          backButton
        }
      }
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
      Text("2025")
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
    state: Bool,
    makeAction: @escaping (Bool) -> SettingsViewAction.UI
  ) -> some View {
    Toggle(
      title,
      isOn: Binding(
        get: { state },
        set: { newValue in
          store(makeAction(newValue))
        }
      )
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
      initialValue: SettingsState(
        showYearColorInClusters: false,
        openClusterPreviews: false
      )
    ),
    urlOpener: { _ in }
  ).viewStore

  SettingsView(
    store: store
  )
}
#endif // DEBUG
