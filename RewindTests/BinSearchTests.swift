//
//  BinSearchTests.swift
//  RewindTests
//
//  Characterization tests for binSearch(firstEqualOrGreaterThan:in:) — a branchy
//  binary search with a non-standard loop invariant (arr[lhs+1] < arr[rhs]) and
//  three tail checks. Expected indices are hand-worked from the contract
//  ("index of the first element >= goal, or nil if none"), never by re-running
//  the search. These boundary cases (empty, single, goal below/above/at/between
//  elements) exercise branches that the gradient pipeline can't reach — it always
//  clamps its parameter into [first, last], so "goal above all -> nil" and the
//  empty/single paths are only observable here.
//

@testable import Rewind
import Testing

struct BinSearchTests {
  @Test func emptyArrayIsNil() {
    #expect(binSearch(firstEqualOrGreaterThan: 5, in: [Int]()) == nil)
  }

  @Test func singleElement() {
    #expect(binSearch(firstEqualOrGreaterThan: 5, in: [5]) == 0) // equal
    #expect(binSearch(firstEqualOrGreaterThan: 4, in: [5]) == 0) // greater
    #expect(binSearch(firstEqualOrGreaterThan: 6, in: [5]) == nil) // none >= goal
  }

  // arr = [1, 3, 5, 7, 9]; answers are the first index whose value is >= goal.
  @Test func exactMatchReturnsThatIndex() {
    #expect(binSearch(firstEqualOrGreaterThan: 5, in: [1, 3, 5, 7, 9]) == 2)
  }

  @Test func betweenElementsReturnsUpperNeighbour() {
    // 4 sits between 3 and 5 -> first element >= 4 is 5 at index 2.
    #expect(binSearch(firstEqualOrGreaterThan: 4, in: [1, 3, 5, 7, 9]) == 2)
  }

  @Test func belowAllReturnsFirst() {
    #expect(binSearch(firstEqualOrGreaterThan: 0, in: [1, 3, 5, 7, 9]) == 0)
  }

  @Test func atLastReturnsLast() {
    #expect(binSearch(firstEqualOrGreaterThan: 9, in: [1, 3, 5, 7, 9]) == 4)
  }

  @Test func aboveAllIsNil() {
    #expect(binSearch(firstEqualOrGreaterThan: 10, in: [1, 3, 5, 7, 9]) == nil)
  }
}
