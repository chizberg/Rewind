//
//  ImageShareItem.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 7. 12. 2025..
//

import LinkPresentation
import UIKit

final class ImageShareItem: NSObject, UIActivityItemSource {
  private var image: UIImage
  private var text: String

  init(image: UIImage, text: String) {
    self.image = image
    self.text = text
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
    metadata.imageProvider = NSItemProvider(object: image)
    return metadata
  }
}
