//
//  SettingsViewModel.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 9. 11. 2025.
//

import UIKit
import VGSL

typealias SettingsViewModel = Reducer<SettingsViewState, SettingsViewAction>
typealias SettingsViewStore = ViewStore<SettingsViewState, SettingsViewAction.UI>

struct SettingsViewState {
  var stored: SettingsState
  var supportsAlternateIcons: Bool
  var icon: Icon
  var alert: Identified<AlertParams>?
}

// new fields should be added carefully
// not to break decoding from existing stored data
struct SettingsState: Codable, Equatable {
  var openClusterPreviews: Bool

  var sorting: ImageSorting
  var gradientScheme: GradientScheme

  init(
    openClusterPreviews: Bool,
    sorting: ImageSorting,
    gradientScheme: GradientScheme,
  ) {
    self.openClusterPreviews = openClusterPreviews
    self.sorting = sorting
    self.gradientScheme = gradientScheme
  }

  enum CodingKeys: String, CodingKey {
    case openClusterPreviews
    case sorting
    case gradientScheme
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.openClusterPreviews = try container.decode(Bool.self, forKey: .openClusterPreviews)

    // 29.3.26: optionality of these fields should be removed in 3 months, then fallback to default
    self.sorting = try container.decodeIfPresent(
      ImageSorting.self, forKey: .sorting,
    ) ?? SettingsState.default.sorting
    self.gradientScheme = try container.decodeIfPresent(
      GradientScheme.self, forKey: .gradientScheme,
    ) ?? SettingsState.default.gradientScheme
  }
}

enum SettingsViewAction {
  enum UI {
    enum Alert {
      case iconApplicationFailed(Error)
      case dismiss
    }

    case setOpenClusterPreviews(Bool)

    case iconSelected(Icon)
    case gradientSchemeSelected(GradientScheme)

    case alert(Alert)

    case contact
    case openRepo
    case viewInAppStore

    case openPastVu
    case pastVuRules
  }

  enum Internal {
    case iconApplied(Icon)
  }

  case ui(UI)
  case `internal`(Internal)
}

func makeSettings(
  storage: KeyValueStorage,
) -> ObservableProperty<SettingsState> {
  let property = storage.makeCodableField(
    key: "settings",
    default: SettingsState.default,
  )
  return property.unsafeMakeObservable()
}

func makeSettingsViewModel(
  settings: ObservableProperty<SettingsState>,
  urlOpener: @escaping UrlOpener,
) -> SettingsViewModel {
  Reducer<SettingsViewState, SettingsViewAction>(
    initial: SettingsViewState(
      stored: settings.value,
      supportsAlternateIcons: UIApplication.shared.supportsAlternateIcons,
      icon: Icon(
        alternateIconName: UIApplication.shared.alternateIconName,
      ),
      alert: nil,
    ),
    reduce: { state, action, enqueueEffect in
      switch action {
      case let .ui(ui):
        switch ui {
        case let .setOpenClusterPreviews(value):
          state.stored.openClusterPreviews = value
        case let .iconSelected(icon):
          enqueueEffect(.perform { anotherAction in
            do {
              try await UIApplication.shared.setAlternateIconName(icon.alternateIconName)
              await anotherAction(.internal(.iconApplied(icon)))
            } catch {
              await anotherAction(.ui(.alert(.iconApplicationFailed(error))))
            }
          })
        case let .gradientSchemeSelected(scheme):
          state.stored.gradientScheme = scheme
        case .contact:
          urlOpener(URL(string: "mailto:a.chizberg@proton.me"))
        case .openRepo:
          urlOpener(URL(string: "https://github.com/chizberg/Rewind"))
        case .viewInAppStore:
          urlOpener(URL(string: "https://apps.apple.com/app/rewind-history-on-a-map/id6755358800"))
        case .openPastVu:
          urlOpener(pastvuCom)
        case .pastVuRules:
          urlOpener(URL(string: "https://docs.pastvu.com/en/rules"))
        case let .alert(alert):
          switch alert {
          case let .iconApplicationFailed(error):
            state.alert = Identified(value: .error(
              title: "Unable to set icon",
              error: error,
            ))
          case .dismiss:
            state.alert = nil
          }
        }
      case let .internal(internalAction):
        switch internalAction {
        case let .iconApplied(icon):
          state.icon = icon
        }
      }
    },
  )
  .onStateUpdate { newState in
    settings.value = newState.stored
  }
}

let pastvuCom = URL(string: "https://pastvu.com")!

extension SettingsState {
  static let `default` = SettingsState(
    openClusterPreviews: false,
    sorting: .dateAscending,
    gradientScheme: .rewind,
  )
}
