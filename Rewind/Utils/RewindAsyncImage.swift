//
//  RewindAsyncImage.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 05.02.2025.
//

import SwiftUI

struct RewindAsyncImage<Content: View, Placeholder: View>: View {
  let getter: () async throws -> UIImage
  @ViewBuilder
  var content: (UIImage) -> Content
  var placeholder: Placeholder

  init(
    _ image: LoadableUIImage,
    _ quality: ImageQuality,
    cachedOnly: Bool = false,
    @ViewBuilder content: @escaping (UIImage) -> Content,
    @ViewBuilder placeholder: @escaping () -> Placeholder
  ) {
    getter = {
      try await image.load(
        ImageLoadingParams(
          quality: quality,
          cachedOnly: cachedOnly
        )
      )
    }
    self.content = content
    self.placeholder = placeholder()
  }

  @State
  private var image: UIImage?
  @State
  private var error: Error?

  var body: some View {
    Group {
      if let image {
        content(image)
      } else if error != nil {
        content(UIImage.error)
      } else {
        placeholder
      }
    }
    .task(priority: .background) {
      do {
        let fetchedImage = try await getter()
        await MainActor.run {
          self.image = fetchedImage
        }
      } catch {
        await MainActor.run {
          self.error = error
        }
      }
    }
  }
}
