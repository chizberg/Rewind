//
//  ColorizationHelpers.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 12. 9. 2026.
//

// Helpers shared by the colorization pipeline's stages, kept out of the app's global scope.
enum ColorizationHelpers {
  // OpenCV's BORDER_REFLECT_101: an index past the edge folds back without repeating the edge
  // pixel, abcd -> dcb|abcd|cba. A single pixel has nothing to fold into, it is the answer.
  // https://docs.opencv.org/4.x/d2/de8/group__core__array.html#ga247f571aa6244827d3d798f13892da58
  static func mirroredIndex(_ index: Int, limit: Int) -> Int {
    guard limit > 1 else { return 0 }
    let period = 2 * limit - 2
    var i = index % period
    if i < 0 { i += period }
    return i < limit ? i : period - i
  }
}
