//
//  YearSelector.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 15.2.25..
//

import SwiftUI

struct YearSelector: View {
  @Binding
  var yearRange: ClosedRange<Int>
  @Environment(\.maxRange)
  var maxRange: ClosedRange<Int>
  @Environment(\.gradientScheme)
  private var gradient

  var body: some View {
    ViewRepresentable {
      YearSelectorImpl(
        yearRange: yearRange,
        maxRange: maxRange,
        gradient: gradient,
        setYearRange: { yearRange = $0 },
      )
    } updater: {
      $0.setYearRange = { yearRange = $0 }
      $0.updateMaxRange(maxRange, yearRange: yearRange)
      $0.updateGradient(gradient)
    }
    .frame(height: 50)
  }
}

#Preview {
  @Previewable @State
  var yearRange = ImageRequestFilters.ImageKind.photo.maxRange

  YearSelector(
    yearRange: $yearRange,
  ).onChange(of: yearRange) {
    print(yearRange)
  }
}
