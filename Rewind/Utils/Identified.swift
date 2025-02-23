//
//  Identified.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 09.02.2025.
//

import SwiftUI

struct Identified<Value>: Identifiable {
  let id: UUID = .init()
  let value: Value
}
