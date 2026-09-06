//
//  ColorizationModel.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 23. 8. 2026.
//

import UIKit

protocol ColorizationModel: Sendable {
  func colorize(image: UIImage) async throws -> UIImage
}

enum ColorizationModelID: String, Codable, CaseIterable {
  case ddColorLarge = "ddcolor-large"
  case eccv16
}
