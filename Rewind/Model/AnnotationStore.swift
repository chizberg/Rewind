//
//  AnnotationStore.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 17. 12. 2025.
//

import Foundation
import MapKit

final actor AnnotationStore {
  typealias Key = AnnotationValue
  private var anns = [Key: WeakRef<MKAnnotation>]()

  func create(key: Key) -> MKAnnotation {
    if let existing = existing(key: key) {
      return existing
    }
    let annotation: MKAnnotation = switch key {
    case let .image(i): Annotation(value: i)
    case let .cluster(c): Annotation(value: c)
    case let .localCluster(lc): Annotation(value: lc)
    }
    anns[key] = WeakRef(annotation)
    return annotation
  }

  func existing(key: Key) -> MKAnnotation? {
    anns[key]?.value
  }

  func refresh() {
    anns = anns.filter { _, value in value.value != nil }
  }

  /// Clears all stored annotation references.
  /// Called on memory warnings to free up memory.
  func clearAll() {
    anns.removeAll()
  }
}

enum AnnotationValue: Hashable {
  case image(Model.Image)
  case cluster(Model.Cluster)
  case localCluster(Model.LocalCluster)
}

protocol Locatable {
  var coordinate: Coordinate { get }
}

final class Annotation<T: Locatable>: NSObject, MKAnnotation {
  var value: T

  fileprivate init(value: T) {
    self.value = value
  }

  var coordinate: Coordinate {
    value.coordinate
  }

  static func withoutStore(value: T) -> Annotation<T> {
    Annotation(value: value)
  }
}

extension Model.Image: Locatable {}
extension Model.Cluster: Locatable {}
extension Model.LocalCluster: Locatable {}
