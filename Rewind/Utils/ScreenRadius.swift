//
//  ScreenRadius.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 2. 12. 2025..
//

import Foundation

extension DeviceModel {
  func screenRadius() -> CGFloat {
    switch self {
    case let .phone(phone): phone.radius
    case let .pad(pad): pad.radius
    case .unknown: 0
    }
  }
}

extension PhoneModel {
  fileprivate var radius: Double {
    switch self {
    case .iPhone, .iPhone3G, .iPhone3GS, .iPhone4, .iPhone4S, .iPhone5, .iPhone5c, .iPhone5s,
         .iPhone6Plus, .iPhone6, .iPhone6s, .iPhone6sPlus, .iPhoneSE1stGen,
         .iPhone7, .iPhone7Plus, .iPhone8, .iPhone8Plus, .iPhoneSE2ndGen, .iPhoneSE3rdGen:
      return 0
    case .iPhoneX, .iPhoneXs, .iPhoneXsMax, .iPhone11Pro, .iPhone11ProMax:
      return 39
    case .iPhoneXr, .iPhone11:
      return 41.5
    case .iPhone12Mini, .iPhone13Mini:
      return 44
    case .iPhone12, .iPhone12Pro, .iPhone13, .iPhone13Pro, .iPhone14, .iPhone16e:
      return 47.33
    case .iPhone12ProMax, .iPhone13ProMax, .iPhone14Plus:
      return 53.33
    case .iPhone14Pro, .iPhone14ProMax, .iPhone15, .iPhone15Plus,
         .iPhone15Pro, .iPhone15ProMax, .iPhone16, .iPhone16Plus:
      return 55
    case .iPhone16Pro, .iPhone16ProMax, .iPhone17, .iPhone17Pro, .iPhone17ProMax,
         .iPhoneAir:
      return 62
    case .unknown:
      assertionFailure("unknown phone model")
      return 62 // assume the newest devices will keep the radius
    }
  }
}

extension PadModel {
  fileprivate var radius: Double {
    switch self {
    case .iPad, .iPad2, .iPad3, .iPad4, .iPadMini, .iPadAir, .iPadMini2,
         .iPadMini3, .iPadMini4, .iPadAir2, .iPadPro12_9Gen1, .iPadPro9_7,
         .iPad5, .iPadPro12_9Gen2, .iPadPro10_5, .iPad6, .iPad7, .iPadMini5,
         .iPadAir3, .iPad8, .iPad9:
      return 0
    case .iPadPro11A12X, .iPadPro13A12X, .iPadPro11A12Z, .iPadPro13A12Z,
         .iPadAir4, .iPadPro11M1, .iPadPro13M1, .iPadAir5, .iPadPro11M2, .iPadPro13M2,
         .iPadAir11M2, .iPadAir13M2, .iPadAir11M3, .iPadAir13M3:
      return 18
    case .iPad10, .iPadA16:
      return 25
    case .iPadMini6, .iPadMini7:
      return 21.5
    case .iPadPro11M4, .iPadPro13M4, .iPadPro11M5, .iPadPro13M5:
      return 30
    case .unknown:
      assertionFailure("unknown pad model")
      return 25 // assume the newest devices will keep the radius
    }
  }
}
