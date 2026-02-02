//
//  SearchModel.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 3. 12. 2025.
//

import Foundation
import MapKit

import VGSL

typealias SearchModel = Reducer<SearchState, SearchAction>
typealias SearchViewStore = ViewStore<SearchState, SearchAction.External>

struct SearchState {
  struct Suggest: Identifiable, Hashable {
    var title: String
    var subtitle: String
    var id = UUID()
  }

  var query: String
  var suggests: [Suggest]
  var alertModel: Identified<AlertParams>?
}

enum SearchAction {
  enum External {
    case updateQuery(String)
    case suggestSelected(SearchState.Suggest)
    case addSuggestToQuery(SearchState.Suggest)
    case submit
    case dismissAlert
  }

  enum Internal {
    case suggestsUpdated([MKLocalSearchCompletion])
    case suggestsFailed(Error)
    case performSearch(String)
    case searchResponseReceived(MKLocalSearch.Response)
    case searchError(Error)
    case nothingFound
  }

  case external(External)
  case `internal`(Internal)
}

func makeSearchModel(
  onLocationFound: @escaping (CLLocation) -> Void
) -> SearchModel {
  let suggestProvider = SearchSuggestProvider()
  return SearchModel(
    initial: SearchState(
      query: "",
      suggests: []
    ),
    reduce: { state, action, enqueueEffect in
      switch action {
      case let .external(external):
        switch external {
        case let .updateQuery(query):
          state.query = query
          suggestProvider.query = query
        case let .suggestSelected(suggest):
          enqueueEffect(.anotherAction(
            .internal(.performSearch(suggest.query))
          ))
        case let .addSuggestToQuery(suggest):
          state.query = suggest.query
        case .submit:
          enqueueEffect(.anotherAction(
            .internal(.performSearch(state.query))
          ))
        case .dismissAlert:
          state.alertModel = nil
        }
      case let .internal(internalAction):
        switch internalAction {
        case let .suggestsUpdated(results):
          state.suggests = results.map {
            SearchState.Suggest(title: $0.title, subtitle: $0.subtitle)
          }
        case let .suggestsFailed(error):
          state.alertModel = Identified(value: .error(
            title: "Unable to load suggests for this query",
            error: error
          ))
        case let .performSearch(query):
          enqueueEffect(.perform { anotherAction in
            do {
              let request = MKLocalSearch.Request()
              request.naturalLanguageQuery = query
              let search = MKLocalSearch(request: request)
              let result = try await search.start()
              await anotherAction(
                .internal(.searchResponseReceived(result))
              )
            } catch {
              await anotherAction(.internal(.searchError(error)))
            }
          })
        case let .searchResponseReceived(response):
          guard let mapItem = response.mapItems.first,
                let location = mapItem.getLocation()
          else {
            enqueueEffect(.anotherAction(.internal(.nothingFound)))
            return
          }
          onLocationFound(location)
        case let .searchError(error):
          if let mkError = error as? MKError,
             mkError.code == .placemarkNotFound {
            enqueueEffect(.anotherAction(.internal(.nothingFound)))
            return
          }
          state.alertModel = Identified(value: .error(
            title: "Something went wrong during the search",
            error: error
          ))
        case .nothingFound:
          state.alertModel = Identified(value: .info(
            title: "Unable to find what you're looking for",
            message: "Try to change the search query and try again"
          ))
        }
      }
    }
  ).adding(
    signal: suggestProvider.signal,
    makeAction: { event in
      switch event {
      case let .didUpdateResults(results): .internal(.suggestsUpdated(results))
      case let .didFail(error): .internal(.suggestsFailed(error))
      }
    }
  )
}

private final class SearchSuggestProvider: NSObject, MKLocalSearchCompleterDelegate {
  var query: String = "" {
    didSet {
      if !query.isEmpty, query != oldValue {
        completer.queryFragment = query
      }
    }
  }

  var signal: Signal<SearchSuggestEvent> {
    pipe.signal
  }

  enum SearchSuggestEvent {
    case didUpdateResults([MKLocalSearchCompletion])
    case didFail(Error)
  }

  private let pipe = SignalPipe<SearchSuggestEvent>()
  private let completer: MKLocalSearchCompleter

  override init() {
    completer = MKLocalSearchCompleter()
    super.init()
    completer.delegate = self
  }

  func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
    pipe.send(.didUpdateResults(completer.results))
  }

  func completer(_: MKLocalSearchCompleter, didFailWithError error: any Error) {
    pipe.send(.didFail(error))
  }
}

extension SearchState.Suggest {
  fileprivate var query: String {
    Array.build {
      if !subtitle.isEmpty {
        subtitle
      }
      title
    }.joined(separator: ", ")
  }
}

extension MKMapItem {
  fileprivate func getLocation() -> CLLocation? {
    if #available(iOS 26, *) {
      location
    } else { placemark.location }
  }
}
