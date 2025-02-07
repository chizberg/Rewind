//
//  NetworkService.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 02.02.2025.
//

import Foundation

typealias URLRequestPerformer = (URLRequest) async throws -> (Data, URLResponse)

final class RequestPerformer {
  private let urlRequestPerformer: URLRequestPerformer

  init(urlRequestPerformer: @escaping URLRequestPerformer) {
    self.urlRequestPerformer = urlRequestPerformer
  }

  func perform<Response>(
    request: Network.Request<Response>
  ) async throws -> Response {
    let urlRequest = request.makeURLRequest()
    let data = try await data(for: urlRequest)
    do {
      return try request.parseResult(data)
    } catch {
      throw NetworkError.parsingFailure(error)
    }
  }

  private func data(for request: URLRequest) async throws -> Data {
    do {
      let (data, response) = try await urlRequestPerformer(request)
      if let httpResponse = response as? HTTPURLResponse,
         !(200..<300).contains(httpResponse.statusCode) {
        throw NetworkError.invalidCode(httpResponse.statusCode)
      }
      return data
    } catch {
      throw NetworkError.connectionFailure(error)
    }
  }
}
