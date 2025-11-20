//
//  RewindAsyncImage.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 05.02.2025.
//

import SwiftUI

struct RewindAsyncImage<Content: View, Placeholder: View, ErrorView: View>: View {
  let getter: () async throws -> UIImage
  @ViewBuilder
  var content: (UIImage) -> Content
  var placeholder: Placeholder
  @ViewBuilder
  var errorView: (Error) -> ErrorView

  init(
    _ image: LoadableUIImage,
    _ quality: ImageQuality,
    cachedOnly: Bool = false,
    @ViewBuilder content: @escaping (UIImage) -> Content,
    @ViewBuilder placeholder: @escaping () -> Placeholder,
    @ViewBuilder errorView: @escaping (Error) -> ErrorView
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
    self.errorView = errorView
  }

  @State
  private var image: UIImage?
  @State
  private var error: Error?

  var body: some View {
    Group {
      if let image {
        content(image)
      } else if let error {
        errorView(error)
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
        await MainActor.run {
          self.error = error
        }
      }
    }
  }
}

extension RewindAsyncImage where ErrorView == Image {
  init(
    _ image: LoadableUIImage,
    _ quality: ImageQuality,
    cachedOnly: Bool = false,
    @ViewBuilder content: @escaping (UIImage) -> Content,
    @ViewBuilder placeholder: @escaping () -> Placeholder
  ) {
    self.init(
      image,
      quality,
      cachedOnly: cachedOnly,
      content: content,
      placeholder: placeholder,
      errorView: { _ in
        Image(uiImage: .error)
      }
    )
  }
}
