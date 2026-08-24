import SwiftUI

@main
struct SpinPodsApp: App {
    @StateObject private var monitor = HeadphoneMotionMonitor()

    var body: some Scene {
        WindowGroup {
            SpinPodsContentView(monitor: monitor)
        }
    }
}
