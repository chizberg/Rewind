//
//  ThumbnailView.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 05.02.2025.
//

import SwiftUI
import VGSL

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
        if #available(iOS 26, *) {
          GlassView(radius: radius)
        } else {
          BlurView(style: .regular, radius: radius)
        }
      }

      ImageDateView(date: image.date)
        .padding(radius - ImageDateView.cardRadius)
    }
    .frame(size: size)
    .clipShape(RoundedRectangle(cornerRadius: radius))
    .contentShape(Rectangle())
    .overlay {
      RoundedRectangle(cornerRadius: radius)
        .strokeBorder(.white.opacity(0.2), lineWidth: 1)
    }
  }
}

private let radius: CGFloat = 20

#if DEBUG
#Preview("single cat") {
  ThumbnailView(image: .mock, size: CGSize(width: 200, height: 200))
}

#Preview("panorama touch test") {
  ThumbnailView(
    image: modified(.mock) {
      $0.image = .panorama
    },
    size: CGSize(width: 200, height: 200)
  )
  .onTapGesture {
    print("foo")
  }
}
#endif
