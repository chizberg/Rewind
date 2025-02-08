//
//  Remote.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 08.02.2025.
//

struct Remote<Args, Response> {
  let impl: (Args) async throws -> Response

  init(_ impl: @escaping (Args) async throws -> Response) {
    self.impl = impl
  }

  func callAsFunction(_ args: Args) async throws -> Response {
    try await impl(args)
  }

  @discardableResult
  func callAsFunction(
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
}

extension Remote where Args == Void {
  func callAsFunction() async throws -> Response {
    try await impl(())
  }
}
