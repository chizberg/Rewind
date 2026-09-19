//
//  SettingsViewModel.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 9. 11. 2025.
//

import UIKit
import VGSL

typealias SettingsViewStore = ViewStore<SettingsViewState, SettingsViewAction.UI>

struct SettingsViewState {
  struct UI {
    var supportsAlternateIcons: Bool
    var icon: Icon
    var alert: Identified<AlertParams>?
    var colorizationPicker: Identified<ColorizationPickerScreenStore>?
  }

  var stored: SettingsState
  var ui: UI
}

// new fields should be added carefully
// not to break decoding from existing stored data
struct SettingsState: Codable, Equatable {
  var openClusterPreviews: Bool

  var sorting: ImageSorting
  var gradientScheme: GradientScheme
  var colorizationModel: ColorizationModelID?
}

enum SettingsViewAction {
  enum UI {
    enum Alert {
      case iconApplicationFailed(Error)
      case dismiss
    }

    enum ColorizationPicker {
      case present
      case dismiss
    }

    case setOpenClusterPreviews(Bool)

    case iconSelected(Icon)
    case gradientSchemeSelected(GradientScheme)

    case alert(Alert)
    case colorizationPicker(ColorizationPicker)

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

func makeSettingsViewStore(
  settings: ObservableProperty<SettingsState>,
  urlOpener: @escaping UrlOpener,
  makeColorizationPicker: @escaping () -> ColorizationPickerScreenStore,
) -> SettingsViewStore {
  let model = Reducer<SettingsViewState.UI, SettingsViewAction>(
    initial: SettingsViewState.UI(
      supportsAlternateIcons: UIApplication.shared.supportsAlternateIcons,
      icon: Icon(
        alternateIconName: UIApplication.shared.alternateIconName,
      ),
      alert: nil,
      colorizationPicker: nil,
    ),
    reduce: { state, action, effect, asyncEffect in
      switch action {
      case let .ui(ui):
        switch ui {
        case let .setOpenClusterPreviews(value):
          effect { settings.value.openClusterPreviews = value }
        case let .iconSelected(icon):
          asyncEffect(.perform { anotherAction in
            do {
              try await UIApplication.shared.setAlternateIconName(icon.alternateIconName)
              await anotherAction(.internal(.iconApplied(icon)))
            } catch {
              await anotherAction(.ui(.alert(.iconApplicationFailed(error))))
            }
          })
        case let .gradientSchemeSelected(scheme):
          effect { settings.value.gradientScheme = scheme }
          UISelectionFeedbackGenerator().selectionChanged()
        case .contact:
          effect { urlOpener(URL(string: "mailto:a.chizberg@proton.me")) }
        case .openRepo:
          effect { urlOpener(URL(string: "https://github.com/chizberg/Rewind")) }
        case .viewInAppStore:
          effect {
            urlOpener(
              URL(string: "https://apps.apple.com/app/rewind-history-on-a-map/id6755358800")
            )
          }
        case .openPastVu:
          effect { urlOpener(pastvuCom) }
        case .pastVuRules:
          effect { urlOpener(URL(string: "https://docs.pastvu.com/en/rules")) }
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
        case let .colorizationPicker(picker):
          switch picker {
          case .present:
            state.colorizationPicker = Identified(value: makeColorizationPicker())
          case .dismiss:
            state.colorizationPicker = nil
          }
        }
      case let .internal(internalAction):
        switch internalAction {
        case let .iconApplied(icon):
          state.icon = icon
          UISelectionFeedbackGenerator().selectionChanged()
        }
      }
    },
  )
  return ViewStore(
    state: ObservableVariable.combineLatest(
      settings.asObservableVariable(),
      model.$state
    ).map { stored, ui in
      SettingsViewState(stored: stored, ui: ui)
    }.asObservedVariable(),
    actionPerformer: { model(.ui($0)) },
  )
}

let pastvuCom = URL(string: "https://pastvu.com")!

extension SettingsState {
  static let `default` = SettingsState(
    openClusterPreviews: false,
    sorting: .dateAscending,
    gradientScheme: .rewind,
    colorizationModel: nil,
  )
}
