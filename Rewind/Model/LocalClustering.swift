//
//  LocalClustering.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 16. 11. 2025..
//

import Foundation
import MapKit

import VGSL

struct ClusteringCell: Hashable {
  var latIndex: Int
  var lonIndex: Int

  var size: CLLocationDegrees
}

func groupImages(
  images: [Model.Image],
  zoom: Int
) -> [ClusteringCell: Set<Model.Image>] {
  let size = delta(zoom: zoom) / clusteringCellRatio
  return images.reduce(into: [:]) { result, image in
    let cell = ClusteringCell(
      latIndex: Int(floor(image.coordinate.latitude / size)),
      lonIndex: Int(floor(image.coordinate.longitude / size)),
      size: size
    )
    result[cell, default: []].insert(image)
  }
}

enum LocalClusteringPatch {
  case addImages(Set<Model.Image>)
  case addCluster(Model.LocalCluster, removing: Set<Model.Image>)
  case addImagesToCluster(Set<Model.Image>)
}

func makePatches(
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

func applyPatches(
  _ patches: [(ClusteringCell, LocalClusteringPatch)],
  clusteredImages: inout MapState.ClusteredImages,
  annotationsInRect: (MKMapRect) -> [MKAnnotation]
) -> (
  toAdd: [AnnotationWrapper],
  toRemove: [MKAnnotation]
) {
  var toAdd: [AnnotationWrapper] = []
  var toRemove: [MKAnnotation] = []
  for (cell, patch) in patches {
    switch patch {
    case let .addImages(newImages):
      clusteredImages[cell] = .left(
        (clusteredImages[cell]?.left ?? []).union(newImages)
      )
      toAdd.append(contentsOf: newImages.map {
        AnnotationWrapper(value: .image($0))
      })
    case let .addCluster(newLocalCluster, removing: imagesToRemove):
      clusteredImages[cell] = .right(newLocalCluster)
      toAdd.append(
        AnnotationWrapper(value: .localCluster(newLocalCluster))
      )
      let currentAnnotations = annotationsInRect(cell.rect)
      let imageAnnotationsToRemove = imagesToRemove.compactMap {
        findAnnotationToDelete(for: $0, in: currentAnnotations)
      }
      toRemove.append(contentsOf: imageAnnotationsToRemove)
    case let .addImagesToCluster(newImages):
      guard let currentCluster = clusteredImages[cell]?.right else {
        assertionFailure("expected local cluster")
        continue
      }
      let newLocalCluster = modified(currentCluster) {
        $0.images.append(contentsOf: newImages)
        $0.id = UUID()
      }
      clusteredImages[cell] = .right(newLocalCluster)
      toAdd.append(AnnotationWrapper(value: .localCluster(newLocalCluster)))
      let currentAnnotations = annotationsInRect(cell.rect)
      let oldAnnotationToRemove = currentAnnotations.first { ann in
        if let wrapper = ann as? AnnotationWrapper,
           case let .localCluster(localCluster) = wrapper.value {
          return localCluster == currentCluster
        }
        return false
      }
      if let oldAnnotationToRemove {
        toRemove.append(oldAnnotationToRemove)
      }
    }
  }
  return (toAdd, toRemove)
}

private func findAnnotationToDelete(
  for image: Model.Image,
  in annotations: [MKAnnotation]
) -> MKAnnotation? {
  func isGoal(_ ann: MKAnnotation) -> Bool {
    if let wrapper = ann as? AnnotationWrapper,
       case let .image(imageValue) = wrapper.value,
       imageValue == image {
      return true
    }
    return false
  }
  for ann in annotations {
    if isGoal(ann) { return ann }
    if let mkCluster = ann as? MKClusterAnnotation {
      for member in mkCluster.memberAnnotations where isGoal(member) {
        return member
      }
    }
  }
  return nil
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
