import func SwiftUI.__designTimeFloat
import func SwiftUI.__designTimeString
import func SwiftUI.__designTimeInteger
import func SwiftUI.__designTimeBoolean

#sourceLocation(file: "/Users/chizberg/Documents/Личные проекты/Rewind/Rewind/View/ThumbnailView.swift", line: 1)
//
//  ThumbnailView.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 05.02.2025.
//

import SwiftUI

struct ThumbnailView: View {
  var image: Model.Image

  var body: some View {
    ZStack(alignment: .bottomLeading) {
      AsyncImage {
        try await image.image.load(quality: .medium)
      } content: { loaded in
        Image(uiImage: loaded)
          .resizable()
          .aspectRatio(contentMode: .fill)
      }

      badge
        .padding(radius - badgeRadius)
    }.clipShape(RoundedRectangle(cornerRadius: radius))
  }

  private var badge: some View {
    Text(image.date.description)
      .foregroundStyle(Color.white)
      .bold()
      .padding(badgeRadius)
      .background {
        RoundedRectangle(cornerRadius: badgeRadius)
          .fill(Color(uiColor: UIColor.from(year: image.date.year)))
      }
  }
}

private let badgeRadius: CGFloat = 7
private let radius: CGFloat = 15

#if DEBUG
#Preview {
  ThumbnailView(image: .mock)
}
#endif
