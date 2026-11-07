//
//  EmptyListPlaceholder.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 6. 11. 2026.
//

import Foundation

struct EmptyListPlaceholder {
  var emoji: String
  var title: LocalizedStringResource
}

extension EmptyListPlaceholder {
  static let general: [EmptyListPlaceholder] = [
    EmptyListPlaceholder(emoji: "👀", title: "Nothing here yet"),
    EmptyListPlaceholder(emoji: "🔭", title: "Nothing in sight"),
    EmptyListPlaceholder(emoji: "🍃", title: "All quiet here"),
    EmptyListPlaceholder(emoji: "📭", title: "Empty for now"),
    EmptyListPlaceholder(emoji: "🧭", title: "Nothing found yet"),
    EmptyListPlaceholder(emoji: "🐾", title: "No traces yet"),
    EmptyListPlaceholder(emoji: "🪴", title: "Nothing to show yet"),
  ]

  static let map = general + [
    EmptyListPlaceholder(emoji: "🕰️", title: "Nothing from this time"),
  ]
}
