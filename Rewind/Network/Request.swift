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
    let makeURLRequest: () throws -> URLRequest
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

  static func streetViewAvailability(coordinate: Coordinate) -> Network
    .Request<StreetViewAvailability> {
    Network.streetViewAvailability(coordinate: coordinate)
  }

  static func translate(params: TranslateParams) -> Network.Request<String> {
    Network.translate(params: params)
  }
}

private func makeBaseURLComponents() -> URLComponents {
  var components = URLComponents()
  components.scheme = "https"
  components.host = "api.pastvu.com"
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
        let paramsString = try String(data: JSONEncoder().encode(rawParams), encoding: .utf8)
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
        let paramsString = try String(data: JSONEncoder().encode(rawParams), encoding: .utf8)
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
        var components = URLComponents()
        components.scheme = "https"
        components.host = "img.pastvu.com"
        let clearPath = dropUnexpectedQueryItems(from: path)
        components.path = "/\(quality.linkParam)/\(clearPath)"
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

  // https://developers.google.com/maps/documentation/streetview/metadata
  fileprivate static func streetViewAvailability(coordinate: Coordinate)
    -> Request<StreetViewAvailability> {
    struct Response: Decodable {
      enum Status: String, Decodable {
        case ok = "OK"
        case zeroResults = "ZERO_RESULTS"
        case notFound = "NOT_FOUND"
        case overQueryLimit = "OVER_QUERY_LIMIT"
        case requestDenied = "REQUEST_DENIED"
        case invalidRequest = "INVALID_REQUEST"
        case unknownError = "UNKNOWN_ERROR"
      }

      let status: Status
      let date: String?
    }

    func extractYear(date: String?) throws -> Int {
      guard let date else { throw HandlingError("Date is missing") }
      let s = date.trimmingCharacters(in: .whitespacesAndNewlines)
      guard
        let yearStr = s.split(
          separator: "-",
          maxSplits: 1,
          omittingEmptySubsequences: true
        ).first,
        yearStr.allSatisfy(\.isNumber),
        let year = Int(yearStr)
      else {
        throw HandlingError("Invalid date format")
      }
      return year
    }

    return Request(
      makeURLRequest: {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "maps.googleapis.com"
        components.path = "/maps/api/streetview/metadata"
        components.queryItems = [
          URLQueryItem(
            name: "location",
            value: "\(coordinate.latitude),\(coordinate.longitude)"
          ),
          URLQueryItem(
            name: "key",
            value: Secrets.googleApiKey
          ),
        ]
        return URLRequest(url: components.url!)
      },
      parseResult: { data in
        let response = try JSONDecoder().decode(Response.self, from: data)
        if response.status == .ok {
          let year = try extractYear(date: response.date)
          return .available(year: year)
        } else {
          return .unavailable
        }
      }
    )
  }

  // https://docs.cloud.google.com/translate/docs/reference/rest/v2/translate
  fileprivate static func translate(params: TranslateParams) -> Request<String> {
    struct Response: Decodable {
      struct Data: Decodable {
        struct Translation: Decodable {
          let translatedText: String
          let model: String?
          let detectedSourceLanguage: String?
        }

        let translations: [Translation]
      }

      let data: Data
    }

    return Request(
      makeURLRequest: {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "translation.googleapis.com"
        components.path = "/language/translate/v2"
        components.queryItems = [
          URLQueryItem(name: "key", value: Secrets.googleApiKey),
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
          "q": params.text,
          "target": params.target,
          "format": "text",
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
      },
      parseResult: { data in
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard let translation = response.data.translations.first else {
          throw HandlingError("No translations found")
        }
        return translation.translatedText
      }
    )
  }
}
