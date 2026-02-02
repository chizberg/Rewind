//
//  BinSearch.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 25. 1. 2026.
//

import Foundation

func binSearch<T: Numeric & Comparable>(
  firstEqualOrGreaterThan goal: T,
  in arr: [T]
) -> Int? {
  guard arr.count > 0 else { return nil }
  guard arr.count > 1 else { return arr[0] >= goal ? 0 : nil }
  var lhs = 0
  var rhs = arr.count - 1
  while arr[lhs + 1] < arr[rhs] {
    let mid = (lhs + rhs) / 2
    if arr[mid] >= goal {
      rhs = mid
    } else {
      lhs = mid
    }
  }
  if arr[lhs] >= goal { return lhs }
  if arr[rhs] >= goal { return rhs }
  return nil
}

func binSearch<T, U: Numeric & Comparable>(
  firstEqualOrGreaterThan goal: U,
  keyPath kp: KeyPath<T, U>,
  in arr: [T]
) -> Int? {
  guard arr.count > 0 else { return nil }
  guard arr.count > 1 else { return arr[0][keyPath: kp] >= goal ? 0 : nil }
  var lhs = 0
  var rhs = arr.count - 1
  while arr[lhs + 1][keyPath: kp] < arr[rhs][keyPath: kp] {
    let mid = (lhs + rhs) / 2
    if arr[mid][keyPath: kp] >= goal {
      rhs = mid
    } else {
      lhs = mid
    }
  }
  if arr[lhs][keyPath: kp] >= goal { return lhs }
  if arr[rhs][keyPath: kp] >= goal { return rhs }
  return nil
}
