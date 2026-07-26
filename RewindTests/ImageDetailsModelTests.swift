//
//  ImageDetailsModelTests.swift
//  RewindTests
//
//  Tests two branchy parts of the ImageDetails reducer. Description-link routing: a link to a
//  pastvu photo (https://pastvu.com/p/<cid>) recurses into a nested ImageDetails screen loaded
//  from the remote, while any other link (external host, or a non-photo pastvu path) is handed to
//  the url opener — the routing hinges on a URL parse (host + /p/ path + integer cid). And details
//  seeding: details already known when the model is built land in the initial state instead of
//  arriving as a later update, which is what keeps a cached screen from redrawing on open.
//  The raw button/url string tables are not tested.
//

import Foundation
@testable import Rewind
import Testing
import VGSL

@MainActor
struct ImageDetailsModelTests {
  /// A link to a pastvu photo loads that photo's details from the remote and presents them as a
  /// nested details screen; loadingAnotherImage flips true while the load is in flight, and the
  /// external url opener is never called.
  @Test func pastvuPhotoLinkOpensNestedDetails() async {
    let harness = Harness()
    let model = harness.makeModel(cachedDetails: nil)

    let linkedCid = 2_223_969
    model(.descriptionLink(pastvuPhotoURL(linkedCid)))
    #expect(model.state.loadingAnotherImage) // set synchronously, before the load returns

    #expect(await eventually { model.state.anotherImageModel != nil })
    #expect(!model.state.loadingAnotherImage) // cleared once the nested model is presented
    #expect(harness.requestedCids == [linkedCid]) // the remote was asked for the linked photo
    #expect(harness.openedURLs.isEmpty) // recursion, not a browser hand-off
  }

  /// A link to an external host is opened in the browser rather than recursing.
  @Test func externalLinkOpensInBrowser() async throws {
    let harness = Harness()
    let model = harness.makeModel(cachedDetails: nil)

    let external = try #require(URL(string: "https://example.com/gallery"))
    model(.descriptionLink(external))

    #expect(await eventually { harness.openedURLs == [external] })
    #expect(!model.state.loadingAnotherImage)
    #expect(model.state.anotherImageModel == nil)
    #expect(harness.requestedCids.isEmpty)
  }

  /// A pastvu link that is not a photo page (e.g. a user profile) is opened in the browser, not
  /// mistaken for a photo to recurse into.
  @Test func nonPhotoPastvuLinkOpensInBrowser() async throws {
    let harness = Harness()
    let model = harness.makeModel(cachedDetails: nil)

    let userPage = try #require(URL(string: "https://pastvu.com/u/someone"))
    model(.descriptionLink(userPage))

    #expect(await eventually { harness.openedURLs == [userPage] })
    #expect(model.state.anotherImageModel == nil)
    #expect(harness.requestedCids.isEmpty)
  }

  /// Details known upfront are part of the very first state, indistinguishable from a state the
  /// network just filled in — so the screen renders complete in its first frame instead of
  /// updating a frame later — and presenting it doesn't ask for them again.
  @Test func knownDetailsSeedInitialState() async {
    let harness = Harness()
    let details = modified(Model.ImageDetails.mock) { $0.description = "Вулица Кастрычницкая" }
    let seeded = harness.makeModel(cachedDetails: details)
    let loaded = harness.makeModel(cachedDetails: nil)
    loaded(.internal(.detailsLoaded(details)))

    let seededAttributes = seeded.state.attributedDetails
    let loadedAttributes = loaded.state.attributedDetails

    #expect(seeded.state.details?.cid == details.cid)
    #expect(seededAttributes?.description.map { String($0.characters) } == details.description)
    #expect(seededAttributes?.description == loadedAttributes?.description)
    #expect(seededAttributes?.author == loadedAttributes?.author)
    #expect(seededAttributes?.address == loadedAttributes?.address)
    #expect(seededAttributes?.source == loadedAttributes?.source)
    #expect(seeded.state.translationState == loaded.state.translationState)

    seeded(.willBePresented)

    #expect(await eventually { seeded.state.uiImage != nil }) // image effects still run
    #expect(harness.requestedCids.isEmpty) // details were not refetched
  }

  /// Without known details, presentation loads them and applies them to the same fields the seed
  /// fills in.
  @Test func unknownDetailsAreLoadedOnPresentation() async {
    let harness = Harness()
    let model = harness.makeModel(cachedDetails: nil)

    #expect(model.state.details == nil)
    model(.willBePresented)

    #expect(await eventually { model.state.details != nil })
    #expect(model.state.attributedDetails != nil)
    #expect(harness.requestedCids == [Model.Image.mock.cid])
  }
}

private func pastvuPhotoURL(_ cid: Int) -> URL {
  URL(string: "https://pastvu.com/p/\(cid)")!
}

@MainActor
private final class Harness {
  private(set) var openedURLs: [URL] = []
  private(set) var requestedCids: [Int] = []

  // Both closures below are non-Sendable and formed in this @MainActor context, so they inherit
  // main-actor isolation — their bodies hop back to the main actor before touching harness state.
  func makeModel(cachedDetails: Model.ImageDetails?) -> ImageDetailsModel {
    makeImageDetailsModel(
      modelImage: .mock,
      remote: Remote { [weak self] cid in
        self?.requestedCids.append(cid)
        return modified(.mock) { $0.cid = cid }
      },
      cachedDetails: cachedDetails,
      openSource: "",
      favoritesModel: .mock,
      showOnMap: { _ in },
      canOpenURL: { _ in true },
      urlOpener: { [weak self] in self?.openedURLs.append($0) },
      setOrientationLock: { _ in },
      streetViewAvailability: .mock(.unavailable),
      translate: .mock("translated"),
      extractModelImage: { _ in .mock },
    )
  }
}

// MARK: - Async helpers (mirrors MapModelTests: async effects run in a Task we can't await)

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
