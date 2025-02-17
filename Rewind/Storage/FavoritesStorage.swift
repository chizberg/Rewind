//
//  FavoritesStorage.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 17.2.25..
//

import VGSL

final class FavoritesStorage {
  private let impl: Property<[Storage.Image]>
  private let makeLoadableImage: (String) -> LoadableImage
  private var modelImages: [Model.Image]

  init(
    storage: KeyValueStorage,
    makeLoadableImage: @escaping (String) -> LoadableImage
  ) {
    impl = storage.makeCodableField(key: "favorites", default: [])
    self.makeLoadableImage = makeLoadableImage
    modelImages = impl.value.map {
      Model.Image($0, image: makeLoadableImage($0.imagePath))
    }
  }

  var property: Property<[Model.Image]> {
    Property(
      getter: { [weak self] in
        self?.modelImages ?? []
      },
      setter: { [weak self] in
        guard let self else { return }
        modelImages = $0
        impl.value = $0.map { Storage.Image($0) }
      }
    )
  }
}
