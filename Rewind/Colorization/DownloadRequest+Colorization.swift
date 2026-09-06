//
//  DownloadRequest+Colorization.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 6. 9. 2026.
//

import CoreML
import CryptoKit
import Foundation
import ZIPFoundation

extension Network.DownloadRequest {
  static func colorizationModel(
    _ entry: ColorizationManifest.Entry,
  ) -> Network.DownloadRequest<URL> {
    Network.DownloadRequest(
      makeURLRequest: {
        URLRequest(url: entry.archiveURL)
      },
      processFile: { archive in
        try verify(archive, against: entry)
        let temp = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temp) }
        try await unarchive(archive, to: temp)
        try Task.checkCancellation()
        return try await MLModel.compileModel(at: temp.appending(path: entry.unpackedName))
      },
    )
  }
}

private func verify(_ archive: URL, against entry: ColorizationManifest.Entry) throws {
  let data = try Data(contentsOf: archive, options: .mappedIfSafe)
  guard Int64(data.count) == entry.bytes else {
    throw HandlingError("Archive size \(data.count) differs from the manifest: \(entry.bytes)")
  }
  let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  guard digest == entry.sha256 else {
    throw HandlingError("Archive checksum differs from the manifest")
  }
}

private func unarchive(_ archive: URL, to directory: URL) async throws {
  let progress = Progress()
  try await withTaskCancellationHandler {
    try await Task.detached(priority: .userInitiated) {
      do {
        try FileManager.default.unzipItem(at: archive, to: directory, progress: progress)
      } catch Archive.ArchiveError.cancelledOperation {
        throw CancellationError()
      }
    }.value
  } onCancel: {
    progress.cancel()
  }
}
