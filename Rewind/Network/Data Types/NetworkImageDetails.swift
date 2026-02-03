//
//  NetworkImageDetails.swift
//  Camera Roll
//
//  Created by Alexey Sherstnev on 14.01.2023.
//

import Foundation

extension Network {
  struct ImageDetails: Decodable {
    let cid: Int // unique image id
    let file: String // local path to image
    let title: String
    let dir: String? // direction
    let geo: [Double] // location, has two values: latitude and longitude
    let year: Int // lower time boundary
    let year2: Int // upper time boundary

    let desc: String? // description of image
    let source: String? // can contain url
    let address: String?
    let author: String?

    let watersignText: String?

    // inner JSON values
    let user: User // user that uploaded the image

    #if DEBUG // unused fields. under debug to not break decoding
    let type: Int? // distinguishes between photos and paintings
    let s: Int? // photo status
    let ldate: String // load time (when photo was uploaded), required
    let mime: String? // MIME type of the image
    let size: Int? // file size in bytes
    let r2d: [Double]? // coordinates for randomized selection in gallery flip coin mode
    let frags: [Fragment]? // array of comment fragments
    let h: Int? // original image height
    let hs: Int? // standard image height
    let w: Int? // original image width
    let ws: Int? // standard image width
    let waterh: Int? // watermark height for original size
    let waterhs: Int? // watermark height for standard size
    let y: String? // aggregated year field displaying date ranges (e.g., "1920—1940")
    let cdate: String? // last change time
    let stdate: String? // time of setting current photo status
    let adate: String? // activation time
    let vdcount: Int? // views per day
    let vcount: Int? // total views
    let vwcount: Int? // views per week
    let ucdate: String? // last time human-readable attributes were changed
    let regions: [Region]?
    #endif
  }

  struct User: Decodable {
    let name: String
    #if DEBUG // unused fields. under debug to not break decoding
    let ranks: [String]?
    let login: String?
    #endif

    enum CodingKeys: String, CodingKey {
      case name = "disp"
      #if DEBUG // unused fields. under debug to not break decoding
      case login
      case ranks
      #endif
    }
  }

  #if DEBUG // unused structs. under debug to not break decoding
  struct Fragment: Decodable {
    let cid: Int?
  }

  struct Region: Decodable {
    let cid: Int
    let title_local: String?
    let phc: Int? // photo count
    let pac: Int? // painting count
    let cc: Int? // comment count
  }
  #endif
}

#if DEBUG
extension Network.ImageDetails {
  static let mock = Network.ImageDetails(
    cid: 1_641_494,
    file: "v/s/s/vssv956fa6kpunaqmm.jpg",
    title: "Теразије",
    dir: "nw",
    geo: [44.813047, 20.460579],
    year: 1958,
    year2: 1965,
    desc: "На самом деле описания в API нет, но его добавлю я.",
    source: "too long for me",
    address: nil,
    author: "Jerry Cooke",
    watersignText: "uploaded by Zanuda Kartotechnaya",
    user: .init(name: "Николай", ranks: [], login: "nikolay"),
    // unused fields
    type: 1,
    s: 5,
    ldate: "2025-04-16T08:24:21.264Z",
    mime: "image/jpeg",
    size: 260_350,
    r2d: [48.715652, 90.425259],
    frags: [],
    h: 800,
    hs: 684,
    w: 1060,
    ws: 928,
    waterh: 19,
    waterhs: 16,
    y: "1958—1965",
    cdate: "2025-05-10T16:26:35.322Z",
    stdate: "2025-04-16T22:02:04.133Z",
    adate: "2025-04-16T22:02:04.133Z",
    vdcount: 6,
    vcount: 66,
    vwcount: 9,
    ucdate: "2025-05-10T16:26:35.322Z",
    regions: []
  )
}
#endif
