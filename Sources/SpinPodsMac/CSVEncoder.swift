import Foundation

enum CSVEncoder {
    static func encode(_ samples: [RecordedMotionSample], airPodSide: AirPodSide?) -> String {
        var rows = [
            "elapsed_s,device_timestamp_s,gyro_x_rad_s,gyro_y_rad_s,gyro_z_rad_s,gyro_magnitude_rad_s,raw_rpm,filtered_rpm,rpm_stddev,is_stable,user_accel_x_g,user_accel_y_g,user_accel_z_g,gravity_x_g,gravity_y_g,gravity_z_g,roll_rad,pitch_rad,yaw_rad,airpod_side"
        ]
        rows.reserveCapacity(samples.count + 1)

        for sample in samples {
            rows.append([
                number(sample.elapsedTime),
                number(sample.deviceTimestamp),
                number(sample.rotationRate.x),
                number(sample.rotationRate.y),
                number(sample.rotationRate.z),
                number(sample.rotationRate.magnitude),
                number(sample.reading.rawRPM),
                number(sample.reading.smoothedRPM),
                number(sample.reading.standardDeviationRPM),
                sample.reading.isStable ? "true" : "false",
                number(sample.userAcceleration.x),
                number(sample.userAcceleration.y),
                number(sample.userAcceleration.z),
                number(sample.gravity.x),
                number(sample.gravity.y),
                number(sample.gravity.z),
                number(sample.roll),
                number(sample.pitch),
                number(sample.yaw),
                airPodSide?.rawValue ?? ""
            ].joined(separator: ","))
        }

        return rows.joined(separator: "\n") + "\n"
    }

    private static func number(_ value: Double) -> String {
        String(format: "%.8f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
