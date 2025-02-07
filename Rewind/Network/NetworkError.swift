//
//  NetworkError.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 02.02.2025.
//

import Foundation

enum NetworkError: Error {
  case invalidURL
  case connectionFailure(Error)
  case invalidCode(Int)
  case parsingFailure(Error? = nil, desc: String? = nil)
}
