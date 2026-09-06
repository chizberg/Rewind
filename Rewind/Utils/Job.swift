//
//  Job.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 6. 9. 2026.
//

import VGSL

struct Job<Progress, Success> {
  enum State {
    case running(Progress)
    case finished(Result<Success, Error>)
  }

  let state: ObservableVariable<State>
  let cancel: () -> Void
}
