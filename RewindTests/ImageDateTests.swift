//
//  ImageDateTests.swift
//  RewindTests
//
//  Characterization tests for ImageDate.description (single year vs range) and
//  its lexicographic Comparable ordering by (year, year2).
//

@testable import Rewind
import Testing

struct ImageDateTests {
  @Test func comparableOrdersByYearFirst() {
    #expect(ImageDate(year: 1890, year2: 1895) < ImageDate(year: 1900, year2: 1800))
  }

  @Test func comparableBreaksTieOnYear2() {
    // Same year -> must fall back to year2.
    #expect(ImageDate(year: 1890, year2: 1895) < ImageDate(year: 1890, year2: 1896))
    #expect(!(ImageDate(year: 1890, year2: 1896) < ImageDate(year: 1890, year2: 1895)))
  }
}
