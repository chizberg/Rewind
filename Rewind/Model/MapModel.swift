//
//  MapModel.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 03.02.2025.
//

import MapKit
import VGSL

typealias MapModel = Reducer<MapState, MapAction>
typealias MapViewModel = Reducer<MapState, MapAction.External.UI>

struct MapState {
  typealias ClusteredImages = [ClusteringCell: Either<Set<Model.Image>, Model.LocalCluster>]
  var mapType: MapType
  var region: Region
  var yearRange: ClosedRange<Int>
  var currentRegionImages: [Model.Image]
  var previews: [ThumbnailCard]
  var locationState: LocationState
  var isLoading: Bool

  fileprivate var clusters: Set<Model.Cluster>
  fileprivate var clusteredImages: ClusteredImages
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
    case focusOn(Coordinate)
    case newLocationState(LocationState)
  }

  enum Internal {
    case regionChanged(Region)
    case loadAnnotations
    case loadingFailed(Error)
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
  urlOpener: @escaping UrlOpener,
  settings: Variable<SettingsState>
) -> MapModel {
  MapModel(
    initial: MapState(
      mapType: .standard,
      region: .zero,
      yearRange: 1826...2000,
      currentRegionImages: [],
      previews: [],
      locationState: locationModel.state,
      isLoading: false,
      clusters: [],
      clusteredImages: [:]
    ),
    reduce: { state, action, enqueueEffect in
      switch action {
      case let .external(externalAction):
        switch externalAction {
        case let .map(map):
          switch map {
          case let .regionChanged(region):
            enqueueEffect(.debounced(id: .regionChanged) { anotherAction in
              await anotherAction(.internal(.regionChanged(region)))
            })
          case let .annotationSelected(mkAnn):
            var listToPresent: [Model.Image] = []
            if let ann = mkAnn as? AnnotationWrapper {
              switch ann.value {
              case let .image(image):
                performAppAction(.imageDetails(.present(image, source: "annotation")))
              case let .cluster(cluster):
                if settings.value.openClusterPreviews {
                  performAppAction(.imageDetails(.present(cluster.preview, source: "annotation")))
                } else {
                  mapAdapter.set(
                    region: Region(center: cluster.coordinate, zoom: state.region.zoom + 1),
                    animated: true
                  )
                }
              case let .localCluster(localCluster):
                listToPresent = localCluster.images
              }
            } else if let mkCluster = mkAnn as? MKClusterAnnotation {
              listToPresent = mkCluster.memberAnnotations.compactMap { ann in
                if let wrapper = ann as? AnnotationWrapper,
                   case let .image(image) = wrapper.value {
                  return image
                }
                return nil
              }
            }
            if !listToPresent.isEmpty {
              performAppAction(
                .imageList(
                  .present(listToPresent, source: "local cluster", title: "Cluster")
                )
              )
            }
          case .annotationDeselected:
            break
          }
        case let .ui(ui):
          switch ui {
          case .mapViewLoaded:
            locationModel(.requestAccess)
            locationModel(.tryStartUpdatingLocation)
          case let .yearRangeChanged(yearRange):
            state.yearRange = yearRange
            enqueueEffect(.debounced(id: .yearRangeChanged) { anotherAction in
              await anotherAction(.internal(.clearAnnotations))
              await anotherAction(.internal(.loadAnnotations))
            })
          case let .mapTypeSelected(mapType):
            state.mapType = mapType
            applyMapType(mapType)
          case .locationButtonTapped:
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
          }
        case .previewClosed:
          mapAdapter.deselectAnnotations()
        case let .focusOn(coordinate):
          mapAdapter.set(
            region: Region(center: coordinate, zoom: 17),
            animated: true
          )
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
          enqueueEffect(.debounced(id: .updatePreviews) { anotherAction in
            await anotherAction(.internal(.updatePreviews))
          })
        case .loadAnnotations:
          state.isLoading = true
          let params = (state.region, state.yearRange)
          enqueueEffect(.perform(id: EffectID.loadAnnotations) { anotherAction in
            do {
              let (images, clusters) = try await annotationsRemote.load(params)
              await anotherAction(.internal(.loaded(images, clusters)))
            } catch {
              await anotherAction(.internal(.loadingFailed(error)))
            }
          })
        case let .loadingFailed(error):
          state.isLoading = false
          performAppAction(.alert(.present(.error(
            title: "Unable to load map annotations",
            error: error
          ))))
        case let .loaded(images, clusters):
          state.isLoading = false
          let clustersSet = Set(clusters)
          let newClusters = clustersSet.subtracting(state.clusters)
          state.clusters.formUnion(clustersSet)
          let newClusterAnnotations = newClusters.map {
            AnnotationWrapper(value: .cluster($0))
          }

          let groupedImages = groupImages(
            images: images,
            zoom: state.region.zoom
          )
          let patches = makePatches(
            newImages: groupedImages,
            current: state.clusteredImages
          )

          let (clusteredImagesToAdd, clusteredImagesToRemove) = applyPatches(
            patches,
            clusteredImages: &state.clusteredImages,
            annotationsInRect: { mapAdapter.annotations(in: $0) }
          )

          mapAdapter.remove(annotations: clusteredImagesToRemove)
          mapAdapter.add(annotations: clusteredImagesToAdd + newClusterAnnotations)
          enqueueEffect(.debounced(id: .updatePreviews) { anotherAction in
            await anotherAction(.internal(.updatePreviews))
          })
        case .clearAnnotations:
          state.clusteredImages.removeAll()
          state.clusters.removeAll()
          mapAdapter.clear()
          enqueueEffect(.cancel(id: EffectID.loadAnnotations))
          enqueueEffect(.debounced(id: .updatePreviews) { anotherAction in
            await anotherAction(.internal(.updatePreviews))
          })
        case .updatePreviews:
          guard !state.isLoading else { return }
          let annotations = mapAdapter.visibleAnnotations.flatMap {
            if let cluster = $0 as? MKClusterAnnotation {
              return cluster.memberAnnotations
            }
            return [$0]
          }
          let modelValues = annotations.flatMap { (ann: MKAnnotation) -> [Model.Image] in
            guard let wrapper = ann as? AnnotationWrapper else { return [] }
            return switch wrapper.value {
            case let .image(image): [image]
            case let .cluster(cluster): [cluster.preview]
            case let .localCluster(localCluster): Array(localCluster.images)
            }
          }
          state.currentRegionImages = Array(Set(modelValues))
          state.previews = makePreviews(images: state.currentRegionImages, limit: 10)
        }
      }
    }
  )
}

private func makePreviews(
  images: [Model.Image],
  limit: Int
) -> [ThumbnailCard] {
  if images.isEmpty {
    [.noImages]
  } else if images.count > limit {
    images.prefix(limit).map { .image($0) } + [.viewAsList]
  } else {
    images.map { .image($0) }
  }
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
