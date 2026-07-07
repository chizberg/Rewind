//
//  NetworkParsingTests.swift
//  RewindTests
//
//  Characterization tests: decode the recorded PastVu API fixtures into the
//  Decodable DTOs and map them into the Model layer. Pins the exact field
//  mapping, the CodingKey remaps (p/c/geo, user.disp), the [lat,lon] geo order,
//  and the preview-coordinate `.reversed()` quirk in Model.Cluster.
//

import Foundation
@testable import Rewind
import Testing
import VGSL

// Test-local mirrors of the private RawResponse structs in Request.swift.
private struct RawResponse: Decodable {
  struct ClusteredImages: Decodable {
    let photos: [Network.Image]?
    let clusters: [Network.Cluster]?
  }

  let result: ClusteredImages
}

private struct DetailsResponse: Decodable {
  struct Result: Decodable {
    let photo: Network.ImageDetails
  }

  let result: Result
}

struct NetworkParsingTests {
  private func decodeBounds(_ name: String) throws -> RawResponse.ClusteredImages {
    try JSONDecoder().decode(RawResponse.self, from: Fixture.data(name)).result
  }

  private func decodeDetails(_ name: String) throws -> Network.ImageDetails {
    try JSONDecoder().decode(DetailsResponse.self, from: Fixture.data(name)).result.photo
  }

  // MARK: - Network.Image decoding

  @Test func photosFixtureDecodes() throws {
    // Each photo also carries an unknown "__v" key; a successful decode proves
    // the decoder silently ignores it (no separate obvious-logic test for that).
    let result = try decodeBounds("getByBounds_photos.json")
    #expect(result.photos?.isEmpty == false)
    #expect(result.clusters == nil) // key absent in this fixture
  }

  @Test func firstPhotoFieldsAndGarbageQueryPreserved() throws {
    let photos = try #require(decodeBounds("getByBounds_photos.json").photos)
    let first = photos[0]
    #expect(first.cid == 1_959_860)
    // The `?s=...` garbage query param must survive verbatim into `file`.
    #expect(first.file == "q/q/p/qqp52d1i1jn4qndllt.jpg?s=81293f61a6")
    #expect(first.dir == "nw")
    #expect(first.year == 1890)
    #expect(first.year2 == 1895)
    // geo is [lat, lon].
    #expect(first.geo[0].isApproximatelyEqualTo(50.089992))
    #expect(first.geo[1].isApproximatelyEqualTo(14.419038))
  }

  @Test func missingDirDecodesToNil() throws {
    let photos = try #require(decodeBounds("getByBounds_photos.json").photos)
    let third = photos[2]
    #expect(third.cid == 1_856_884)
    #expect(third.dir == nil) // no "dir" key in JSON
  }

  // MARK: - Network.Cluster decoding (p/c/geo CodingKeys)

  @Test func clustersFixtureDecodes() throws {
    let result = try decodeBounds("getByBounds_clusters.json")
    #expect(result.photos?.isEmpty == true)
    #expect(result.clusters?.isEmpty == false)
  }

  @Test func firstClusterMapsPreviewAndCountKeys() throws {
    let cluster = try #require(decodeBounds("getByBounds_clusters.json").clusters?[0])
    // "c" -> count, "p" -> preview, "geo" is [lat,lon] for the cluster itself.
    #expect(cluster.count == 83)
    #expect(cluster.geo[0].isApproximatelyEqualTo(50.072674))
    #expect(cluster.geo[1].isApproximatelyEqualTo(14.443844))
    #expect(cluster.preview.cid == 2_081_180)
    // The preview's raw geo is [lon, lat] (REVERSED) as the server sends it.
    #expect(cluster.preview.geo[0].isApproximatelyEqualTo(14.444176))
    #expect(cluster.preview.geo[1].isApproximatelyEqualTo(50.072229))
  }

  // MARK: - Nullable-arrays quirk

  @Test func emptyResultFixtureHasEmptyArrays() throws {
    let result = try decodeBounds("getByBounds_empty.json")
    #expect(result.photos?.isEmpty == true)
    #expect(result.clusters?.isEmpty == true)
  }

  @Test func absentArraysDecodeToNil() throws {
    let data = Data(#"{"result":{}}"#.utf8)
    let result = try JSONDecoder().decode(RawResponse.self, from: data).result
    #expect(result.photos == nil)
    #expect(result.clusters == nil)
  }

  // MARK: - Network.ImageDetails decoding (user.disp CodingKey)

  @Test func detailsDecodesUserDispKey() throws {
    let details = try decodeDetails("imageDetails_watersign.json")
    #expect(details.cid == 1_641_494)
    #expect(details.title == "Теразије")
    #expect(details.user.name == "Николай") // via CodingKey "disp"
    #expect(details.watersignText == "uploaded by nb92")
    // The HTML <a href=...> source is kept as-is.
    #expect(details.source?.contains("<a href=") == true)
    #expect(details.geo[0].isApproximatelyEqualTo(44.813047))
    #expect(details.geo[1].isApproximatelyEqualTo(20.460579))
  }

  // MARK: - Model.Cluster mapping (reversed preview coordinate quirk)

  @Test func modelClusterReversesPreviewCoordinateOnly() throws {
    let nc = try #require(decodeBounds("getByBounds_clusters.json").clusters?[0])
    let cluster = Model.Cluster(nc: nc, image: .mock)
    // Cluster's own coordinate is NOT reversed: [lat, lon] straight through.
    #expect(cluster.coordinate.latitude.isApproximatelyEqualTo(50.072674))
    #expect(cluster.coordinate.longitude.isApproximatelyEqualTo(14.443844))
    // Preview coordinate IS reversed: server sent [lon, lat] -> reversed to (lat, lon).
    #expect(cluster.preview.coordinate.latitude.isApproximatelyEqualTo(50.072229))
    #expect(cluster.preview.coordinate.longitude.isApproximatelyEqualTo(14.444176))
  }
}
