//
//  MonochromeDetectionTests.swift
//  RewindTests
//
//  Created by Aleksei Sherstnev on 12. 9. 2026.
//

@testable import Rewind
import Testing
import UIKit

struct MonochromeDetectionTests {
  @Test func sepiaGradientIsMonochrome() async throws {
    let image = try makeRGBImage(width: 16, height: 16, pixels: (0..<256).map { index in
      let t = Float(index % 16 + index / 16) / 30
      return [UInt8(60 + t * 180), UInt8(40 + t * 160), UInt8(20 + t * 120)]
    })

    #expect(try await isMonochrome(image: UIImage(cgImage: image)))
  }

  @Test func colorCloudIsNotMonochrome() async throws {
    let image = try makeRGBImage(width: 16, height: 16, pixels: (0..<256).map { index in
      let x = index % 16
      let y = index / 16
      return [UInt8(x * 17), UInt8(y * 17), UInt8((x * 7 + y * 3) % 16 * 17)]
    })

    #expect(try await !isMonochrome(image: UIImage(cgImage: image)))
  }
}
