//
//  Interpolation.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 25. 1. 2026.
//

import Foundation
import VGSL

protocol Interpolatable {
  func lerp(at: CGFloat, between lhs: Self, _ rhs: Self) -> Self
}

struct InterpolationPoint<Value: Interpolatable> {
  var position: CGFloat
  var value: Value

  init(_ position: CGFloat, _ value: Value) {
    self.position = position
    self.value = value
  }
}

func lerpParameter<T: FloatingPoint>(of value: T, lowerBound: T, upperBound: T) -> T {
  guard value > lowerBound else { return 0 }
  guard value < upperBound else { return 1 }
  return (value - lowerBound) / (upperBound - lowerBound)
}

func lerp<T: Interpolatable>(
  at rawT: CGFloat,
  in values: NonEmptyArray<InterpolationPoint<T>>
) -> T {
  let t = rawT.clamp(values.first.position...values.last.position)
  guard let index = binSearch(
    firstEqualOrGreaterThan: t,
    keyPath: \.position,
    in: values.asArray()
  ) else {
    return values.last.value
  }
  if index == 0 {
    return values.first.value
  }
  let lowerStop = values[index - 1]
  let upperStop = values[index]
  let t1 = lerpParameter(
    of: t,
    lowerBound: lowerStop.position,
    upperBound: upperStop.position
  )
  return lowerStop.value.lerp(at: t1, between: lowerStop.value, upperStop.value)
}

/// VGSL version has a typo
@inlinable
func lerp<T: FloatingPoint>(at: T, between lhs: T, _ rhs: T) -> T {
  VGSL.lerp(at: at, beetween: lhs, rhs)
}
