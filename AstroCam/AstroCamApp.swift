import SwiftUI

@main
struct AstroCamApp: App {
    @StateObject private var cameraViewModel = CameraViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(cameraViewModel)
        }
    }
}
