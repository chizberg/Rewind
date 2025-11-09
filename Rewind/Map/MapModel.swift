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
  var location: CLLocation?

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
      case mapViewLoaded
      case locationButtonTapped
      case yearRangeChanged(ClosedRange<Int>)
      case mapTypeSelected(MapType)
    }

    case map(Map)
    case ui(UI)
    case previewClosed
    case locationChanged(CLLocation?)
  }

  enum Internal {
    case regionChanged(Region)
    case loadAnnotations
    case loaded([Model.Image], [Model.Cluster])
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
  annotationsRemote: Remote<(Region, ClosedRange<Int>), ([Model.Image], [Model.Cluster])>,
  applyMapType: @escaping (MapType) -> Void,
  performAppAction: @escaping (AppAction) -> Void,
  startLocationUpdating: @escaping () -> Void
) -> MapModel {
  MapModel(
    initial: MapState(
      mapType: .standard,
      region: .zero,
      yearRange: 1826...2000,
      previews: [],
      location: nil,
      images: [],
      clusters: []
    ),
    reduce: { state, action, enqueueEffect in
      switch action {
      case let .external(externalAction):
        switch externalAction {
        case let .map(.regionChanged(region)):
          enqueueEffect(.throttled(id: .regionChanged) { anotherAction in
            await anotherAction(.internal(.regionChanged(region)))
          })
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
            performAppAction(.openImageList(images, source: "local cluster"))
          }
        case .map(.annotationDeselected): break
        case .ui(.mapViewLoaded):
          startLocationUpdating()
        case let .ui(.yearRangeChanged(yearRange)):
          state.yearRange = yearRange
          enqueueEffect(.throttled(id: .clearAnnotations) { anotherAction in
            await anotherAction(.internal(.clearAnnotations))
          })
          enqueueEffect(.throttled(id: .loadAnnotations) { anotherAction in
            await anotherAction(.internal(.loadAnnotations))
          })
        case let .ui(.mapTypeSelected(mapType)):
          state.mapType = mapType
          applyMapType(mapType)
        case .ui(.locationButtonTapped):
          if let location = state.location {
            setRegion(
              Region(center: location.coordinate, zoom: 15),
              /* animated */ true
            )
          } // TODO: do something here
        case .previewClosed:
          deselectAnnotations()
        case let .locationChanged(location):
          if let location, state.location == nil {
            setRegion(
              Region(center: location.coordinate, zoom: 15),
              /* animated */ false
            )
          }
          if let location {
            state.location = location
          }
        }
      case let .internal(internalAction):
        switch internalAction {
        case let .regionChanged(region):
          if state.region != .zero, state.region.zoom != region.zoom {
            enqueueEffect(.regular { anotherAction in
              await anotherAction(.internal(.clearAnnotations))
            })
          }
          state.region = region
          enqueueEffect(.regular { anotherAction in
            await anotherAction(.internal(.loadAnnotations))
          })
          enqueueEffect(.throttled(id: .updatePreviews) { anotherAction in
            await anotherAction(.internal(.updatePreviews))
          })
        case .loadAnnotations:
          let params = (state.region, state.yearRange)
          enqueueEffect(.regular { anotherAction in
            let (images, clusters) = try await annotationsRemote(params)
            await anotherAction(.internal(.loaded(images, clusters)))
          })
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
          enqueueEffect(.throttled(id: .updatePreviews) { anotherAction in
            await anotherAction(.internal(.updatePreviews))
          })
        case .clearAnnotations:
          state.images.removeAll()
          state.clusters.removeAll()
          clearAnnotations()
          enqueueEffect(.throttled(id: .updatePreviews) { anotherAction in
            await anotherAction(.internal(.updatePreviews))
          })
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
