//
//  FavoritesModelTests.swift
//  RewindTests
//
//  FavoritesModel dedups add/remove by Model.Image's cid-only equality (Model.Image.== compares
//  only `cid`, ignoring every other field). These tests pin that behavior with two DISTINCT
//  instances sharing a cid but differing in every other field, so a port that widened equality to
//  the full struct (or compared some other key) would fail: it would either grow a duplicate entry
//  on re-favoriting the same photo from a different source screen, or fail to find/remove the
//  stored entry when the caller only has a partially-populated instance (e.g. one rehydrated from
//  persisted Storage.Image, which carries fewer fields than a freshly-fetched Model.Image).
//

import CoreLocation
@testable import Rewind
import Testing
import VGSL

@MainActor
struct FavoritesModelTests {
  /// Adding an image whose cid already exists in favorites is a no-op: the original entry is kept
  /// (not replaced), and the synchronous storage effect is not re-invoked for the duplicate.
  @Test func addToFavoritesDedupesByCidKeepingTheFirstEntry() {
    let storage = StorageSpy()
    let model = makeFavoritesModel(storage: storage.property)

    let first = makeImage(cid: 1, title: "A", imagePath: "a.jpg", year: 1900)
    let sameCidDifferentEverythingElse = makeImage(
      cid: 1,
      title: "B",
      imagePath: "b.jpg",
      year: 1950
    )

    model(.addToFavorites(first))
    model(.addToFavorites(sameCidDifferentEverythingElse))

    #expect(model.state.count == 1)
    #expect(model.state.first?.title == "A")
    #expect(model.state.first?.imagePath == "a.jpg")

    // The second dispatch hit the `guard !state.contains(image)` and returned before enqueuing
    // the persistence effect at all — not just "persisted the same thing twice".
    #expect(storage.writes.count == 1)
    #expect(storage.writes.last?.map(\.title) == ["A"])
  }

  /// Removing an image finds the stored entry by cid alone: an instance with the same cid but
  /// different title/imagePath/coordinate still matches and is removed; an unrelated cid is a
  /// no-op that neither changes state nor re-invokes the storage effect.
  @Test func removeFromFavoritesMatchesStoredEntryByCidAlone() {
    let toRemove = makeImage(cid: 1, title: "A", imagePath: "a.jpg", year: 1900)
    let toKeep = makeImage(cid: 2, title: "B", imagePath: "b.jpg", year: 1950)
    let storage = StorageSpy(initial: [toRemove, toKeep])
    let model = makeFavoritesModel(storage: storage.property)

    let differentInstanceSameCid = modified(
      makeImage(cid: 1, title: "Z", imagePath: "z.jpg", year: 2020),
    ) {
      $0.coordinate = CLLocationCoordinate2D(latitude: 10, longitude: 20)
    }
    model(.removeFromFavorites(differentInstanceSameCid))

    #expect(model.state.count == 1)
    #expect(model.state.first?.cid == 2)
    #expect(model.state.first?.title == "B")
    #expect(storage.writes.count == 1)
    #expect(storage.writes.last?.map(\.title) == ["B"])

    // An unrelated cid finds no index (`firstIndex(of:)` returns nil) — state and storage are
    // both left untouched, not just "unchanged after another identical write".
    model(.removeFromFavorites(makeImage(cid: 99, title: "Nope", imagePath: "nope.jpg", year: 1)))
    #expect(model.state.count == 1)
    #expect(storage.writes.count == 1)
  }
}

// MARK: - Fixtures

private func makeImage(
  cid: Int,
  title: String,
  imagePath: String,
  year: Int,
) -> Model.Image {
  modified(Model.Image.mock) {
    $0.cid = cid
    $0.title = title
    $0.imagePath = imagePath
    $0.date = ImageDate(year: year, year2: year)
  }
}

@MainActor
private final class StorageSpy {
  private(set) var writes: [[Model.Image]] = []
  private var value: [Model.Image]

  init(initial: [Model.Image] = []) {
    value = initial
  }

  var property: Property<[Model.Image]> {
    Property(
      getter: { [weak self] in self?.value ?? [] },
      setter: { [weak self] newValue in
        self?.value = newValue
        self?.writes.append(newValue)
      },
    )
  }
}
