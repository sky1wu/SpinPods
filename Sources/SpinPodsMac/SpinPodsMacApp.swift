import SwiftUI

@main
struct SpinPodsMacApp: App {
    @StateObject private var monitor = HeadphoneMotionMonitor()

    var body: some Scene {
        WindowGroup("SpinPods 验证器") {
            ContentView(monitor: monitor)
                .frame(minWidth: 760, minHeight: 620)
        }
        .defaultSize(width: 820, height: 680)
    }
}
