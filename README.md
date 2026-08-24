# SpinPod Mac 验证器

SpinPod 的第一阶段可行性原型：在 macOS 上通过 Apple 的公开 `CMHeadphoneMotionManager` API 读取 AirPods 运动数据，用陀螺仪角速度估算黑胶唱机转速，并保存原始 CSV 供复核。

> AirPods 4 ANC 实测确认：关闭“自动人耳检测”后，AirPod 离耳放置于转盘时可持续取得运动数据；保持开启时离耳不上报。33 ⅓ 和 45 RPM 测试均获得稳定读数，详见[可行性报告](docs/FEASIBILITY_REPORT.md)。

当前没有独立转速基准，因此项目以 AirPods 的测量值作为阶段性结果：33 ⅓ 档约为 **33.791 RPM**（C），45 档的 10 分钟结果约为 **45.493 RPM**（F）。这些数值不代表已经验证绝对准确度。

## 功能

- 检查运动权限和兼容 AirPods 的数据可用性
- 实时显示瞬时 RPM、1.5 秒滤波 RPM、波动、采样率和样本数
- 以 33 ⅓、45 或 78 RPM 为档位标称值显示相对偏移
- 通过角速度向量模长计算 RPM，不依赖 AirPod 在盘面上的朝向
- 使用滚动中位数和 MAD 过滤偶发运动尖峰
- 导出每一个 IMU 样本，包括角速度、用户加速度、重力、姿态和 RPM
- 提供零第三方依赖的算法检查程序

## 系统要求

- macOS 14 或更高版本
- 支持耳机运动数据的 AirPods，且已经通过蓝牙连接至 Mac
- Apple Swift 6 / Xcode Command Line Tools；不依赖第三方库

离耳测量前必须在“系统设置 → 蓝牙 → AirPods 右侧的 ⓘ”中关闭“自动人耳检测”。应用无法通过公开 API 自动更改或可靠读取这项设置。

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

理想刚体的角速度与测点半径无关，但远离圆心会产生更大的向心加速度，并增加滑动、振动和 Core Motion 传感器融合受干扰的可能。实测时应把 AirPod 固定并尽量靠近转盘圆心。

## 如何验证可行性

完整的 [A–F 实机测试结果](docs/FEASIBILITY_REPORT.md) 已确认公开 API 路径可行。离耳静止状态连续采样 71.6 秒；改变朝向和半径后的 45 RPM 结果仍然稳定；F 连续测量 601.5 秒且没有断流，首尾分钟均值仅变化约 0.027%。

后续复测请遵循[实机验证方案](docs/VALIDATION_PROTOCOL.md)，固定 AirPod、靠近圆心并分别重复多次。如果未来能够取得可靠的独立转速基准，再额外评估绝对准确度。

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
