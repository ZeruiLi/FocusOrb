# FocusOrb 测试版安装说明（无 Xcode）

适用系统：macOS 14.0 及以上

## 正确安装流程（必须按顺序）
1. 双击 `FocusOrb-macOS-test-unsigned.dmg`
2. 将 `FocusOrb.app` 拖到 `Applications`
3. 在 DMG 内双击 `open_after_download.command`
4. 等待脚本自动清理隔离属性并打开 `/Applications/FocusOrb.app`

## 重要提醒
- 不要在 DMG 内直接双击 `FocusOrb.app` 运行。
- 必须从 `/Applications/FocusOrb.app` 打开。
- 这是无签名、未公证的内测包，首次运行被 Gatekeeper 拦截是预期行为。

## 如果仍被拦截
1. 打开 System Settings -> Privacy & Security
2. 在底部找到 FocusOrb 的拦截提示，点击 `Open Anyway`
3. 再次打开 `/Applications/FocusOrb.app`

## 手动命令（备用）
```bash
xattr -dr com.apple.quarantine "/Applications/FocusOrb.app"
open "/Applications/FocusOrb.app"
```

## 发包前验收（打包机）
请在打包机执行以下命令并附上输出：
```bash
codesign -dv --verbose=4 "/path/to/FocusOrb.app"
spctl -a -vv "/path/to/FocusOrb.app"
xattr -l "/path/to/FocusOrb.app"
```

打包脚本会自动生成 `VALIDATION-打包机结果.txt`。
