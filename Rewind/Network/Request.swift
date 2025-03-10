//
//  Request.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 02.02.2025.
//

import Foundation
import UIKit

enum Network {} // namespace only

extension Network {
  struct Request<Response> {
    let makeURLRequest: () -> URLRequest
    let parseResult: (Data) throws -> Response
  }
}

extension Network.Request {
  static func byBounds(
    zoom: Int,
    coordinates: [[Double]],
    startAt: TimeInterval,
    yearRange: ClosedRange<Int>
  ) -> Network.Request<([Network.Image], [Network.Cluster])> {
    Network.byBounds(zoom: zoom, coordinates: coordinates, startAt: startAt, yearRange: yearRange)
  }

  // TODO: more aestetically pleasing extensions
  static func imageDetails(cid: Int) -> Network.Request<Network.ImageDetails> {
    Network.imageDetails(cid: cid)
  }

  static func image(path: String, quality: ImageQuality) -> Network.Request<UIImage> {
    Network.image(path: path, quality: quality)
  }
}

private func makeBaseURLComponents() -> URLComponents {
  var components = URLComponents()
  components.scheme = "https"
  components.host = "pastvu.com"
  return components
}

private func isLocalWork(zoom: Int) -> Bool {
  zoom >= 17
}

extension Network {
  fileprivate static func byBounds(
    zoom: Int,
    coordinates: [[Double]],
    startAt: TimeInterval,
    yearRange: ClosedRange<Int>
  ) -> Request<([Image], [Cluster])> {
    struct RawParams: Encodable {
      struct Geometry: Encodable {
        let type: String = "Polygon"
        let coordinates: [[[Double]]]
      }

      let z: Int
      let year: Int
      let year2: Int
      let isPainting: Bool
      let localWork: Bool
      let geometry: Geometry
      let startAt: TimeInterval
    }

    struct RawResponse: Decodable {
      struct ClusteredImages: Decodable {
        let photos: [Network.Image]?
        let clusters: [Network.Cluster]?
      }

      let result: ClusteredImages
    }

    return Request<([Image], [Cluster])>(
      makeURLRequest: {
        var components = makeBaseURLComponents()
        components.path = "/api2"
        let rawParams = RawParams(
          z: zoom,
          year: yearRange.lowerBound,
          year2: yearRange.upperBound,
          isPainting: false, // TODO: support for paintings
          localWork: isLocalWork(zoom: zoom),
          geometry: .init(
            coordinates: [coordinates]
          ),
          startAt: startAt
        )
        let paramsString = try? String(data: JSONEncoder().encode(rawParams), encoding: .utf8)
        components.queryItems = [
          URLQueryItem(name: "method", value: "photo.getByBounds"),
          URLQueryItem(name: "params", value: paramsString),
        ]
        return URLRequest(url: components.url!)
      },
      parseResult: { data in
        let raw = try JSONDecoder().decode(RawResponse.self, from: data)
        return (raw.result.photos ?? [], raw.result.clusters ?? [])
      }
    )
  }

  fileprivate static func imageDetails(cid: Int) -> Request<ImageDetails> {
    struct RawParams: Encodable {
      let cid: Int
    }

    struct RawResponse: Decodable {
      struct Result: Decodable {
        let photo: ImageDetails
      }

      let result: Result
    }

    return Request<ImageDetails>(
      makeURLRequest: {
        var components = makeBaseURLComponents()
        components.path = "/api2"
        let rawParams = RawParams(cid: cid)
        let paramsString = try? String(data: JSONEncoder().encode(rawParams), encoding: .utf8)
        components.queryItems = [
          URLQueryItem(name: "method", value: "photo.giveForPage"),
          URLQueryItem(name: "params", value: paramsString),
        ]
        return URLRequest(url: components.url!)
      },
      parseResult: { data in
        let raw = try JSONDecoder().decode(RawResponse.self, from: data)
        return raw.result.photo
      }
    )
  }

  fileprivate static func image(path: String, quality: ImageQuality) -> Request<UIImage> {
    // path contains unexpected query parameters, we have to remove them
    func dropUnexpectedQueryItems(from path: String) -> String {
      guard var urlComponents = URLComponents(string: path) else {
        return path
      }
      urlComponents.query = nil
      return urlComponents.string ?? path
    }
    return Request<UIImage>(
      makeURLRequest: {
        var components = makeBaseURLComponents()
        let clearPath = dropUnexpectedQueryItems(from: path)
        components.path = "/_p/\(quality.linkParam)/\(clearPath)"
        return URLRequest(url: components.url!)
      },
      parseResult: { data in
        if let image = UIImage(data: data) {
          return image
        } else {
          throw NetworkError.parsingFailure(desc: "Image decoding error")
        }
      }
    )
  }
}
