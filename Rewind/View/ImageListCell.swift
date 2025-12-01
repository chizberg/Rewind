//
//  ImageListCell.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 19.2.25..
//

import SwiftUI

struct ImageListCell: View {
  var value: Model.Image
  var body: some View {
    ZStack(alignment: .bottomLeading) {
      RewindAsyncImage(value.image, .medium) { uiImage in
        Rectangle()
          .overlay {
            Image(uiImage: uiImage)
              .resizable()
              .aspectRatio(contentMode: .fill)
          }
          .clipped()
      } placeholder: {
        Color(uiColor: .secondarySystemBackground)
          .overlay {
            ProgressView()
          }
      }
      .aspectRatio(4 / 3, contentMode: .fit)

      HStack {
        VStack(alignment: .leading, spacing: 5) {
          Text(value.title)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .foregroundColor(.white)
            .font(.title3)
            .bold()

          ImageDateView(date: value.date)
        }

        Spacer(minLength: 0)
      }
      .padding(radius)
      .background(bgGradient)
    }
    .clipShape(RoundedRectangle(cornerRadius: radius))
  }

  private var bgGradient: some View {
    Rectangle()
      .fill(
        .linearGradient(
          SwiftUI.Gradient(colors: [.clear, .black.opacity(0.5)]),
          startPoint: UnitPoint(x: 0, y: 0),
          endPoint: UnitPoint(x: 0, y: 1)
        )
      )
  }
}

private let radius: CGFloat = 20

#if DEBUG
#Preview {
  ImageListCell(value: .mock)
}
#endif
