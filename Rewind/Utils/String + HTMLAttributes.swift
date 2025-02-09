//
//  String + HTMLAttributes.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 09.02.2025.
//

import Foundation

extension String {
  func makeAttrString() -> AttributedString {
    let nsAttrString = NSAttributedString(html: self) ?? NSAttributedString(string: self)
    return AttributedString(nsAttrString)
  }
}

extension NSAttributedString {
  fileprivate convenience init?(html: String) {
    guard let data = html.data(using: .utf8) else { return nil }

    guard let mutableAttrStr = try? NSMutableAttributedString(
      data: data,
      options: [
        .documentType: NSAttributedString.DocumentType.html,
        .characterEncoding: String.Encoding.utf8.rawValue
      ],
      documentAttributes: nil
    ) else { return nil }

    let fullRange = NSRange(
      location: 0,
      length: mutableAttrStr.length
    )

    mutableAttrStr.removeAttribute(
      .font,
      range: fullRange
    )
    mutableAttrStr.removeAttribute(
      .foregroundColor,
      range: fullRange
    )
    self.init(attributedString: mutableAttrStr)
  }
}
