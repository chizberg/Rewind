//
//  withUIIdiom.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 5. 12. 2025.
//

import UIKit

func withUIIdiom<T>(
  phone: T,
  pad: T
) -> T {
  switch UIDevice.current.userInterfaceIdiom {
  case .phone: phone
  case .pad: pad
  default: phone
  }
}
