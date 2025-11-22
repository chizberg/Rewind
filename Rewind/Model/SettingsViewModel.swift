//
//  SettingsViewModel.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 9. 11. 2025..
//

import Foundation
import VGSL

typealias SettingsViewModel = Reducer<SettingsState, SettingsViewAction.UI>

// new fields should be added carefully
// not to break decoding from existing stored data
struct SettingsState: Codable, Equatable {
  var showYearColorInClusters: Bool
  var openClusterPreviews: Bool
}

enum SettingsViewAction {
  enum UI {
    case setShowYearColorInClusters(Bool)
    case setOpenClusterPreviews(Bool)

    case contactSupport
    case openRepo
    case openPastVu
    case pastVuRules
  }

  enum Internal {
    case newSettingsState(SettingsState)
  }

  case ui(UI)
  case `internal`(Internal)
}

func makeSettings(
  storage: KeyValueStorage
) -> ObservableProperty<SettingsState> {
  let property = storage.makeCodableField(
    key: "settings",
    default: SettingsState(
      showYearColorInClusters: false,
      openClusterPreviews: false
    )
  )
  return property.unsafeMakeObservable()
}

func makeSettingsViewModel(
  settings: ObservableProperty<SettingsState>,
  urlOpener: @escaping UrlOpener
) -> SettingsViewModel {
  Reducer<SettingsState, SettingsViewAction>(
    initial: settings.value,
    reduce: { state, action, _ in
      switch action {
      case let .ui(ui):
        switch ui {
        case let .setShowYearColorInClusters(value):
          state.showYearColorInClusters = value
        case let .setOpenClusterPreviews(value):
          state.openClusterPreviews = value
        case .contactSupport:
          urlOpener(URL(string: "mailto:a.chizberg@proton.me"))
        case .openRepo:
          urlOpener(URL(string: "https://github.com/chizberg/Rewind"))
        case .openPastVu:
          urlOpener(URL(string: "https://pastvu.com"))
        case .pastVuRules:
          urlOpener(URL(string: "https://docs.pastvu.com/en/rules"))
        }
      case let .internal(internalAction):
        switch internalAction {
        case let .newSettingsState(newState):
          state = newState
        }
      }
    }
  )
  .onStateUpdate { newState in
    settings.value = newState
  }
  .unsafeBimap(state: { $0 }, action: { .ui($0) })
}
