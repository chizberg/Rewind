//
//  SearchModelTests.swift
//  RewindTests
//
//  Tests the search reducer's one asynchronous path: a tapped suggest is resolved and its location
//  — that one's, not another suggest's — is handed to onLocationFound exactly once. The second test
//  covers two taps racing: the newer search cancels the older, so a late answer neither moves the
//  map a second time nor raises an alert. Mirrored by SearchModelTest on Android.
//

import CoreLocation
@testable import Rewind
import Testing

@MainActor
struct SearchModelTests {
  /// Tapping a suggest resolves that suggest, not the first one in the list.
  @Test func suggestSelectedResolvesTappedPlace() async {
    let harness = Harness()
    let model = harness.makeModel()

    model(.external(.suggestSelected(Harness.louvre)))

    #expect(await eventually { harness.foundLocations.count == 1 })
    #expect(harness.foundLocations.first === Harness.louvreLocation)
    #expect(model.state.alertModel == nil)
  }

  /// A second tap while the first search is still in flight: only the second place is handed over,
  /// and the first one's late answer is dropped instead of yanking the map back.
  @Test func secondSuggestSelectionSupersedesTheFirst() async throws {
    let harness = Harness()
    harness.delayFirstSearch = true
    let model = harness.makeModel()

    model(.external(.suggestSelected(Harness.eiffel)))
    #expect(await eventually { harness.searchedQueries.count == 1 }) // first search started

    model(.external(.suggestSelected(Harness.louvre)))
    #expect(await eventually { harness.foundLocations.count == 1 })

    // Past the point the first search would have answered had it not been cancelled.
    try await Task.sleep(for: .milliseconds(400))

    #expect(harness.foundLocations.count == 1)
    #expect(harness.foundLocations.first === Harness.louvreLocation)
    #expect(model.state.alertModel == nil) // cancellation is silent
  }
}

@MainActor
private final class Harness {
  static let eiffel = SearchState.Suggest(title: "Eiffel Tower", subtitle: "Paris, France")
  static let louvre = SearchState.Suggest(title: "Louvre Museum", subtitle: "Paris, France")
  static let eiffelLocation = CLLocation(latitude: 48.8584, longitude: 2.2945)
  static let louvreLocation = CLLocation(latitude: 48.8606, longitude: 2.3376)

  private(set) var foundLocations: [CLLocation] = []
  private(set) var searchedQueries: [String] = []
  var delayFirstSearch = false

  func makeModel() -> SearchModel {
    makeSearchModel(
      onLocationFound: { [weak self] in self?.foundLocations.append($0) },
      search: { [weak self] query in
        guard let self else { return nil }
        searchedQueries.append(query)
        if delayFirstSearch, searchedQueries.count == 1 {
          try await Task.sleep(for: .milliseconds(200))
        }
        return Harness.location(matching: query)
      },
    )
  }

  /// Matches on the place's name rather than on the query string the reducer assembles, so the
  /// test pins which suggest was resolved without restating how that query is built.
  private static func location(matching query: String) -> CLLocation? {
    if query.contains(louvre.title) {
      louvreLocation
    } else if query.contains(eiffel.title) {
      eiffelLocation
    } else {
      nil
    }
  }
}

@MainActor
private func eventually(
  timeout: Duration = .seconds(2),
  _ condition: () -> Bool,
) async -> Bool {
  let deadline = ContinuousClock().now.advanced(by: timeout)
  while !condition() {
    if ContinuousClock().now >= deadline { return false }
    try? await Task.sleep(for: .milliseconds(5))
  }
  return true
}
