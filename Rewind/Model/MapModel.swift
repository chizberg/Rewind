//
//  MapModel.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 03.02.2025.
//

import MapKit
import VGSL

typealias MapModel = Reducer<MapState, MapAction>

struct MapState {
  var selectedImage: Model.Image?
  var region: Region
  var previews: [Model.Image]

  var images: Set<Model.Image>
  var clusters: Set<Model.Cluster>
}

enum MapAction {
  enum External {
    enum Map {
      case regionChanged(Region)
      case annotationSelected(MKAnnotation?)
      case annotationDeselected(MKAnnotation?)
    }

    case map(Map)
    case loaded([Model.Image], [Model.Cluster])
  }

  enum Internal {
    case regionChangedThrottled(Region)
    case clearAnnotations
    case updatePreviews
  }

  case external(External)
  case `internal`(Internal)
}

func makeMapModel(
  addAnnotations: @escaping ([MKAnnotation]) -> Void,
  clearAnnotations: @escaping () -> Void,
  visibleAnnotations: Variable<[MKAnnotation]>,
  setRegion: @escaping (Region, _ animated: Bool) -> Void,
  requestAnnotations: @escaping (Region) -> Void,
  throttledAction: @escaping (MapAction) -> Void
) -> MapModel {
  MapModel(
    initial: MapState(
      region: .zero,
      previews: [],
      images: [],
      clusters: []
    ),
    reduce: { state, action, effect in
      switch action {
      case let .external(externalAction):
        switch externalAction {
        case let .map(.regionChanged(region)):
          throttledAction(.internal(.regionChangedThrottled(region)))
        case let .map(.annotationSelected(mkAnn)):
          guard let ann = mkAnn as? Annotation else { return }
          switch ann.value {
          case let .image(image): state.selectedImage = image
          case let .cluster(cluster):
            setRegion(
              Region(center: cluster.coordinate, zoom: state.region.zoom + 1),
              /*animated:*/ true
            )
          }
          break
        case .map(.annotationDeselected):
          state.selectedImage = nil
        case let .loaded(images, clusters):
          let imagesSet = Set(images)
          let clustersSet = Set(clusters)

          let newImages = imagesSet.subtracting(state.images)
          let newClusters = clustersSet.subtracting(state.clusters)

          state.images.formUnion(imagesSet)
          state.clusters.formUnion(clustersSet)

          let newAnnotations = newImages.map { Annotation(value: .image($0)) }
            + newClusters.map { Annotation(value: .cluster($0)) }

          addAnnotations(newAnnotations)
          effect(.internal(.updatePreviews))
        }
      case let .internal(internalAction):
        switch internalAction {
        case let .regionChangedThrottled(region):
          if state.region != .zero, state.region.zoom != region.zoom {
            effect(.internal(.clearAnnotations))
          }
          state.region = region
          requestAnnotations(region)
          effect(.internal(.updatePreviews))
        case .clearAnnotations:
          state.images.removeAll()
          state.clusters.removeAll()
          clearAnnotations()
          effect(.internal(.updatePreviews))
        case .updatePreviews:
          state.previews = visibleAnnotations.value.compactMap {
            guard let ann = $0 as? Annotation else { return nil }
            return switch ann.value {
            case let .image(image): image
            case let .cluster(cluster): cluster.preview
            }
          }
        }
      }
    }
  )
}

