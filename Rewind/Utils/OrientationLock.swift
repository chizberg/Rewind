//
//  OrientationLock.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 5. 12. 2025..
//

import UIKit

enum OrientationLock {
  case portrait
  // if you need to lock into more orientations, add them here
}

extension OrientationLock {
  var mask: UIInterfaceOrientationMask {
    switch self {
    case .portrait: .portrait
    }
  }
}
