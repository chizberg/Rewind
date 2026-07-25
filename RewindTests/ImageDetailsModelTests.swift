//
//  ImageDetailsModelTests.swift
//  RewindTests
//
//  Tests the description-link routing in the ImageDetails reducer: a link to a pastvu photo
//  (https://pastvu.com/p/<cid>) recurses into a nested ImageDetails screen loaded from the remote,
//  while any other link (external host, or a non-photo pastvu path) is handed to the url opener.
//  The routing hinges on a branchy URL parse (host + /p/ path + integer cid), which is exactly the
//  kind of quirk worth pinning; the raw button/url string tables are not tested.
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
    let model = harness.makeModel()

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
    let model = harness.makeModel()

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
    let model = harness.makeModel()

    let userPage = try #require(URL(string: "https://pastvu.com/u/someone"))
    model(.descriptionLink(userPage))

    #expect(await eventually { harness.openedURLs == [userPage] })
    #expect(model.state.anotherImageModel == nil)
    #expect(harness.requestedCids.isEmpty)
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
  func makeModel() -> ImageDetailsModel {
    makeImageDetailsModel(
      modelImage: .mock,
      remote: Remote { [weak self] cid in
        self?.requestedCids.append(cid)
        return modified(.mock) { $0.cid = cid }
      },
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
