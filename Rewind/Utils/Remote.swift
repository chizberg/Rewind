//
//  Remote.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 08.02.2025.
//

import Foundation

struct Remote<Args, Response> {
  let impl: (Args) async throws -> Response

  init(_ impl: @escaping (Args) async throws -> Response) {
    self.impl = impl
  }

  func load(_ args: Args) async throws -> Response {
    try await impl(args)
  }

  @discardableResult
  func load(
    _ args: Args,
    completion: @MainActor @escaping (Result<Response, Error>) -> Void
  ) -> Task<Void, Never> {
    Task {
      do {
        let result = try await impl(args)
        await completion(.success(result))
      } catch {
        await completion(.failure(error))
      }
    }
  }

  func mapArgs<NewArgs>(
    _ transform: @escaping (NewArgs) -> Args
  ) -> Remote<NewArgs, Response> {
    Remote<NewArgs, Response> { args in
      try await self.impl(transform(args))
    }
  }

  func mapResponse<NewResponse>(
    _ transform: @escaping (Response) -> NewResponse
  ) -> Remote<Args, NewResponse> {
    Remote<Args, NewResponse> { args in
      try await transform(self.impl(args))
    }
  }

  func exponentialBackoff(
    attemptCount: Int = 3,
    initialDelay: TimeInterval = 1,
    factor: Double = 2.0
  ) -> Remote<Args, Response> {
    Remote<Args, Response> { args in
      var currentDelay = initialDelay
      var lastError: Error?
      for i in 0..<attemptCount {
        do {
          return try await self.impl(args)
        } catch {
          lastError = error
          if i < attemptCount - 1 {
            try await Task.sleep(for: .seconds(currentDelay))
            currentDelay *= factor
          }
        }
      }
      throw lastError!
    }
  }
}

extension Remote where Args == Void {
  func load() async throws -> Response {
    try await impl(())
  }
}

#if DEBUG
extension Remote {
  func delayed(delay: TimeInterval) -> Remote {
    Remote<Args, Response> { args in
      try await Task.sleep(for: .seconds(delay))
      return try await self.impl(args)
    }
  }
}
#endif
