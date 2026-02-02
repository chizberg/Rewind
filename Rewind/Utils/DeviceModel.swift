//
//  DeviceModel.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 2. 12. 2025.
//

import Foundation

enum DeviceModel {
  case phone(PhoneModel)
  case pad(PadModel)
  case unknown

  static func getCurrent() -> DeviceModel {
    let id = obtainDeviceID()
    if id.starts(with: "iPhone") {
      return .phone(PhoneModel(deviceID: id))
    } else if id.starts(with: "iPad") {
      return .pad(PadModel(deviceID: id))
    } else {
      assertionFailure("unknown device id: \(id)")
      return .unknown
    }
  }
}

// copied from
// https://github.com/markbattistella/BezelKit/blob/main/Sources/BezelKit/UIDevice%2BExt.swift
private func obtainDeviceID() -> String {
  #if targetEnvironment(simulator)
  return ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] ?? ""
  #else
  var systemInfo = utsname()
  uname(&systemInfo)
  let machineMirror = Mirror(reflecting: systemInfo.machine)
  return machineMirror.children.compactMap { $0.value as? Int8 }
    .filter { $0 != 0 }
    .map { String(UnicodeScalar(UInt8($0))) }
    .joined()
  #endif
}

enum PhoneModel {
  case iPhone
  case iPhone3G
  case iPhone3GS
  case iPhone4
  case iPhone4S
  case iPhone5
  case iPhone5c
  case iPhone5s
  case iPhone6Plus
  case iPhone6
  case iPhone6s
  case iPhone6sPlus
  case iPhoneSE1stGen
  case iPhone7
  case iPhone7Plus
  case iPhone8
  case iPhone8Plus
  case iPhoneX
  case iPhoneXs
  case iPhoneXsMax
  case iPhoneXr
  case iPhone11
  case iPhone11Pro
  case iPhone11ProMax
  case iPhoneSE2ndGen
  case iPhone12Mini
  case iPhone12
  case iPhone12Pro
  case iPhone12ProMax
  case iPhone13Pro
  case iPhone13ProMax
  case iPhone13Mini
  case iPhone13
  case iPhoneSE3rdGen
  case iPhone14
  case iPhone14Plus
  case iPhone14Pro
  case iPhone14ProMax
  case iPhone15
  case iPhone15Plus
  case iPhone15Pro
  case iPhone15ProMax
  case iPhone16Pro
  case iPhone16ProMax
  case iPhone16
  case iPhone16Plus
  case iPhone16e
  case iPhone17Pro
  case iPhone17ProMax
  case iPhone17
  case iPhoneAir
  case unknown

  init(deviceID: String) {
    switch deviceID {
    case "iPhone1,1": self = .iPhone
    case "iPhone1,2": self = .iPhone3G
    case "iPhone2,1": self = .iPhone3GS
    case "iPhone3,1", "iPhone3,2", "iPhone3,3": self = .iPhone4
    case "iPhone4,1": self = .iPhone4S
    case "iPhone5,1", "iPhone5,2": self = .iPhone5
    case "iPhone5,3", "iPhone5,4": self = .iPhone5c
    case "iPhone6,1", "iPhone6,2": self = .iPhone5s
    case "iPhone7,1": self = .iPhone6Plus
    case "iPhone7,2": self = .iPhone6
    case "iPhone8,1": self = .iPhone6s
    case "iPhone8,2": self = .iPhone6sPlus
    case "iPhone8,4": self = .iPhoneSE1stGen
    case "iPhone9,1", "iPhone9,3": self = .iPhone7
    case "iPhone9,2", "iPhone9,4": self = .iPhone7Plus
    case "iPhone10,1", "iPhone10,4": self = .iPhone8
    case "iPhone10,2", "iPhone10,5": self = .iPhone8Plus
    case "iPhone10,3", "iPhone10,6": self = .iPhoneX
    case "iPhone11,2": self = .iPhoneXs
    case "iPhone11,4", "iPhone11,6": self = .iPhoneXsMax
    case "iPhone11,8": self = .iPhoneXr
    case "iPhone12,1": self = .iPhone11
    case "iPhone12,3": self = .iPhone11Pro
    case "iPhone12,5": self = .iPhone11ProMax
    case "iPhone12,8": self = .iPhoneSE2ndGen
    case "iPhone13,1": self = .iPhone12Mini
    case "iPhone13,2": self = .iPhone12
    case "iPhone13,3": self = .iPhone12Pro
    case "iPhone13,4": self = .iPhone12ProMax
    case "iPhone14,2": self = .iPhone13Pro
    case "iPhone14,3": self = .iPhone13ProMax
    case "iPhone14,4": self = .iPhone13Mini
    case "iPhone14,5": self = .iPhone13
    case "iPhone14,6": self = .iPhoneSE3rdGen
    case "iPhone14,7": self = .iPhone14
    case "iPhone14,8": self = .iPhone14Plus
    case "iPhone15,2": self = .iPhone14Pro
    case "iPhone15,3": self = .iPhone14ProMax
    case "iPhone15,4": self = .iPhone15
    case "iPhone15,5": self = .iPhone15Plus
    case "iPhone16,1": self = .iPhone15Pro
    case "iPhone16,2": self = .iPhone15ProMax
    case "iPhone17,1": self = .iPhone16Pro
    case "iPhone17,2": self = .iPhone16ProMax
    case "iPhone17,3": self = .iPhone16
    case "iPhone17,4": self = .iPhone16Plus
    case "iPhone17,5": self = .iPhone16e
    case "iPhone18,1": self = .iPhone17Pro
    case "iPhone18,2": self = .iPhone17ProMax
    case "iPhone18,3": self = .iPhone17
    case "iPhone18,4": self = .iPhoneAir
    default: self = .unknown
    }
  }
}

