//
//  ThumbnailView.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 05.02.2025.
//

import SwiftUI
import VGSL

struct ThumbnailCardView: View {
  var card: ThumbnailCard
  var size: CGSize
  var radius: CGFloat = 25

  var body: some View {
    ZStack {
      MapControlBackground(radius: radius)

      content
    }.frame(size: size)
      .clipShape(RoundedRectangle(cornerRadius: radius))
      .contentShape(Rectangle())
      .overlay {
        RoundedRectangle(cornerRadius: radius)
          .strokeBorder(.white.opacity(0.2), lineWidth: 1)
      }
  }

  @ViewBuilder
  var content: some View {
    switch card {
    case .noImages: nothingHere
    case let .image(image): imageContent(image: image)
    case .viewAsList: viewAsList
    }
  }

  private func imageContent(image: Model.Image) -> some View {
    ZStack(alignment: .bottomLeading) {
      RewindAsyncImage(image.image, .medium) { loaded in
        Image(uiImage: loaded)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(size: size)
      } placeholder: {
        Color.clear.overlay {
          ProgressView()
        }
      }

      ImageDateView(date: image.date)
        .padding(radius - ImageDateView.cardRadius)
    }
  }

  private var nothingHere: some View {
    VStack {
      Text("👀")
        .font(.largeTitle)
      Text("Nothing here yet")
        .fontWeight(.semibold)
    }
  }

  private var viewAsList: some View {
    VStack(spacing: 12) {
      Image(systemName: "list.bullet")
        .font(.largeTitle)
      Text("View as List")
        .fontWeight(.semibold)
    }
  }
}

#if DEBUG
#Preview("single cat") {
  ZStack {
    Image(.cat).resizable().ignoresSafeArea()

    ThumbnailCardView(
      card: .image(modified(.mock) {
        $0.image = $0.image.delayed(delay: 1)
      }),
      size: CGSize(width: 200, height: 200)
    )
  }
}

#Preview("panorama touch test") {
  ThumbnailCardView(
    card: .image(modified(.mock) {
      $0.image = .panorama
    }),
    size: CGSize(width: 200, height: 200)
  )
  .onTapGesture {
    print("foo")
  }
}

#Preview("no images") {
  ZStack {
    Image(.cat).resizable().ignoresSafeArea()

    ThumbnailCardView(
      card: .noImages,
      size: CGSize(width: 200, height: 200)
    )
  }
}

#Preview("view as list") {
  ZStack {
    Image(.cat).resizable().ignoresSafeArea()
    ThumbnailCardView(
      card: .viewAsList,
      size: CGSize(width: 200, height: 200)
    )
  }
}
#endif
