//
//  DownloadRequest.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 6. 9. 2026.
//

import Foundation

extension Network {
  struct DownloadRequest<Response> {
    let makeURLRequest: () throws -> URLRequest
    let processFile: (URL) async throws -> Response
  }
}
