//
//  Icon.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 18. 1. 2026..
//

import SwiftUI

enum Icon: Hashable, CaseIterable {
  enum CustomIconName: String {
    case rewindMap = "RewindMap"
    case photoPlenkaSimple = "PhotoPlenkaSimple"
    case photoPlenka = "PhotoPlenka"
    case cameraRoll = "CameraRoll"
  }

  case rewindSimple
  case rewindMap
  case photoPlenkaSimple
  case photoPlenka
  case cameraRoll
}

extension Icon {
  init(alternateIconName: String?) {
    if let value = alternateIconName,
       let name = CustomIconName(rawValue: value) {
      self = name.icon
    } else {
      self = .rewindSimple
    }
  }

  var preview: UIImage {
    switch self {
    case .rewindSimple: .rewindSimple
    case .rewindMap: .rewindMap
    case .cameraRoll: .cameraRoll
    case .photoPlenkaSimple: .photoPlenkaSimple
    case .photoPlenka: .photoPlenka
    }
  }

  var alternateIconName: String? {
    let name: CustomIconName? = switch self {
    case .rewindSimple: nil
    case .rewindMap: .rewindMap
    case .cameraRoll: .cameraRoll
    case .photoPlenkaSimple: .photoPlenkaSimple
    case .photoPlenka: .photoPlenka
    }
    return name?.rawValue
  }

  var displayName: LocalizedStringKey {
    switch self {
    case .rewindSimple: "Default"
    case .rewindMap: "Map"
    case .cameraRoll: "Camera Roll"
    case .photoPlenkaSimple: "Pins"
    case .photoPlenka: "Pins & map"
    }
  }
}

extension Icon.CustomIconName {
  fileprivate var icon: Icon {
    switch self {
    case .rewindMap: .rewindMap
    case .cameraRoll: .cameraRoll
    case .photoPlenkaSimple: .photoPlenkaSimple
    case .photoPlenka: .photoPlenka
    }
  }
}
