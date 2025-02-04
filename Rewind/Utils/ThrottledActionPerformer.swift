//
//  ThrottledActionPerformer.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 04.02.2025.
//

import Foundation

import VGSL

final class ThrottledActionPerformer: NSObject {
  private var delay: Double
  private var action: Action = {}

  init(delay: Double = defaultDelay) {
    self.delay = delay
  }

  func throttledCall(_ action: @escaping Action) {
    cancelPreviousPerform()
    self.action = action
    self.perform(#selector(performAction), with: nil, afterDelay: delay)
  }

  private func cancelPreviousPerform() {
    NSObject.cancelPreviousPerformRequests(
      withTarget: self,
      selector: #selector(performAction),
      object: nil
    )
  }

  @objc private func performAction() {
    action()
  }
}

private let defaultDelay: Double = 0.15
