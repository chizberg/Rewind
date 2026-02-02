//
//  LocalClustering.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 16. 11. 2025.
//

import Foundation
import MapKit

import VGSL

struct ClusteringCell: Hashable {
  var latIndex: Int
  var lonIndex: Int

  var size: CLLocationDegrees
}

func makeDiffAfterReceived(
  images: [Model.Image],
  clusters: [Model.Cluster],
  params: AnnotationLoadingParams,
  mapSize: CGSize,
  state: inout MapState
) -> (
  toAdd: [AnnotationValue],
  toRemove: [AnnotationValue]
) {
  let shouldClearOldAnnotations = if let lastParams = state.lastLoadedParams {
    lastParams.zoom != params.zoom
      || lastParams.yearRange != params.yearRange
  } else {
    false
  }
  var toAdd = [AnnotationValue]()
  var toRemove = [AnnotationValue]()

  // clusters:
  // if shouldClearOldAnnotations, replace all clusters with new ones
  // otherwise, just add new clusters
  let receivedClusters = Set(clusters)
  let newClusters = receivedClusters.subtracting(state.clusters)
  if shouldClearOldAnnotations {
    let clustersToRemove = state.clusters
    toRemove += clustersToRemove.map { .cluster($0) }
    state.clusters = receivedClusters
    toAdd += receivedClusters.map { .cluster($0) }
  } else {
    state.clusters.formUnion(newClusters)
    toAdd += newClusters.map { .cluster($0) }
  }

  // clustered images:
  // if shouldClearOldAnnotations, remove all local clusters
  // remove all images that are not in the received set
  // group old images that are still present with new images
  // then add new ones to these groups
  let receivedImages = Set(images)
  if shouldClearOldAnnotations {
    var freeImages = Set<Model.Image>()
    for cellValue in state.clusteredImages.values {
      switch cellValue {
      case let .left(images):
        freeImages.formUnion(images)
      case let .right(localCluster):
        toRemove.append(.localCluster(localCluster))
      }
    }
    let staleImages = freeImages.subtracting(receivedImages)
    toRemove += staleImages.map { .image($0) }
    state.clusteredImages = groupImages(
      images: freeImages.intersection(receivedImages),
      zoom: params.zoom,
      mapSize: mapSize
    ).map(key: { $0 }, value: { .left($0) })
  }

  let groupedImages = groupImages(
    images: receivedImages,
    zoom: params.zoom,
    mapSize: mapSize
  )
  let patches = makePatches(
    newImages: groupedImages,
    current: state.clusteredImages
  )
  applyPatches(
    patches,
    clusteredImages: &state.clusteredImages,
    toAdd: &toAdd,
    toRemove: &toRemove
  )
  return (toAdd, toRemove)
}

private func groupImages(
  images: any Sequence<Model.Image>,
  zoom: Int,
  mapSize: CGSize
) -> [ClusteringCell: Set<Model.Image>] {
  let size = delta(zoom: zoom, mapSize: mapSize) / clusteringCellRatio
  return images.reduce(into: [:]) { result, image in
    let cell = ClusteringCell(
      latIndex: Int(floor(image.coordinate.latitude / size)),
      lonIndex: Int(floor(image.coordinate.longitude / size)),
      size: size
    )
    result[cell, default: []].insert(image)
  }
}

private enum LocalClusteringPatch {
  case addImages(Set<Model.Image>)
  case addCluster(Model.LocalCluster, removing: Set<Model.Image>)
  case addImagesToCluster(Set<Model.Image>)
}

private func makePatches(
  newImages: [ClusteringCell: Set<Model.Image>],
  current: MapState.ClusteredImages
) -> [(ClusteringCell, LocalClusteringPatch)] {
  newImages.compactMap { cell, newImagesForCell in
    if let patch = makePatch(
      cell: cell,
      newImages: newImagesForCell,
      current: current[cell]
    ) {
      (cell, patch)
    } else {
      nil
    }
  }
}

private func applyPatches(
  _ patches: [(ClusteringCell, LocalClusteringPatch)],
  clusteredImages: inout MapState.ClusteredImages,
  toAdd: inout [AnnotationValue],
  toRemove: inout [AnnotationValue]
) {
  for (cell, patch) in patches {
    switch patch {
    case let .addImages(newImages):
      clusteredImages[cell] = .left(
        (clusteredImages[cell]?.left ?? []).union(newImages)
      )
      toAdd.append(contentsOf: newImages.map { .image($0) })
    case let .addCluster(newLocalCluster, removing: imagesToRemove):
      clusteredImages[cell] = .right(newLocalCluster)
      toAdd.append(.localCluster(newLocalCluster))
      toRemove.append(contentsOf: imagesToRemove.map { .image($0) })
    case let .addImagesToCluster(newImages):
      guard let cluster = clusteredImages[cell]?.right else {
        assertionFailure("expected local cluster")
        continue
      }
      let newLocalCluster = modified(cluster) {
        $0.images.append(contentsOf: newImages)
        $0.id = UUID()
      }
      clusteredImages[cell] = .right(newLocalCluster)
      toAdd.append(.localCluster(newLocalCluster))
      toRemove.append(.localCluster(cluster))
    }
  }
}

private func makePatch(
  cell: ClusteringCell,
  newImages: Set<Model.Image>,
  current: Either<Set<Model.Image>, Model.LocalCluster>?
) -> LocalClusteringPatch? {
  guard let current else {
    if newImages.count < localClusterMinCount {
      return .addImages(newImages)
    } else {
      return .addCluster(
        Model.LocalCluster(images: newImages, cell: cell),
        removing: []
      )
    }
  }
  switch current {
  case let .left(existingImages):
    let imagesToAdd = newImages.subtracting(existingImages)
    if imagesToAdd.isEmpty {
      return nil
    } else if existingImages.count + imagesToAdd.count < localClusterMinCount {
      return .addImages(imagesToAdd)
    } else {
      return .addCluster(
        Model.LocalCluster(
          images: existingImages.union(imagesToAdd),
          cell: cell
        ),
        removing: existingImages
      )
    }
  case let .right(existingLocalCluster):
    let imagesToAdd = newImages.subtracting(existingLocalCluster.images)
    if imagesToAdd.isEmpty {
      return nil
    } else {
      return .addImagesToCluster(imagesToAdd)
    }
  }
}

extension Model.LocalCluster {
  fileprivate init(
    images: Set<Model.Image>,
    cell: ClusteringCell
  ) {
    self.init(
      images: Array(images),
      coordinate: cell.coordinate
    )
  }
}

extension ClusteringCell {
  fileprivate var coordinate: Coordinate {
    Coordinate(
      latitude: Double(latIndex) * size + size / 2,
      longitude: Double(lonIndex) * size + size / 2
    )
  }

  fileprivate var rect: MKMapRect {
    MKMapRect(
      origin: MKMapPoint(
        x: Double(lonIndex) * size,
        y: Double(latIndex) * size
      ),
      size: MKMapSize(
        width: size,
        height: size
      )
    )
  }
}

private let localClusterMinCount = 5
private let clusteringCellRatio: Double = 8
