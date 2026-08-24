import CoreMotion
import Foundation
import SpinPodsCore

struct RecordedMotionSample {
    let elapsedTime: TimeInterval
    let deviceTimestamp: TimeInterval
    let rotationRate: MotionVector
    let userAcceleration: MotionVector
    let gravity: MotionVector
    let roll: Double
    let pitch: Double
    let yaw: Double
    let reading: RPMReading

    init(motion: CMDeviceMotion, elapsedTime: TimeInterval, reading: RPMReading) {
        self.elapsedTime = elapsedTime
        deviceTimestamp = motion.timestamp
        rotationRate = MotionVector(
            x: motion.rotationRate.x,
            y: motion.rotationRate.y,
            z: motion.rotationRate.z
        )
        userAcceleration = MotionVector(
            x: motion.userAcceleration.x,
            y: motion.userAcceleration.y,
            z: motion.userAcceleration.z
        )
        gravity = MotionVector(
            x: motion.gravity.x,
            y: motion.gravity.y,
            z: motion.gravity.z
        )
        roll = motion.attitude.roll
        pitch = motion.attitude.pitch
        yaw = motion.attitude.yaw
        self.reading = reading
    }
}
