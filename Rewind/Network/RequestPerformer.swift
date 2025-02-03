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
    print(urlRequest)
    let data = try await data(for: urlRequest)
    do {
      return try request.parseResult(data)
    } catch {
      throw NetworkError.parsingFailure(error)
    }
  }

  private func data(for request: URLRequest) async throws -> Data {
    do {
      let (data, _) = try await urlRequestPerformer(request)
      return data
    } catch {
      throw NetworkError.connectionFailure(error)
    }
  }
}
