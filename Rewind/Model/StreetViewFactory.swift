//
//  StreetViewFactory.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 7. 1. 2026..
//

import UIKit
import WebKit

func makeStreetView(
  image: Model.Image
) throws -> WKWebView {
  guard let url = makeStreetViewURL(image: image) else {
    throw HandlingError("Unable to generate a Street View URL")
  }
  let webView = WKWebView()
  webView.isInspectable = true
  webView.scrollView.isScrollEnabled = false
  let html = makeHTML(url: url)
  webView.loadHTMLString(html, baseURL: url)
  return webView
}

private func makeStreetViewURL(
  image: Model.Image
) -> URL? {
  var components = URLComponents()
  components.scheme = "https"
  components.host = "www.google.com"
  components.path = "/maps/embed/v1/streetview"
  components.queryItems = Array.build {
    URLQueryItem(name: "key", value: Secrets.googleMapsApiKey)
    URLQueryItem(
      name: "location",
      value: "\(image.coordinate.latitude),\(image.coordinate.longitude)"
    )
    if let heading = image.dir?.angleDegrees {
      URLQueryItem(name: "heading", value: "\(heading)")
    }
  }
  return components.url
}

private func makeHTML(
  url: URL
) -> String {
  let src = url.absoluteString
    .replacingOccurrences(of: "&", with: "&amp;")
    .replacingOccurrences(of: "\"", with: "&quot;")

  return """
  <!doctype html>
  <html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <style>
      html, body {
        margin: 0;
        padding: 0;
        height: 100%;
        overflow: hidden;
      }

      iframe {
        position: absolute;
        inset: 0;
        width: 100%;
        height: 100%;
        min-width: 50px; /* if size is 0x0, pov breaks */
        min-height: 50px;
        border: 0;
        display: block;
      }
    </style>
  </head>
  <body>
    <iframe src="\(src)" allowfullscreen loading="eager"></iframe>
  </body>
  </html>
  """
}
