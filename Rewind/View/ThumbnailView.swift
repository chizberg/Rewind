//
//  ThumbnailView.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 05.02.2025.
//

import SwiftUI

struct ThumbnailView: View {
  var image: Model.Image
  var size: CGSize

  var body: some View {
    ZStack(alignment: .bottomLeading) {
      RewindAsyncImage(image.image, .medium) { loaded in
        Image(uiImage: loaded)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(size: size)
      } placeholder: {
        BlurView(style: .regular, radius: radius)
      }

      badge
        .padding(radius - badgeRadius)
    }
    .frame(size: size)
    .clipShape(RoundedRectangle(cornerRadius: radius))
    .overlay {
      RoundedRectangle(cornerRadius: radius)
        .strokeBorder(.white.opacity(0.2), lineWidth: 1)
    }
    .transition(.scale)
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
  ThumbnailView(image: .mock, size: CGSize(width: 200, height: 200))
}
#endif
