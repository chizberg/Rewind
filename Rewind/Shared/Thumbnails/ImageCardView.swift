//
//  ImageCardView.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 18. 10. 2026.
//

import SwiftUI

struct ImageCardView: View {
  var image: Model.Image

  @State
  private var titleStyle: ThumbnailTitleStyle?

  var body: some View {
    MapControlBackground(radius: radius)
      .aspectRatio(3 / 4, contentMode: .fit)
      .overlay {
        imageView
      }
      .overlay(alignment: .topLeading) {
        let padding = radius - 10
        title
          .padding(padding)
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .background {
            VariableBlurView(gradient: .easedFade(), maxRadius: 20)
            LinearGradient(
              gradient: .easedFade(
                Color.black.opacity(
                  titleStyle?.dimming ?? 0
                )
              ),
              startPoint: .top,
              endPoint: .bottom
            )
          }
      }
      .overlay(alignment: .bottomLeading) {
        ImageDateView(date: image.date)
          .font(.footnote)
          .padding(radius - ImageDateView.cardRadius)
      }
      .clipShape(RoundedRectangle(cornerRadius: radius))
      .overlay {
        RoundedRectangle(cornerRadius: radius)
          .strokeBorder(.white.opacity(0.2), lineWidth: 1)
      }
  }

  private var imageView: some View {
    RewindAsyncImage(image.image, .medium) { loaded in
      Image(uiImage: loaded)
        .resizable()
        .scaledToFill()
        .task(id: loaded) {
          let style = await ThumbnailTitleStyle.measure(
            loaded,
            widthToHeight: 3 / 4,
            captionFraction: 0.3,
          )
          withAnimation {
            titleStyle = style
          }
        }
    } placeholder: {
      SwiftUI.Color.clear.overlay {
        DelayedProgressView()
      }
    }
  }

  private var title: some View {
    Text(image.title)
      .multilineTextAlignment(.leading)
      .lineLimit(3)
      .font(.system(.body, design: .serif).bold())
      .foregroundStyle(titleStyle?.titleColor ?? .primary)
  }
}

private let radius = 25.0
