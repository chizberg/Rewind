import SwiftUI

@main
enum AppEntryPoint {
  static func main() {
    #if DEBUG
    if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
      UnitTestApp.main()
      return
    }
    #endif

    RewindApp.main()
  }
}

#if DEBUG
private struct UnitTestApp: App {
  var body: some Scene {
    WindowGroup {}
  }
}
#endif