enum PadModel {
  case iPad
  case iPad2
  case iPad3
  case iPad4
  case iPadMini
  case iPadAir
  case iPadMini2
  case iPadMini3
  case iPadMini4
  case iPadAir2
  case iPadPro12_9Gen1
  case iPadPro9_7
  case iPad5
  case iPadPro12_9Gen2
  case iPadPro10_5
  case iPad6
  case iPadPro11A12X
  case iPadPro13A12X
  case iPad7
  case iPadPro11A12Z
  case iPadPro13A12Z
  case iPadMini5
  case iPadAir3
  case iPad8
  case iPad9
  case iPadMini6
  case iPadAir4
  case iPadPro11M1
  case iPadPro13M1
  case iPadAir5
  case iPadPro11M2
  case iPadPro13M2
  case iPad10
  case iPadPro11M4
  case iPadPro13M4
  case iPadAir11M2
  case iPadAir13M2
  case iPadA16
  case iPadMini7
  case iPadPro11M5
  case iPadPro13M5
  case iPadAir11M3
  case iPadAir13M3
  case unknown

  init(deviceID: String) {
    switch deviceID {
    case "iPad1,1", "iPad1,2": self = .iPad
    case "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4": self = .iPad2
    case "iPad3,1", "iPad3,2", "iPad3,3": self = .iPad3
    case "iPad3,4", "iPad3,5", "iPad3,6": self = .iPad4
    case "iPad2,5", "iPad2,6", "iPad2,7": self = .iPadMini
    case "iPad4,1", "iPad4,2", "iPad4,3": self = .iPadAir
    case "iPad4,4", "iPad4,5", "iPad4,6": self = .iPadMini2
    case "iPad4,7", "iPad4,8", "iPad4,9": self = .iPadMini3
    case "iPad5,1", "iPad5,2": self = .iPadMini4
    case "iPad5,3", "iPad5,4": self = .iPadAir2
    case "iPad6,7", "iPad6,8": self = .iPadPro12_9Gen1
    case "iPad6,3", "iPad6,4": self = .iPadPro9_7
    case "iPad6,11", "iPad6,12": self = .iPad5
    case "iPad7,1", "iPad7,2": self = .iPadPro12_9Gen2
    case "iPad7,3", "iPad7,4": self = .iPadPro10_5
    case "iPad7,5", "iPad7,6": self = .iPad6
    case "iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4": self = .iPadPro11A12X
    case "iPad8,5", "iPad8,6", "iPad8,7", "iPad8,8": self = .iPadPro13A12X
    case "iPad7,11", "iPad7,12": self = .iPad7
    case "iPad8,9", "iPad8,10": self = .iPadPro11A12Z
    case "iPad8,11", "iPad8,12": self = .iPadPro13A12Z
    case "iPad11,1", "iPad11,2": self = .iPadMini5
    case "iPad11,3", "iPad11,4": self = .iPadAir3
    case "iPad11,6", "iPad11,7": self = .iPad8
    case "iPad12,1", "iPad12,2": self = .iPad9
    case "iPad14,1", "iPad14,2": self = .iPadMini6
    case "iPad13,1", "iPad13,2": self = .iPadAir4
    case "iPad13,4", "iPad13,5", "iPad13,6", "iPad13,7": self = .iPadPro11M1
    case "iPad13,8", "iPad13,9", "iPad13,10", "iPad13,11": self = .iPadPro13M1
    case "iPad13,16", "iPad13,17": self = .iPadAir5
    case "iPad14,3", "iPad14,4": self = .iPadPro11M2
    case "iPad14,5", "iPad14,6": self = .iPadPro13M2
    case "iPad13,18", "iPad13,19": self = .iPad10
    case "iPad16,3", "iPad16,4": self = .iPadPro11M4
    case "iPad16,5", "iPad16,6": self = .iPadPro13M4
    case "iPad14,8", "iPad14,9": self = .iPadAir11M2
    case "iPad14,10", "iPad14,11": self = .iPadAir13M2
    case "iPad15,7", "iPad15,8": self = .iPadA16
    case "iPad16,1", "iPad16,2": self = .iPadMini7
    case "iPad17,1", "iPad17,2": self = .iPadPro11M5
    case "iPad17,3", "iPad17,4": self = .iPadPro13M5
    case "iPad15,3", "iPad15,4": self = .iPadAir11M3
    case "iPad15,5", "iPad15,6": self = .iPadAir13M3
    default: self = .unknown
    }
  }
}
