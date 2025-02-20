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
  var mapType: MapType
  var region: Region
  var yearRange: ClosedRange<Int>
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

    enum UI {
      case yearRangeChanged(ClosedRange<Int>)
      case mapTypeSelected(MapType)
      case thumbnailSelected(Model.Image)
    }

    case map(Map)
    case ui(UI)
    case loaded([Model.Image], [Model.Cluster])
    case previewClosed
  }

  enum Internal {
    case regionChanged(Region)
    case loadAnnotations
    case clearAnnotations
    case updatePreviews
  }

  case external(External)
  case `internal`(Internal)
}

func makeMapModel(
  addAnnotations: @escaping ([MKAnnotation]) -> Void,
  clearAnnotations: @escaping () -> Void,
  deselectAnnotations: @escaping () -> Void,
  visibleAnnotations: Variable<[MKAnnotation]>,
  setRegion: @escaping (Region, _ animated: Bool) -> Void,
  requestAnnotations: @escaping (Region, ClosedRange<Int>) -> Void,
  applyMapType: @escaping (MapType) -> Void,
  performAppAction: @escaping (AppAction) -> Void,
  throttle: @escaping (MapAction) -> Void
) -> MapModel {
  MapModel(
    initial: MapState(
      mapType: .standard,
      region: .zero,
      yearRange: 1826...2000,
      previews: [],
      images: [],
      clusters: []
    ),
    reduce: { state, action, effect, _ in
      switch action {
      case let .external(externalAction):
        switch externalAction {
        case let .map(.regionChanged(region)):
          throttle(.internal(.regionChanged(region)))
        case let .map(.annotationSelected(mkAnn)):
          if let ann = mkAnn as? AnnotationWrapper {
            switch ann.value {
            case let .image(image):
              performAppAction(.previewImage(image))
            case let .cluster(cluster):
              setRegion(
                Region(center: cluster.coordinate, zoom: state.region.zoom + 1),
                /* animated: */ true
              )
            }
          } else if let localCluster = mkAnn as? MKClusterAnnotation {
            let images = localCluster.memberAnnotations.compactMap {
              ($0 as? AnnotationWrapper)?.value.image
            }
            performAppAction(.previewList(images))
          }
        case .map(.annotationDeselected): break
        case let .ui(.thumbnailSelected(image)):
          performAppAction(.previewImage(image))
        case let .ui(.yearRangeChanged(yearRange)):
          state.yearRange = yearRange
          throttle(.internal(.clearAnnotations))
          throttle(.internal(.loadAnnotations))
        case let .ui(.mapTypeSelected(mapType)):
          state.mapType = mapType
          applyMapType(mapType)
        case let .loaded(images, clusters):
          let imagesSet = Set(images)
          let clustersSet = Set(clusters)

          let newImages = imagesSet.subtracting(state.images)
          let newClusters = clustersSet.subtracting(state.clusters)

          state.images.formUnion(imagesSet)
          state.clusters.formUnion(clustersSet)

          let newAnnotations = newImages.map { AnnotationWrapper(value: .image($0)) }
            + newClusters.map { AnnotationWrapper(value: .cluster($0)) }

          addAnnotations(newAnnotations)
          throttle(.internal(.updatePreviews))
        case .previewClosed:
          deselectAnnotations()
        }
      case let .internal(internalAction):
        switch internalAction {
        case let .regionChanged(region):
          if state.region != .zero, state.region.zoom != region.zoom {
            effect(.internal(.clearAnnotations))
          }
          state.region = region
          effect(.internal(.loadAnnotations))
          throttle(.internal(.updatePreviews))
        case .loadAnnotations:
          requestAnnotations(state.region, state.yearRange)
        case .clearAnnotations:
          state.images.removeAll()
          state.clusters.removeAll()
          clearAnnotations()
          throttle(.internal(.updatePreviews))
        case .updatePreviews:
          let visible: [Model.Image] = visibleAnnotations.value.flatMap {
            if let cluster = $0 as? MKClusterAnnotation {
              return cluster.memberAnnotations
            }
            return [$0]
          }.prefix(10).compactMap {
            guard let ann = $0 as? AnnotationWrapper else { return nil }
            return switch ann.value {
            case let .image(image): image
            case let .cluster(cluster): cluster.preview
            }
          }
          state.previews = Array(Set(visible))
        }
      }
    }
  )
}
