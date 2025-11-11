//
//  ImageDateView.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 11. 11. 2025..
//

import SwiftUI

struct ImageDateView: View {
  static var cardRadius: CGFloat { radius }

  var date: ImageDate

  var body: some View {
    ColoredContainer(date: date) {
      Text(date.description)
        .bold()
    }
  }
}

struct DirectionView: View {
  var date: ImageDate
  var direction: Direction

  var body: some View {
    ColoredContainer(date: date) {
      HStack(spacing: 5) {
        Text(direction.rawValue.uppercased())
          .bold().monospaced()
        Image(systemName: "arrowtriangle.up.fill")
          .resizable()
          .frame(width: 8, height: 10)
          .rotationEffect(.radians(direction.angle ?? 0))
      }
    }
  }
}

private struct ColoredContainer<Content: View>: View {
  var date: ImageDate
  @ViewBuilder
  var content: () -> Content

  var body: some View {
    content()
      .foregroundStyle(Color.white)
      .padding(radius)
      .background {
        RoundedRectangle(cornerRadius: radius)
          .fill(Color(uiColor: UIColor.from(year: date.year)))
      }
  }
}

private let radius: CGFloat = 7

#if DEBUG
private let previewDates = [
  ImageDate(year: 1826, year2: 1826),
  ImageDate(year: 1826, year2: 1850),
  ImageDate(year: 1850, year2: 1883),
  ImageDate(year: 1883, year2: 1901),
  ImageDate(year: 1901, year2: 1901),
  ImageDate(year: 1901, year2: 1902),
  ImageDate(year: 1902, year2: 1935),
  ImageDate(year: 1935, year2: 1950),
  ImageDate(year: 1950, year2: 1975),
  ImageDate(year: 1975, year2: 2000),
]

#Preview("dates") {
  VStack {
    ForEach(previewDates, id: \.hashValue) {
      ImageDateView(date: $0)
    }
  }
}

#Preview("directions") {
  VStack {
    ForEach(Direction.allCases, id: \.self) { direction in
      DirectionView(date: previewDates[0], direction: direction)
    }
  }
}
#endif
