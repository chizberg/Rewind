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
  var currentRegionImages: [Model.Image]
  var previews: [Model.Image]
  var locationState: LocationState

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
    case newLocationState(LocationState)
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
  mapAdapter: MapAdapter,
  annotationsRemote: Remote<(Region, ClosedRange<Int>), ([Model.Image], [Model.Cluster])>,
  applyMapType: @escaping (MapType) -> Void,
  performAppAction: @escaping (AppAction) -> Void,
  locationModel: LocationModel,
  urlOpener: @escaping UrlOpener
) -> MapModel {
  MapModel(
    initial: MapState(
      mapType: .standard,
      region: .zero,
      yearRange: 1826...2000,
      currentRegionImages: [],
      previews: [],
      locationState: locationModel.state,
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
              performAppAction(.imageDetails(.present(image, source: "annotation")))
            case let .cluster(cluster):
              mapAdapter.set(
                region: Region(center: cluster.coordinate, zoom: state.region.zoom + 1),
                animated: true
              )
            }
          } else if let localCluster = mkAnn as? MKClusterAnnotation {
            let images = localCluster.memberAnnotations.compactMap {
              ($0 as? AnnotationWrapper)?.value.image
            }
            performAppAction(
              .imageList(
                .present(images, source: "local cluster", title: "Cluster")
              )
            )
          }
        case .map(.annotationDeselected): break
        case .ui(.mapViewLoaded):
          locationModel(.requestAccess)
          locationModel(.tryStartUpdatingLocation)
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
          if let location = state.locationState.location {
            mapAdapter.set(
              region: Region(center: location.coordinate, zoom: 15),
              animated: true
            )
          } else if state.locationState.isAccessGranted == false {
            performAppAction(.alert(.present(.locationAccessDenied {
              if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                urlOpener(settingsURL)
              }
            })))
          } else {
            performAppAction(.alert(.present(.unableToDetermineLocation)))
          }
        case .previewClosed:
          mapAdapter.deselectAnnotations()
        case let .newLocationState(locationState):
          if let location = locationState.location, state.locationState.location == nil {
            mapAdapter.set(
              region: Region(center: location.coordinate, zoom: 15),
              animated: false
            )
          }
          state.locationState = modified(locationState) {
            $0.location = $0.location ?? state.locationState.location
          }
        }
      case let .internal(internalAction):
        switch internalAction {
        case let .regionChanged(region):
          if state.region != .zero, state.region.zoom != region.zoom {
            enqueueEffect(.anotherAction(.internal(.clearAnnotations)))
          }
          state.region = region
          enqueueEffect(.anotherAction(.internal(.loadAnnotations)))
          enqueueEffect(.throttled(id: .updatePreviews) { anotherAction in
            await anotherAction(.internal(.updatePreviews))
          })
        case .loadAnnotations:
          let params = (state.region, state.yearRange)
          enqueueEffect(.perform(id: EffectID.loadAnnotations) { anotherAction in
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

          mapAdapter.add(annotations: newAnnotations)
          enqueueEffect(.throttled(id: .updatePreviews) { anotherAction in
            await anotherAction(.internal(.updatePreviews))
          })
        case .clearAnnotations:
          state.images.removeAll()
          state.clusters.removeAll()
          mapAdapter.clear()
          enqueueEffect(.cancel(id: EffectID.loadAnnotations))
          enqueueEffect(.throttled(id: .updatePreviews) { anotherAction in
            await anotherAction(.internal(.updatePreviews))
          })
        case .updatePreviews:
          let visible: [Model.Image] = mapAdapter.visibleAnnotations.flatMap {
            if let cluster = $0 as? MKClusterAnnotation {
              return cluster.memberAnnotations
            }
            return [$0]
          }.compactMap {
            guard let ann = $0 as? AnnotationWrapper else { return nil }
            return switch ann.value {
            case let .image(image): image
            case let .cluster(cluster): cluster.preview
            }
          }
          state.currentRegionImages = Array(Set(visible))
          state.previews = Array(state.currentRegionImages.prefix(10))
        }
      }
    }
  )
}

private enum EffectID {
  static let loadAnnotations = "load_annotations"
}

extension AlertParams {
  fileprivate static func locationAccessDenied(
    openSettings: @escaping Action
  ) -> AlertParams {
    AlertParams(
      title: "The app has no access to your location",
      message: "You can change it in Settings.\nGo to Apps -> Rewind -> Location -> While Using the App",
      actions: [
        .init(title: "Go to Settings", handler: openSettings),
        .init(title: "OK"),
      ]
    )
  }

  fileprivate static var unableToDetermineLocation: AlertParams {
    AlertParams(
      title: "Unable to Determine Location",
      message: "Please try again later",
      actions: [
        .init(title: "OK"),
      ]
    )
  }
}
