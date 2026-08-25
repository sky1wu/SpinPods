# SpinPods

SpinPods 通过 Apple 的公开 `CMHeadphoneMotionManager` API 读取 AirPods 运动数据，用陀螺仪角速度估算黑胶唱机转速。仓库包含已完成硬件可行性验证的 Mac 原型，以及共用同一算法和采样逻辑的 iPhone/iPad Universal app。

> AirPods 4 ANC 实测确认：关闭“自动人耳检测”后，AirPod 离耳放置于转盘时可持续取得运动数据；保持开启时离耳不上报。33 ⅓ 和 45 RPM 测试均获得稳定读数，详见[可行性报告](docs/FEASIBILITY_REPORT.md)。

当前没有独立转速基准，因此项目以 AirPods 的测量值作为阶段性结果：左耳 33 ⅓ 档约为 **33.791 RPM**（C），左耳 45 档的 10 分钟结果约为 **45.493 RPM**（F）。这些数值不代表已经验证绝对准确度。

左右耳的传感器读数不能混用：相同放置方式下，右耳在 33 和 45 档分别比左耳重复测量均值高约 **0.52%** 和 **0.64%**。为保证历史数据可比，应固定使用同一侧 AirPod；当前基线沿用左耳。

## 下一阶段平台范围

当前 app 采用一个 SwiftUI Universal target，同时支持 iPhone 和 iPad，共用 `SpinPodsCore`、Core Motion 采集、滤波、历史记录和导出逻辑。

iPad 不是简单放大 iPhone 界面，首版已使用自适应容器，后续需通过真机覆盖：

- 横屏、竖屏和可变窗口尺寸；
- Split View / Stage Manager 下的紧凑与宽屏布局；
- 键盘、触控板和触控操作；
- 测量过程中窗口尺寸与场景状态变化；
- 与 iPhone 相同的 AirPods 权限、左右耳、离耳和连接中断真机测试。

GitHub Actions 将分别执行 iPhone 与 iPad Simulator 构建检查；自适应界面和 AirPods IMU 功能仍需各使用至少一台真实 iPhone 和 iPad 验证。

开发阶段暂不依赖付费 Apple Developer Program。CI 将额外使用 `iphoneos` device SDK 生成未签名、可重签名的 `SpinPods-unsigned.ipa` artifact，再由本地 AltStore Classic / AltServer 使用普通 Apple ID 重签并安装到 iPhone 或 iPad。完整流程及限制见[无付费开发者账号的安装方案](docs/SIDELOADING.md)。

## 功能

- 检查运动权限和兼容 AirPods 的数据可用性
- iPhone/iPad app 实时显示滤波 RPM、转速趋势以及与 33 ⅓、45 或 78 RPM 目标的差值
- 以目标转速 ±1% 为可接受区间，超出时显示过快或过慢；趋势图使用同一容差带
- Mac 验证器额外显示瞬时 RPM、波动、采样率和样本数
- 通过角速度向量模长计算 RPM，不依赖 AirPod 在盘面上的朝向
- 使用滚动中位数和 MAD 过滤偶发运动尖峰
- Mac 验证器可导出每一个 IMU 样本，供研发阶段复核；iPhone/iPad app 不向普通用户暴露 CSV 导出
- 提供零第三方依赖的算法检查程序

## 系统要求

在 iPhone/iPad 上运行 Universal app：

- iOS 17 / iPadOS 17 或更高版本
- 支持耳机运动数据的 AirPods
- 使用 AltStore 侧载时需要普通 Apple ID，但不需要付费开发者账号

在 Mac 上构建和运行验证器：

- macOS 14 或更高版本
- 支持耳机运动数据的 AirPods，且已经通过蓝牙连接至 Mac
- Apple Swift 6 / Xcode Command Line Tools；不依赖第三方库

离耳测量前必须在“系统设置 → 蓝牙 → AirPods 右侧的 ⓘ”中关闭“自动人耳检测”。应用无法通过公开 API 自动更改或可靠读取这项设置。

程序会通过 `CMHeadphoneMotionManagerDelegate` 的连接回调判断耳机是否已连接，再以运行时的 `isDeviceMotionAvailable` 判断运动数据兼容性，不硬编码耳机型号。

