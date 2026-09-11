//
//  DownloadPerformer.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 6. 9. 2026.
//

import Foundation
import VGSL

final class DownloadPerformer {
  enum Progress {
    case downloading(CGFloat)
    case processingFile
  }

  private let session: URLSession

  init(session: URLSession) {
    self.session = session
  }

  @MainActor
  func perform<Response>(
    _ request: Network.DownloadRequest<Response>,
  ) -> Job<Progress, Response> {
    let state = ObservableProperty<Job<Progress, Response>.State>(
      initialValue: .running(.downloading(0))
    )
    let task = Task {
      do {
        let response = try await process(request) { progress in
          onMainThread { state.value = .running(progress) }
        }
        state.value = .finished(.success(response))
      } catch {
        state.value = .finished(.failure(error))
      }
    }
    return Job(state: state.asObservableVariable(), cancel: task.cancel)
  }

  private func process<Response>(
    _ request: Network.DownloadRequest<Response>,
    onProgress: @escaping (Progress) -> Void,
  ) async throws -> Response {
    let file = try await fetch(request.makeURLRequest()) { onProgress(.downloading($0)) }
    defer { try? FileManager.default.removeItem(at: file) }
    do {
      onProgress(.processingFile)
      return try await request.processFile(file)
    } catch is CancellationError {
      throw CancellationError()
    } catch {
      throw NetworkError.parsingFailure(error)
    }
  }

  private func fetch(
    _ request: URLRequest,
    onProgress: @escaping (CGFloat) -> Void,
  ) async throws -> URL {
    let destination = URL.temporaryDirectory.appending(path: UUID().uuidString)
    let finished = Promise<Result<Void, Error>>()
    let task = session.downloadTask(with: request) { location, response, error in
      finished.resolve(Result {
        if let error {
          throw (error as? URLError)?.code == .cancelled
            ? CancellationError()
            : NetworkError.connectionFailure(error)
        }
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
          throw NetworkError.invalidCode(httpResponse.statusCode)
        }
        guard let location else { throw NetworkError.missingFile }
        try FileManager.default.moveItem(at: location, to: destination)
      })
    }
    let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
      onProgress(CGFloat(progress.fractionCompleted))
    }

    defer { observation.invalidate() }
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        finished.future.resolved { continuation.resume(with: $0) }
        task.resume()
      }
    } onCancel: {
      task.cancel()
    }
    return destination
  }
}
