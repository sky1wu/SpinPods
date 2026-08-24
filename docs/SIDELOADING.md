# SpinPods 无付费开发者账号安装方案

## 目标

开发阶段不在 GitHub 保存 Apple 签名证书、Provisioning Profile 或 Apple ID。GitHub Actions 只负责编译并输出未签名的 device IPA；下载后由开发者自己的 Mac 通过 AltStore Classic / AltServer 重签并安装到 iPhone 或 iPad。

```text
GitHub Actions
  ├─ 核心算法检查与 iPhone/iPad Simulator 构建
  └─ iphoneos 无签名构建
       └─ SpinPods-unsigned.ipa artifact
            └─ AltStore Classic / AltServer 本地重签
                 └─ iPhone 或 iPad 真机验证
```

这条路径不需要付费 Apple Developer Program，但仍需要普通 Apple ID。AltStore 将普通 Apple ID 作为免费开发者账号使用。

## CI 输出要求

GitHub Actions 会对 iPhone/iPad Universal target 执行两类构建：

1. 运行 `SpinPodsCoreChecks`，并使用 iOS Simulator SDK 分别编译 iPhone 和 iPad 版本，不需要代码签名。
2. 使用 `iphoneos` device SDK 和 `CODE_SIGNING_ALLOWED=NO` 编译真机 `.app`，再按标准 IPA 目录结构打包：

```text
Payload/
└─ SpinPods.app/
```

构建得到 device `.app` 后，使用仓库内的脚本打包：

```shell
./scripts/package-unsigned-ipa.sh path/to/SpinPods.app .build/SpinPods-unsigned.ipa
```

脚本会拒绝 macOS 或 Simulator `.app`，也不会覆盖已有的 IPA，以避免 CI 误发布不可用产物。

最终 artifact 命名为 `SpinPods-unsigned.ipa`。它不是 App Store 分发包，也不能由系统直接安装；AltStore/AltServer 会在本地用用户自己的 Apple ID 重新签名。

CI 中禁止保存或请求：

- Apple ID 或密码；
- 签名证书及私钥；
- Provisioning Profile；
- App Store Connect API Key。

SpinPods 当前使用 Core Motion 和 `NSMotionUsageDescription`，不需要额外的付费 entitlement。以后如加入 iCloud、推送通知、App Groups 等能力，需要重新确认免费签名和 AltStore 是否支持。

## AltStore Classic 安装

1. 从 AltStore 官方网站安装 AltServer for macOS。
2. 将 iPhone 或 iPad 连接到 Mac，解锁并信任这台电脑。
3. 在 Finder 中启用“连接 Wi-Fi 时显示此 iPhone/iPad”。
4. 通过 AltServer 安装 AltStore Classic，并使用普通 Apple ID 完成签名。
5. iOS/iPadOS 16 或更高版本需要在“设置 → 隐私与安全性 → 开发者模式”中开启 Developer Mode。
6. 从 GitHub Actions 下载并解压 artifact，把 `SpinPods-unsigned.ipa` 导入 AltStore 安装。
7. 保持设备与运行 AltServer 的 Mac 处于同一网络，定期打开 AltStore 检查刷新状态。

也可以在 macOS 按住 Option 点击 AltServer 菜单，直接选择“Sideload .ipa…”，无需先安装 AltStore；但这种方式需要每 7 天手动重新安装。

## 免费签名限制

- 侧载 app 的签名有效期为 7 天，到期后无法启动；
- AltStore 可在同一 Wi-Fi 下连接 AltServer 自动刷新，也可手动刷新；
- 一台设备通常最多同时保留 3 个侧载 app；
- 安装和刷新需要普通 Apple ID；
- GitHub Actions 无法代替真机签名、安装或 AirPods 硬件测试。

这些限制适合早期验证，不适合公开测试或正式分发。需要 TestFlight、稳定长期安装或 App Store 发布时，仍应加入 Apple Developer Program。

## 验证清单

每个 IPA 至少在一台 iPhone 和一台 iPad 上确认：

- 安装、首次启动和 Developer Mode 正常；
- 运动与健身权限提示包含明确用途；
- AirPods 连接与 `isDeviceMotionAvailable` 状态正确；
- 左耳、右耳和双耳连接情况下的数据来源行为；
- 关闭自动人耳检测后可离耳持续采样；
- 进入后台、锁屏、来电和蓝牙中断后状态恢复正确；
- iPad 横竖屏、Split View 与 Stage Manager 布局可用；
- 7 天内自动刷新以及过期后的重新安装不丢失必要数据。

参考：[AltStore macOS 安装说明](https://faq.altstore.io/altstore-classic/how-to-install-altstore-macos)、[AltServer 与直接 IPA 侧载](https://faq.altstore.io/release-notes/altserver)、[AltStore 免费签名限制](https://faq.altstore.io/altstore-classic/your-altstore)。
