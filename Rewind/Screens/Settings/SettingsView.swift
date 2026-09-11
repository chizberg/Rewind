//
//  SettingsView.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 9. 11. 2025.
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
            "Open big cluster previews on tap",
            state: \.stored.openClusterPreviews,
            makeAction: { .setOpenClusterPreviews($0) },
          )
        } header: {
          Text("Map")
        }

        Section {
          makeLink("Colorization Model", action: .colorizationPicker(.present))
        } header: {
          Text("Image Colorization")
        }

        if store.ui.supportsAlternateIcons {
          Section {
            iconPicker
          } header: {
            Text("App Icon")
          }
        }

        Section {
          gradientSchemePicker
        } header: {
          Text("Gradient Picker")
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
      .alert(store.binding(\.ui.alert, send: { _ in .alert(.dismiss) }))
      .navigationDestination(
        item: store.binding(
          \.ui.colorizationPicker,
          send: { _ in .colorizationPicker(.dismiss) }
        ),
      ) { picker in
        ColorizationPickerScreen(store: picker.value)
          .navigationTitle("Colorization Model")
          .navigationBarTitleDisplayMode(.inline)
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
      Text("2026")
    }
  }

  // TODO: use list selection? afaik headers/footers are unavailable then
  private func makeButton(
    _ title: LocalizedStringKey,
    action: SettingsViewAction.UI,
  ) -> some View {
    makeRow(title, action: action) {
      EmptyView()
    }
  }

  private func makeLink(
    _ title: LocalizedStringKey,
    action: SettingsViewAction.UI,
  ) -> some View {
    makeRow(title, action: action) {
      Image(systemName: "chevron.right")
        .font(.footnote.bold())
        .foregroundStyle(.tertiary)
    }
  }

  private func makeRow(
    _ title: LocalizedStringKey,
    action: SettingsViewAction.UI,
    @ViewBuilder accessory: () -> some View,
  ) -> some View {
    Button {
      store(action)
    } label: {
      HStack {
        Text(title)
        Spacer()
        accessory()
      }.contentShape(Rectangle())
    }
    .buttonStyle(.borderless)
    .foregroundStyle(.primary)
  }

  private func makeToggle(
    _ title: LocalizedStringKey,
    state: KeyPath<SettingsViewState, Bool>,
    makeAction: @escaping (Bool) -> SettingsViewAction.UI,
  ) -> some View {
    Toggle(
      title,
      isOn: store.binding(state, send: { makeAction($0) }),
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
          IconView(icon: icon, isSelected: store.ui.icon == icon)
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

  private var gradientSchemePicker: some View {
    ForEach(GradientScheme.allCases, id: \.self) { scheme in
      let isSelected = store.stored.gradientScheme == scheme
      HStack(spacing: 10) {
        VStack(alignment: .leading) {
          GradientSchemeView(scheme)
            .frame(height: 30)
            .cornerRadius(10)
            .overlay {
              HStack {
                Text(scheme.title)
                  .font(isSelected ? .body.bold() : .body)
                  .foregroundStyle(.white)
                Spacer()
              }
              .padding(.horizontal, 10)
            }
        }

        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(isSelected ? .blue : .secondary.opacity(0.5))
      }
      .contentShape(Rectangle())
      .onTapGesture { store(.gradientSchemeSelected(scheme)) }
    }
  }
}

private struct IconView: View {
  var icon: Icon
  var isSelected: Bool

  var body: some View {
    VStack {
      Image(uiImage: icon.preview)
        .resizable()
        .scaledToFit()
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
  rawURL: "https://github.com/chizberg",
)
private let honorableMentions: [Contributor] = [
  Contributor(username: "lisa.iso", rawURL: "https://www.instagram.com/l.chizberg"),
  Contributor(username: "dmitriitrif", rawURL: "https://github.com/dmitriitrif"),
  Contributor(username: "Xelwow", rawURL: "https://github.com/xelwow"),
]

#if DEBUG
#Preview {
  @Previewable @State
  var store = makeSettingsViewStore(
    settings: ObservableProperty(
      initialValue: .default,
    ),
    urlOpener: { _ in },
    makeColorizationPicker: { .mock(.mock) },
  )

  SettingsView(
    store: store,
  )
}
#endif // DEBUG