## 构建和运行

```sh
./scripts/run-app.sh
```

脚本会通过 Swift Package Manager 编译，在 `.build/SpinPods.app` 组装标准应用包，加入必需的 `NSMotionUsageDescription`，进行本机临时签名并启动。首次点击“开始测量”时，请允许访问运动与健身数据。

不要直接使用 `swift run SpinPodsMac` 做硬件测试：裸可执行文件没有应用包内的隐私用途声明，Core Motion 可能因此终止进程。

单独构建或运行算法检查：

```sh
./scripts/build-app.sh release
swift run SpinPodsCoreChecks
```

## 测量原理

Core Motion 返回耳机自身坐标系下、单位为 rad/s 的三轴角速度 `ω = (x, y, z)`。向量模长不随耳机朝向改变，因此：

```text
RPM = |ω| × 60 / (2π)
```

例如 33 ⅓ RPM 对应约 3.491 rad/s，45 RPM 对应约 4.712 rad/s。程序保留每个原始样本，同时以 1.5 秒滚动窗口滤除离群点并显示中位数。稳定状态要求至少 20 个样本、覆盖至少 0.75 秒且标准差不超过 0.35 RPM。

理想刚体的角速度与测点半径无关，但远离圆心会产生更大的向心加速度，并增加滑动、振动和 Core Motion 传感器融合受干扰的可能。实测时应把 AirPod 固定并尽量靠近转盘圆心。

## 如何验证可行性

完整的 [A–G 实机测试结果](docs/FEASIBILITY_REPORT.md) 已确认公开 API 路径可行。离耳静止状态连续采样 71.6 秒；改变朝向和半径后的 45 RPM 结果仍然稳定；F 连续测量 601.5 秒且没有断流；G 组验证了同一只左耳的跨档重复性，并发现左右耳存在系统性读数差异。

后续复测请遵循[实机验证方案](docs/VALIDATION_PROTOCOL.md)，固定 AirPod、靠近圆心并分别重复多次。如果未来能够取得可靠的独立转速基准，再额外评估绝对准确度。

## 项目结构

```text
App/                           Mac/iOS 应用元数据和运动权限声明
Sources/SpinPodsCore/          与 Apple 框架解耦的 RPM 算法
Sources/SpinPodsCoreChecks/    零依赖算法检查
Sources/SpinPodsMac/           SwiftUI 界面、Core Motion 采样和 CSV 导出
Sources/SpinPodsIOS/           iPhone/iPad Universal SwiftUI 界面
SpinPods.xcodeproj/            无第三方生成器的 Universal app 工程
scripts/build-app.sh           编译、组装和签名 .app
scripts/run-app.sh             构建并启动
scripts/package-unsigned-ipa.sh 将 device .app 打包为可重签名 IPA
```

## iPhone / iPad CI 构建

推送到 GitHub 后，[iOS and iPadOS](.github/workflows/ios.yml) workflow 会依次运行核心算法检查、iPhone Simulator 构建、iPad Simulator 构建和无签名 `iphoneos` Release 构建。普通分支推送的 `SpinPods-unsigned.ipa` 位于对应 Actions 运行页底部的 Artifacts 区域，保留 14 天。

需要在仓库 Releases 页面生成可长期下载的 IPA 时，推送以 `v` 开头的版本标签：

```shell
git tag v0.1.0
git push origin v0.1.0
```

CI 通过后会自动创建 `SpinPods v0.1.0` GitHub Release，并将 `SpinPods-unsigned.ipa` 作为 Release asset。当前工程最低支持 iOS/iPadOS 17，target 同时包含 iPhone 与 iPad device family。

Simulator 只能验证编译和自适应界面，不能提供 AirPods 耳机运动数据。真机安装与验证方式见[无付费开发者账号的安装方案](docs/SIDELOADING.md)。

API 依据：[CMHeadphoneMotionManager](https://developer.apple.com/documentation/coremotion/cmheadphonemotionmanager)、[NSMotionUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nsmotionusagedescription)。Apple 明确要求 iOS 和 macOS 应用提供运动数据用途声明，并建议在采样前检查 `isDeviceMotionAvailable`。
