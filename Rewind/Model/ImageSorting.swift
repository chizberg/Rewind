//
//  ImageSorting.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 10. 1. 2026.
//

import Foundation

enum ImageSorting: CaseIterable, Codable {
  case dateAscending
  case dateDescending
  case shuffle
}

extension [Model.Image] {
  func sorted(by sorting: ImageSorting) -> [Model.Image] {
    switch sorting {
    case .dateAscending: sorted { $0.date < $1.date }
    case .dateDescending: sorted { $0.date > $1.date }
    case .shuffle: shuffled()
    }
  }
}
