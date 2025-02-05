//
//  AsyncImage.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 05.02.2025.
//

import SwiftUI

struct AsyncImage<Content: View>: View {
  let getter: () async throws -> UIImage
  @ViewBuilder
  var content: (UIImage) -> Content

  @State
  private var image: UIImage?

  var body: some View {
    Group {
      if let image = image {
        content(image)
      } else {
        ProgressView()
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

