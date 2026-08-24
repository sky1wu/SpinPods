import SwiftUI

@main
struct SpinPodMacApp: App {
    @StateObject private var monitor = HeadphoneMotionMonitor()

    var body: some Scene {
        WindowGroup("SpinPod 验证器") {
            ContentView(monitor: monitor)
                .frame(minWidth: 760, minHeight: 620)
        }
        .defaultSize(width: 820, height: 680)
    }
}

