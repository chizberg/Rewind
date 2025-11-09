//
//  SettingsView.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 9. 11. 2025..
//

import SwiftUI

struct SettingsView: View {
  var store: ViewStore<SettingsState, SettingsAction>

  @Environment(\.dismiss)
  private var dismiss

  var body: some View {
    NavigationStack {
      List {
        Section {
          makeButton("Contact Support", action: .contactSupport)
          makeButton("View source code", action: .openRepo)
          makeButton("View PastVu website", action: .openPastVu)
          makeButton("PastVu rules", action: .pastVuRules)
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
      Text("Made by [@chizberg](https://github.com/chizberg)")
      Text(
        """
        with a little help from [@indie-contributor](https://github.com/indie-contributor) \
        and [@Xelwow](https://github.com/xelwow)
        """
      )
      Text("")
      Text("☮️ & ❤️")
      Text("Rewind")
      Text("2025")
    }
  }

  // TODO: use list selection? afaik headers/footers are unavailable then
  private func makeButton(
    _ title: LocalizedStringKey,
    action: SettingsAction
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

  private var backButton: some View {
    Button {
      dismiss()
    } label: {
      Image(systemName: "chevron.left")
    }
    .foregroundStyle(.primary)
  }
}

#Preview {
  @Previewable @State
  var store = makeSettingsModel(
    urlOpener: { _ in }
  ).viewStore

  SettingsView(
    store: store
  )
}
