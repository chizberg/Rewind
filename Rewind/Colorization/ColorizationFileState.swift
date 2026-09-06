//
//  ColorizationFileState.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 6. 9. 2026.
//

import Foundation

enum ColorizationFileState: Equatable {
  case available
  case downloading(CGFloat)
  case installing // TODO: use installing while unzipping and compiling
  case downloaded

  var isDownloading: Bool {
    if case .downloading = self { true } else { false }
  }
}
