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
  var lastLoadedParams: AnnotationLoadingParams?

  var clusters: Set<Model.Cluster>
  var clusteredImages: ClusteredImages
}

enum MapAction {
  enum External {
    enum Map {
      case regionChanged(Region)
      case annotationSelected(MKAnnotation?)
      case annotationDeselected(MKAnnotation?)
      case userDragged(CGPoint, CGRect)
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
    case focusOn(Coordinate, zoom: Int)
    case newLocationState(LocationState)
  }

  enum Internal {
    case regionChanged(Region)
    case loadAnnotations
    case loadingFailed(Error)
    case loaded(AnnotationLoadingParams, [Model.Image], [Model.Cluster])
    case updatePreviews
    case unfoldMapControlsBack
    case clearAnnotations
  }

  case external(External)
  case `internal`(Internal)
}

func makeMapModel(
  mapAdapter: MapAdapter,
  annotationsRemote: Remote<AnnotationLoadingParams, ([Model.Image], [Model.Cluster])>,
  applyMapType: @escaping (MapType) -> Void,
  performAppAction: @escaping (AppAction) -> Void,
  locationModel: LocationModel,
  urlOpener: @escaping UrlOpener,
  settings: Variable<SettingsState>,
  appState: Variable<AppState?>,
  annotationStore: AnnotationStore,
  sorting: Variable<ImageSorting>
) -> MapModel {
  MapModel(
    initial: .makeInitial(locationState: locationModel.state),
    reduce: { state, action, enqueueEffect in
      switch action {
      case let .external(externalAction):
        switch externalAction {
        case let .map(map):
          switch map {
          case let .regionChanged(region):
            enqueueEffect(.debounced(
              id: .regionChanged,
              anotherAction: .internal(.regionChanged(region))
            ))
          case let .annotationSelected(mkAnn):
            var listToPresent: [Model.Image] = []
            if let imageAnn = mkAnn as? Annotation<Model.Image> {
              performAppAction(.imageDetails(.present(imageAnn.value, source: "annotation")))
            } else if let clusterAnn = mkAnn as? Annotation<Model.Cluster> {
              let cluster = clusterAnn.value
              if settings.value.openClusterPreviews {
                performAppAction(.imageDetails(.present(cluster.preview, source: "annotation")))
              } else {
                let mapSize = mapAdapter.size
                let currentZoom = Rewind.zoom(region: state.region, mapSize: mapSize)
                mapAdapter.set(
                  region: Region(
                    center: cluster.coordinate,
                    zoom: currentZoom + 1,
                    mapSize: mapSize
                  ),
                  animated: true
                )
              }
            } else if let localClusterAnn = mkAnn as? Annotation<Model.LocalCluster> {
              listToPresent = localClusterAnn.value.images
            } else if let mkCluster = mkAnn as? MKClusterAnnotation {
              listToPresent = mkCluster.memberAnnotations.compactMap { ann in
                if let imageAnn = ann as? Annotation<Model.Image> {
                  return imageAnn.value
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
          case let .userDragged(touchPosition, mapFrame):
            guard let minimizationState = appState.value?.mapControls.minimization,
                  !minimizationState.isMinimizedByUser else {
              enqueueEffect(.cancel(debouncedAction: .unfoldControlsBack))
              return
            }
            if touchPosition.y > mapFrame.height - MapControls.blockingHeight {
              performAppAction(.mapControls(.setMinimization(.minimized(byUser: false))))
              enqueueEffect(.debounced(
                id: .unfoldControlsBack,
                anotherAction: .internal(.unfoldMapControlsBack)
              ))
            }
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
                region: Region(center: location.coordinate, zoom: 17, mapSize: mapAdapter.size),
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
        case let .focusOn(coordinate, zoom):
          mapAdapter.set(
            region: Region(center: coordinate, zoom: zoom, mapSize: mapAdapter.size),
            animated: true
          )
        case let .newLocationState(locationState):
          if let location = locationState.location, state.locationState.location == nil {
            mapAdapter.set(
              region: Region(center: location.coordinate, zoom: 15, mapSize: mapAdapter.size),
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
          state.region = region
          enqueueEffect(.anotherAction(.internal(.loadAnnotations)))
          enqueueEffect(.debounced(
            id: .updatePreviews,
            anotherAction: .internal(.updatePreviews)
          ))
        case .loadAnnotations:
          state.isLoading = true
          let params = AnnotationLoadingParams(
            region: state.region,
            yearRange: state.yearRange,
            mapSize: mapAdapter.size
          )
          enqueueEffect(.perform(id: EffectID.loadAnnotations) { anotherAction in
            do {
              let (images, clusters) = try await annotationsRemote.load(params)
              await anotherAction(.internal(.loaded(params, images, clusters)))
            } catch {
              await anotherAction(.internal(.loadingFailed(error)))
            }
          })
        case let .loadingFailed(error):
          state.isLoading = false
          performAppAction(.alert(.present(.nonCancelledError(
            title: "Unable to load map annotations",
            error: error
          ))))
        case let .loaded(params, images, clusters):
          let (toAdd, toRemove) = makeDiffAfterReceived(
            images: images,
            clusters: clusters,
            params: params,
            mapSize: mapAdapter.size,
            state: &state
          )
          state.isLoading = false
          state.lastLoadedParams = params

          enqueueEffect(.perform { anotherAction in
            var annsToAdd: [MKAnnotation] = []
            for key in toAdd {
              let ann = await annotationStore.create(key: key)
              annsToAdd.append(ann as MKAnnotation)
            }

            var annsToRemove: [MKAnnotation] = []
            for key in toRemove {
              if let ann = await annotationStore.existing(key: key) {
                annsToRemove.append(ann as MKAnnotation)
              }
            }

            await mapAdapter.remove(annotations: annsToRemove)
            mapAdapter.add(annotations: annsToAdd)
            await annotationStore.refresh()
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
            if let imageAnn = ann as? Annotation<Model.Image> {
              return [imageAnn.value]
            } else if let clusterAnn = ann as? Annotation<Model.Cluster> {
              return [clusterAnn.value.preview]
            } else if let localClusterAnn = ann as? Annotation<Model.LocalCluster> {
              return localClusterAnn.value.images
            } else if ann is MKUserLocation {
              return []
            } else {
              assertionFailure("unexpected annotation type")
              return []
            }
          }
          state.currentRegionImages = Array(Set(modelValues)).sorted(by: sorting.value)
          state.previews = makePreviews(images: state.currentRegionImages, limit: 10)
        case .unfoldMapControlsBack:
          performAppAction(.mapControls(.setMinimization(.normal)))
        case .clearAnnotations:
          mapAdapter.clear()
          enqueueEffect(.perform { anotherAction in
            await annotationStore.clear()
            await anotherAction(.internal(.updatePreviews))
          })
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

extension MapState {
  fileprivate static func makeInitial(
    locationState: LocationState
  ) -> MapState {
    MapState(
      mapType: .standard,
      region: .zero,
      yearRange: 1826...2000,
      currentRegionImages: [],
      previews: [],
      locationState: locationState,
      isLoading: false,
      lastLoadedParams: nil,
      clusters: [],
      clusteredImages: [:]
    )
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

#if DEBUG
extension MapModel {
  static func makeMock(
    stateTransform: (inout MapState) -> Void = { _ in }
  ) -> MapModel {
    let initialState = MapState.makeInitial(
      locationState: LocationState(
        isAccessGranted: false
      )
    )
    return MapModel(
      initial: modified(initialState, stateTransform),
      reduce: { _, _, _ in }
    )
  }
}
#endif
