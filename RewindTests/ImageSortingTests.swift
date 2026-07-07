//
//  ImageSortingTests.swift
//  RewindTests
//
//  Characterization tests for [Model.Image].sorted(by:). Only the deterministic
//  branches (.dateAscending / .dateDescending) are pinned; .shuffle is a
//  nondeterministic stdlib pass-through and is intentionally not tested.
//

@testable import Rewind
import Testing

struct ImageSortingTests {
  private func image(cid: Int, year: Int) -> Model.Image {
    let ni = Network.Image(
      cid: cid,
      file: "\(cid).jpg",
      title: "t\(cid)",
      dir: nil,
      geo: [0, 0],
      year: year,
      year2: year,
    )
    return Model.Image(ni, image: .mock)
  }

  @Test func dateAscendingOrdersByDate() {
    let images = [
      image(cid: 1, year: 1900),
      image(cid: 2, year: 1850),
      image(cid: 3, year: 2000),
    ]
    let sorted = images.sorted(by: .dateAscending)
    #expect(sorted.map(\.date.year) == [1850, 1900, 2000])
    #expect(sorted.map(\.cid) == [2, 1, 3])
  }

  @Test func dateDescendingOrdersByDateDesc() {
    let images = [
      image(cid: 1, year: 1900),
      image(cid: 2, year: 1850),
      image(cid: 3, year: 2000),
    ]
    // Assert against hardcoded literals, not against the ascending SUT output
    // reversed (that would be self-referential — a symmetric comparator bug
    // could pass it).
    let desc = images.sorted(by: .dateDescending)
    #expect(desc.map(\.date.year) == [2000, 1900, 1850])
    #expect(desc.map(\.cid) == [3, 1, 2])
  }
}
