# SpinPod Mac 验证器

SpinPod 的第一阶段可行性原型：在 macOS 上通过 Apple 的公开 `CMHeadphoneMotionManager` API 读取 AirPods 运动数据，用陀螺仪角速度估算黑胶唱机转速，并保存原始 CSV 供复核。

> 目前已验证软件构建、打包、签名和转速算法；是否能在 AirPod 离耳并固定于转盘时持续取得运动数据，必须用真实耳机完成实验。这是本原型需要回答的核心问题。

## 功能

- 检查运动权限和兼容 AirPods 的数据可用性
- 实时显示瞬时 RPM、1.5 秒滤波 RPM、波动、采样率和样本数
- 以 33 ⅓、45 或 78 RPM 为目标显示相对误差
- 通过角速度向量模长计算 RPM，不依赖 AirPod 在盘面上的朝向
- 使用滚动中位数和 MAD 过滤偶发运动尖峰
- 导出每一个 IMU 样本，包括角速度、用户加速度、重力、姿态和 RPM
- 提供零第三方依赖的算法检查程序

## 系统要求

- macOS 14 或更高版本
- 支持耳机运动数据的 AirPods，且已经通过蓝牙连接至 Mac
- Apple Swift 6 / Xcode Command Line Tools；不依赖第三方库

程序会以运行时的 `isDeviceMotionAvailable` 为最终兼容性判断，不硬编码耳机型号。

## 构建和运行

```sh
./scripts/run-app.sh
```

脚本会通过 Swift Package Manager 编译，在 `.build/SpinPod.app` 组装标准应用包，加入必需的 `NSMotionUsageDescription`，进行本机临时签名并启动。首次点击“开始测量”时，请允许访问运动与健身数据。

不要直接使用 `swift run SpinPodMac` 做硬件测试：裸可执行文件没有应用包内的隐私用途声明，Core Motion 可能因此终止进程。

单独构建或运行算法检查：

```sh
./scripts/build-app.sh release
swift run SpinPodCoreChecks
```

## 测量原理

Core Motion 返回耳机自身坐标系下、单位为 rad/s 的三轴角速度 `ω = (x, y, z)`。向量模长不随耳机朝向改变，因此：

```text
RPM = |ω| × 60 / (2π)
```

例如 33 ⅓ RPM 对应约 3.491 rad/s，45 RPM 对应约 4.712 rad/s。程序保留每个原始样本，同时以 1.5 秒滚动窗口滤除离群点并显示中位数。稳定状态要求至少 20 个样本、覆盖至少 0.75 秒且标准差不超过 0.35 RPM。

## 如何验证可行性

请按 [实机验证方案](docs/VALIDATION_PROTOCOL.md) 依次测试佩戴、离耳静止、33 ⅓ RPM 和 45 RPM 四种情况。最关键的判定是：AirPod 离耳后能否连续至少 60 秒提供运动样本；如果系统停止上报，单靠当前公开 API 就无法实现预期的“AirPods 放在转盘上”使用方式。

## 项目结构

```text
App/Info.plist                 应用元数据和运动权限用途声明
Sources/SpinPodCore/           与 Apple 框架解耦的 RPM 算法
Sources/SpinPodCoreChecks/     零依赖算法检查
Sources/SpinPodMac/            SwiftUI 界面、Core Motion 采样和 CSV 导出
scripts/build-app.sh           编译、组装和签名 .app
scripts/run-app.sh             构建并启动
```

API 依据：[CMHeadphoneMotionManager](https://developer.apple.com/documentation/coremotion/cmheadphonemotionmanager)、[NSMotionUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nsmotionusagedescription)。Apple 明确要求 iOS 和 macOS 应用提供运动数据用途声明，并建议在采样前检查 `isDeviceMotionAvailable`。

