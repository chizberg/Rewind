//
//  ImageShareItem.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 7. 12. 2025.
//

import LinkPresentation
import UIKit

final class ImageShareItem: NSObject, UIActivityItemSource {
  private var image: UIImage
  private var text: String
  private var url: URL?

  init(image: UIImage, text: String, url: URL?) {
    self.image = image
    self.text = text
    self.url = url
  }

  func activityViewControllerPlaceholderItem(
    _: UIActivityViewController
  ) -> Any {
    image
  }

  func activityViewController(
    _: UIActivityViewController,
    itemForActivityType _: UIActivity.ActivityType?
  ) -> Any? {
    image
  }

  func activityViewControllerLinkMetadata(
    _: UIActivityViewController
  ) -> LPLinkMetadata? {
    let metadata = LPLinkMetadata()
    metadata.title = text
    metadata.originalURL = url
    metadata.url = url
    metadata.imageProvider = NSItemProvider(object: image)
    return metadata
  }
}

func makeShareVC(
  image: UIImage,
  title: String,
  description: String?,
  url: URL?
) -> UIActivityViewController {
  let item = ImageShareItem(image: image, text: title, url: url)
  let text = Array.build {
    title
    description
    url?.absoluteString
  }.joined(separator: "\n")
  return UIActivityViewController(
    activityItems: [item, text],
    applicationActivities: nil
  )
}
