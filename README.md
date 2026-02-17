# Rewind

Rewind is an iOS app for exploring retro images on a map. 

Available in the App Store: https://apps.apple.com/app/rewind-history-on-a-map/id6755358800

Also in TestFlight: https://testflight.apple.com/join/vbJFFZgD

### Features

- **Vintage images near you:** the app uses PastVu API to fetch images and their metadata and shows them on an Apple MapKit map
- **Favorites:** save images you like to view them later
- **Compare:** take a photo to compare how a place looks like today and how it looked in the past. You can use either the camera or Google Street View.
- **Search:** quickly find places you know with a simple query. *Uses Apple MapKit search*
- **Translate:** read descriptions in your preferred language. Uses Google Translate.

### Screenshots

<p align="leading">
  <img src="screenshots/phone/en/jpgs/time-travel-app.jpeg" width="19%" />
  <img src="screenshots/phone/en/jpgs/what-was-here.jpeg" width="19%" />
  <img src="screenshots/phone/en/jpgs/explore-the-past.jpeg" width="19%" />
  <img src="screenshots/phone/en/jpgs/moments-you-love.jpeg" width="19%" />
  <img src="screenshots/phone/en/jpgs/compare.jpeg" width="19%" />
</p>

### Availability
iOS 18+

### PastVu

All images in the app come from the [PastVu API](https://docs.pastvu.com/dev/api). You can see all these photos on [their website](https://pastvu.com). They have their rules, so better [check them out](https://docs.pastvu.com/en/rules) :)

### Stack

- SwiftUI
- Apple MapKit
- TCA-inspired Reducer
- [VGSL](https://github.com/yandex/vgsl)

### Setup

1. Copy `Config/Secrets.xcconfig.example` to `Config/Secrets.xcconfig`
2. Replace `REPLACE_ME` with your Google API key
3. Build and run

#### P.S. Previous attempts

This is not the first time I try to make this app - you can find repos [PhotoPlenka](https://github.com/chizberg/PhotoPlenka) and [CameraRoll](https://github.com/chizberg/Camera-Roll). These have pretty much the same functionality, but in PhotoPlenka the UX feels off, and in CameraRoll there are performance issues. Still, could be fun to check them out!
