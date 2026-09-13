//
//  ColorizationModel.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 23. 8. 2026.
//

import UIKit

protocol ColorizationModel: Sendable {
  func colorize(image: UIImage) async throws -> UIImage

  // CLAHE's clip limit for the gray frame this model reads, the value the reference measured.
  // https://docs.opencv.org/4.x/d6/db6/classcv_1_1CLAHE.html#abc15ca6784ab92c0d93e8b013fac191f
  var claheClip: Double { get }

  // ab in OpenCV's Lab units at the gray frame's size; how the frame gets into the graph and back
  // is the model's own. A model actor's synchronous method satisfies it, called through await.
  // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0306-actors.md#protocol-conformances
  func predict(gray: Plane<UInt8>) async throws -> ABPlanes
}

extension ColorizationModel {
  // The shared pipeline around predict(gray:); still a requirement, so a model can replace it.
  // https://docs.swift.org/swift-book/documentation/the-swift-programming-language/protocols/#Protocol-Extensions
  func colorize(image: UIImage) async throws -> UIImage {
    try await ColorizationPipeline.run(self, image: image)
  }
}

enum ColorizationModelID: String, Codable, CaseIterable {
  case ddColorLarge = "ddcolor-large"
  case eccv16
}
