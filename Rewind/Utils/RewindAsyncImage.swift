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
    @ViewBuilder content: @escaping (UIImage) -> Content,
    @ViewBuilder placeholder: @escaping () -> Placeholder
  ) {
    getter = { try await image(quality) }
    self.content = content
    self.placeholder = placeholder()
  }

  @State
  private var image: UIImage?

  var body: some View {
    Group {
      if let image {
        content(image)
      } else {
        placeholder
      }
    }
    .task {
      do {
        // Try to load the image asynchronously.
        let fetchedImage = try await getter()
        await MainActor.run {
          self.image = fetchedImage
        }
      } catch {
        // TODO: error handling
      }
    }
  }
}
