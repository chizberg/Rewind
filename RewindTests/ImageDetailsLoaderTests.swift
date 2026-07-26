//
//  ImageDetailsLoaderTests.swift
//  RewindTests
//
//  Tests the in-memory cache in ImageDetailsLoader (the details counterpart of ImageLoader's
//  image cache): details fetched once are reused for every later load of the same photo,
//  distinct photos don't share an entry, clearCache() (fired on memory warnings) forces a
//  refetch, and a failed load leaves nothing cached. The stub network echoes the requested cid
//  back and stamps every response with its fetch number, so a cached value is distinguishable
//  from a refetched one.
//

import Foundation
@testable import Rewind
import Testing

@MainActor
struct ImageDetailsLoaderTests {
  /// Loading the same photo twice performs a single request; the second load is served from cache.
  @Test func repeatedLoadIsServedFromCache() async throws {
    let network = NetworkStub()
    let loader = makeLoader(network: network)

    let first = try await loader.load(cid: 42)
    let second = try await loader.load(cid: 42)

    #expect(await network.requestedCids == [42])
    #expect(first.cid == 42)
    #expect(first.title == "fetch #1")
    #expect(second.title == "fetch #1") // not refetched, hence not "fetch #2"
  }

  /// Every photo gets its own cache entry: two photos are fetched once each and never mixed up.
  @Test func detailsAreCachedPerImage() async throws {
    let network = NetworkStub()
    let loader = makeLoader(network: network)

    let first = try await loader.load(cid: 1)
    let second = try await loader.load(cid: 2)
    let firstAgain = try await loader.load(cid: 1)
    let secondAgain = try await loader.load(cid: 2)

    #expect(await network.requestedCids == [1, 2])
    #expect(firstAgain.cid == 1)
    #expect(firstAgain.title == first.title)
    #expect(secondAgain.cid == 2)
    #expect(secondAgain.title == second.title)
    #expect(first.title != second.title)
  }

  /// Clearing the cache (what a memory warning does) makes the next load hit the network again.
  @Test func clearCacheForcesRefetch() async throws {
    let network = NetworkStub()
    let loader = makeLoader(network: network)

    _ = try await loader.load(cid: 7)
    loader.clearCache()
    let refetched = try await loader.load(cid: 7)

    #expect(await network.requestedCids == [7, 7])
    #expect(refetched.title == "fetch #2")
  }

  /// What the details screen reads while building its initial state: cached details are available
  /// without a suspension once loaded, and only for photos that are actually in the cache.
  @Test func cachedIsReadableWithoutLoading() async throws {
    let network = NetworkStub()
    let loader = makeLoader(network: network)

    #expect(loader.cached(cid: 5) == nil)
    let loaded = try await loader.load(cid: 5)

    #expect(loader.cached(cid: 5)?.title == loaded.title)
    #expect(loader.cached(cid: 6) == nil)
    loader.clearCache()
    #expect(loader.cached(cid: 5) == nil)
  }

  /// A failed load caches nothing, so a later load retries instead of replaying the failure.
  @Test func failedLoadIsNotCached() async throws {
    let network = NetworkStub()
    await network.failNextRequests(1)
    let loader = makeLoader(network: network)

    await #expect(throws: (any Error).self) {
      try await loader.load(cid: 3)
    }
    let details = try await loader.load(cid: 3)
    let cached = try await loader.load(cid: 3)

    #expect(await network.requestedCids == [3, 3]) // the failure did not poison the cache
    #expect(details.cid == 3)
    #expect(cached.title == details.title)
  }
}

@MainActor
private func makeLoader(network: NetworkStub) -> ImageDetailsLoader {
  ImageDetailsLoader(
    requestPerformer: RequestPerformer(
      urlRequestPerformer: { request in try await network.respond(to: request) }
    )
  )
}

/// Stands in for the PastVu API: records the cid of every request and answers with details for
/// that cid, titled with the number of the fetch that produced them.
private actor NetworkStub {
  private(set) var requestedCids: [Int] = []
  private var fetchCount = 0
  private var failuresLeft = 0

  func failNextRequests(_ count: Int) {
    failuresLeft = count
  }

  func respond(to request: URLRequest) throws -> (Data, URLResponse) {
    let cid = try requestedCid(from: request)
    requestedCids.append(cid)
    if failuresLeft > 0 {
      failuresLeft -= 1
      throw HandlingError("network is down")
    }
    fetchCount += 1
    return try (detailsJSON(cid: cid, title: "fetch #\(fetchCount)"), URLResponse())
  }
}

private func requestedCid(from request: URLRequest) throws -> Int {
  struct Params: Decodable {
    var cid: Int
  }

  guard let url = request.url,
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
        let params = components.queryItems?.first(where: { $0.name == "params" })?.value
  else {
    throw HandlingError("unexpected request: \(request)")
  }
  return try JSONDecoder().decode(Params.self, from: Data(params.utf8)).cid
}

private func detailsJSON(cid: Int, title: String) throws -> Data {
  let photo: [String: Any] = [
    "cid": cid,
    "file": "a/b/c.jpg",
    "title": title,
    "geo": [44.813047, 20.460579],
    "year": 1958,
    "year2": 1965,
    "ldate": "2022-09-30T16:52:26.687Z",
    "user": ["disp": "Николай"],
  ]
  return try JSONSerialization.data(withJSONObject: ["result": ["photo": photo]])
}
