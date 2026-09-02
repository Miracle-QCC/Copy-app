# ClipStack

ClipStack 是一款原生 macOS 剪贴板历史工具，使用 SwiftUI 和 AppKit 构建。

应用 Logo 使用 `Assets/AppIconSource.png`，可通过 `scripts/generate-icons.sh` 重新生成 macOS 图标资源。

## 功能

- 自动记录系统剪贴板中的文本、链接、代码和图片
- 本地 JSON 持久化，重新打开应用后历史记录仍然存在
- 搜索、分类筛选、收藏、删除和清空历史
- 重复内容自动置顶并统计使用次数
- 在任意应用中按 `Control + V` 打开轻量剪贴板面板
- 支持搜索、方向键选择、回车复制和 `Esc` 关闭快捷面板
- 菜单栏快速查看最近记录并一键复制
- 原生三栏 macOS UI，支持深色模式

## 运行

要求 macOS 14 或更高版本，以及 Swift 6 / Xcode 16 Command Line Tools。

```bash
swift run
```

第一次启动后，复制任意文字、链接、代码或图片，内容会自动出现在 ClipStack 中。

也可以生成可双击运行的应用：

```bash
chmod +x scripts/build-app.sh
./scripts/build-app.sh
open dist/ClipStack.app
```

生成带 `Applications` 拖拽入口的 DMG 安装包：

```bash
chmod +x scripts/build-dmg.sh
./scripts/build-dmg.sh
```

默认 DMG 使用本地临时签名，只适合开发测试。分发给其他用户前，需要 Apple Developer
的 `Developer ID Application` 证书并完成 Apple 公证：

```bash
xcrun notarytool store-credentials ClipStackNotary \
  --apple-id "你的 Apple ID" \
  --team-id "你的 Team ID" \
  --password "App 专用密码"

SIGN_IDENTITY="Developer ID Application: 你的名称 (TEAMID)" \
NOTARY_PROFILE="ClipStackNotary" \
./scripts/build-notarized-dmg.sh 1.2.2
```

公证成功后，`spctl` 会接受该 DMG，其他用户从网络下载后可直接打开。

## 测试

```bash
swift test
```

历史文件保存在：

```text
~/Library/Application Support/ClipStack/clipboard-history.json
```
