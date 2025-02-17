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

  var body: some View {
    ViewRepresentable {
      UIKitYearSelector(yearRange: $yearRange)
    }
    .frame(height: 50)
  }
}

#Preview {
  @Previewable @State
  var yearRange = 1826...2000

  YearSelector(
    yearRange: $yearRange
  ).onChange(of: yearRange) {
    print(yearRange)
  }
}
