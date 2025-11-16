//
//  SettingsModel.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 9. 11. 2025..
//

import Foundation

typealias SettingsModel = Reducer<SettingsState, SettingsAction>

struct SettingsState {}

enum SettingsAction {
  case contactSupport
  case openRepo
  case openPastVu
  case pastVuRules
}

func makeSettingsModel(
  urlOpener: @escaping UrlOpener
) -> SettingsModel {
  Reducer(
    initial: SettingsState(),
    reduce: { _, action, _ in
      switch action {
      case .contactSupport:
        urlOpener(URL(string: "mailto:a.chizberg@proton.me"))
      case .openRepo:
        urlOpener(URL(string: "https://github.com/chizberg/Rewind"))
      case .openPastVu:
        urlOpener(URL(string: "https://pastvu.com"))
      case .pastVuRules:
        urlOpener(URL(string: "https://docs.pastvu.com/en/rules"))
      }
    }
  )
}
