# IsleWhispers App 多语言最终验证报告

## 范围与环境

- 验证日期：2026-09-03
- 分支：`codex/launch-agreement-rich-text`
- Task 9 基线：`398edd7bd7ea50ce5f3633e30a09f6e1b5c30ea3`
- 工作目录：`/Users/db/Documents/git/my/IsleWhispers/IsleWhispers/.worktrees/launch-agreement-rich-text`
- 自动测试设备：iPhone 17 Pro，iOS Simulator 26.4（23E244），arm64
- 构建环境：Xcode 使用 iPhoneSimulator 26.2 SDK；测试 xcresult 显示 macOS 26.2

本报告区分自动测试、静态/构建产物检查、实际 Simulator 截图和物理设备验证。编译或注入 Bundle 的单元测试不计作实际三语运行截图。

## TDD：生产 Swift 中文字符串守卫

### RED

先只在 `IsleWhispersTests/LocalizationTests.swift` 加入以下测试，尚未实现 test-only helper：

- `testChineseStringLiteralScannerReportsFileAndLineFromFixture`
- `testProductionSwiftContainsNoUserFacingChineseStringLiterals`

执行：

```bash
cd /Users/db/Documents/git/my/IsleWhispers/IsleWhispers/.worktrees/launch-agreement-rich-text/IsleWhispers
xcodebuild -workspace IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  -parallel-testing-enabled NO \
  -only-testing:IsleWhispersTests/LocalizationTests \
  -resultBundlePath /tmp/task9-localization-red.xcresult \
  test CODE_SIGNING_ALLOWED=NO
```

结果：退出码 65，`** TEST FAILED **`。编译器在 fixture 与生产扫描测试调用处均报告 `cannot find 'chineseStringLiteralMatches' in scope`；失败原因正是待实现 helper 缺失，而非临时修改生产文件。

### GREEN

在测试文件内实现最小扫描器：递归读取 `IsleWhispers/IsleWhispers/**/*.swift`，忽略 Swift 行注释与可嵌套块注释，检查普通/raw/多行字符串中的 Han 字符，输出 `文件:行号: 字面量`。初始 allowlist 为严格空集合。

执行同一 focused 命令，改用：

```bash
-resultBundlePath /tmp/task9-localization-green.xcresult
```

结果：退出码 0，`** TEST SUCCEEDED **`；LocalizationTests 6/6，0 failures。fixture 精确得到 `Fixture.swift:2: "中文"`；生产扫描 0 命中，因此 Task 9 未修改任何生产文件。

## 自动测试

### 本地化定向测试

```bash
cd /Users/db/Documents/git/my/IsleWhispers/IsleWhispers/.worktrees/launch-agreement-rich-text/IsleWhispers
xcodebuild -workspace IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  -parallel-testing-enabled NO \
  -only-testing:IsleWhispersTests/LocalizationTests \
  -only-testing:IsleWhispersTests/AppLaunchCoordinatorTests \
  -only-testing:IsleWhispersTests/SoundCatalogGroupingTests \
  -only-testing:IsleWhispersTests/HomeViewControllerTests \
  -only-testing:IsleWhispersTests/SoundLibraryViewControllerTests \
  -only-testing:IsleWhispersTests/FocusPlaybackViewControllerTests \
  -only-testing:IsleWhispersTests/SettingsViewControllerTests \
  -resultBundlePath /tmp/task9-localization-directed.xcresult \
  test CODE_SIGNING_ALLOWED=NO
```

结果：退出码 0，`** TEST SUCCEEDED **`；91 passed，0 failed，0 skipped，0 expected failures。

### 全量 XCTest

```bash
cd /Users/db/Documents/git/my/IsleWhispers/IsleWhispers/.worktrees/launch-agreement-rich-text/IsleWhispers
xcodebuild -workspace IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  -parallel-testing-enabled NO \
  -resultBundlePath /tmp/task9-localization-full.xcresult \
  test CODE_SIGNING_ALLOWED=NO
```

结果：退出码 0，`** TEST SUCCEEDED **`；163 passed，0 failed，0 skipped，0 expected failures。

两份结果数量通过以下命令从 xcresult 重新读取：

```bash
xcrun xcresulttool get test-results summary --path /tmp/task9-localization-directed.xcresult
xcrun xcresulttool get test-results summary --path /tmp/task9-localization-full.xcresult
```

定向和全量测试运行时仍可见既有的 Simulator 音频硬件、部分测试宿主 appearance/window 诊断，不影响 XCTest 计数；本任务没有修改相关生产/测试宿主代码。

## Clean build 与静态检查

固定 DerivedData 构建：

```bash
cd /Users/db/Documents/git/my/IsleWhispers/IsleWhispers/.worktrees/launch-agreement-rich-text/IsleWhispers
xcodebuild -workspace IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/islewhispers-localization-derived-data \
  clean build CODE_SIGNING_ALLOWED=NO 2>&1 | tee /tmp/task9-localization-clean-build.log
```

结果：退出码 0，`** CLEAN SUCCEEDED **`、`** BUILD SUCCEEDED **`。日志仍含基线已有的 YYText 1.0.7 弃用/头文件 warning、当前工具链 linker search-path warning，以及 Task 3/8 生产文件已有的 Swift 6 concurrency warning；Task 9 只修改测试与报告，没有新增生产 warning/error。

静态命令：

```bash
rg -n '"[^"\n]*[\p{Han}][^"\n]*"' IsleWhispers --glob '*.swift'
rg -n 'AppleLanguages' IsleWhispers ../IsleWhispersTests
git diff --check
```

结果：三条命令均无输出；生产 Swift 没有中文字符串字面量，没有通过 `AppleLanguages` 覆盖系统语言，diff whitespace 检查干净。

## 固定 `.app` 资源产物

检查对象：`/tmp/islewhispers-localization-derived-data/Build/Products/Debug-iphonesimulator/IsleWhispers.app`

```bash
plutil -p /tmp/islewhispers-localization-derived-data/Build/Products/Debug-iphonesimulator/IsleWhispers.app/Info.plist \
  | rg 'CFBundleDevelopmentRegion|CFBundleLocalizations'
find /tmp/islewhispers-localization-derived-data/Build/Products/Debug-iphonesimulator/IsleWhispers.app \
  -path '*lproj/Localizable.strings' -print | sort
find /tmp/islewhispers-localization-derived-data/Build/Products/Debug-iphonesimulator/IsleWhispers.app \
  -name '*.caf' | wc -l
```

结果：

- `CFBundleDevelopmentRegion = en`。
- 存在 `en.lproj/Localizable.strings`、`zh-Hans.lproj/Localizable.strings`、`zh-Hant.lproj/Localizable.strings`。
- CAF 资源数为 15。
- `LocalizationTests.testCatalogContainsExactly129NonemptyKeysInAllThreeLocales` 证明三语各有相同且非空的 129 个 key。

## 稳定数据证据

全量 163/163 中包含以下运行测试：

- `RecentSoundsStoreTests.testPersistedRainIdentifierResolvesToLocalizedMetadataWithoutChangingIdentity`：持久化 `2_sound_rain` 后，英语/简中/繁中显示分别变化，`id` 仍为 `2_sound_rain`；生产 `Sound.id` 由 `audioResource` 返回。
- `SoundCatalogGroupingTests.testLocalizedDisplayDoesNotChangeStableResourceIdentity`：三语读取前后逐项比较 `id/audioResource/backgroundResource/category.rawValue`。
- `PlaybackEndNotificationSchedulerTests.testPlaybackEndNotificationUsesStableIdentity`：常量仍为 `isleWhispers.playbackEnded`。
- `PlaybackEndNotificationSchedulerTests.testPlaybackEndNotificationTitleUsesInjectedBundle`：英语/简中/繁中 request 的 title 本地化，同时每个实际构造的 request identifier 仍为 `isleWhispers.playbackEnded`。

## 实际 Simulator 截图：PARTIAL / BLOCKED

没有把自动测试或 clean build 写成运行截图通过，也没有使用 launch argument、`AppleLanguages` 或 UserDefaults 覆盖语言。

尝试过程：

1. 按 GUI 控制流程请求 Simulator 可访问状态，单次调用长期无返回，被中断；没有得到可核验截图。
2. 随后创建 iOS 26.4 的 iPhone SE（3rd generation，320×568 等效）与 iPhone 13（390×844）临时模拟器，准备安装上述固定 `.app`；两台设备首次 `simctl bootstatus -b` 并行等待超过 60 秒仍未完成，按时限终止并删除临时设备。

因此本轮截图绝对路径：无（未产出文件）。以下均不能声明实际运行截图通过：

- English / 简体中文 / 繁體中文的首次协议、首页、声音列表、Focus、设置、关于、帮助反馈。
- 320×568 与 390×844 的完整页面矩阵。
- 三语最大辅助字号下 Launch、Library、Focus、Settings 的真实手势滚动。

自动测试已经覆盖三语文案/Bundle 注入，以及 320×568 最大辅助字号的关键布局/滚动可达性，但这只能作为自动化证据，不能代替系统 Preferred Language 下的真实截图。

## 待实机验证

- 物理设备上的 English / 简体中文 / 繁體中文系统或 App Preferred Language 全流程。
- 物理设备通知授权、前台 banner/声音以及播放结束通知的真实投递。
- 锁屏/控制中心 Now Playing 的真实显示与语言切换。
- VoiceOver 实际手势、YYText 两个自定义 action、最大辅助字号滚动体验。
- 真机后台音频、暂停/关闭与计时结束状态。

## 提交说明

Task 9 只应提交：

- `IsleWhispersTests/LocalizationTests.swift`
- `docs/superpowers/reports/2026-09-02-app-localization-verification.md`

最终提交 SHA 由提交完成后的 `git log -1` 记录；由于提交对象包含本报告，报告正文不能自引用尚未生成的提交 SHA。Task 9 的 ignored 实施报告会在提交后记录该 SHA。

## Fix Round 1：递归解析字符串插值

### 审查问题

Task 9 初版扫描器在普通字符串内遇到反斜杠时无条件跳过两个字符，因此 `\(...)` 只跳过插值开头，未从字符串态切回代码态。插值表达式中的嵌套字符串可能提前结束外层字符串，raw interpolation 可能整段误报，插值内的中文注释也可能被当作外层可见文字。

### RED fixtures

只增加 fixtures、尚未修改 helper 时执行：

```bash
cd /Users/db/Documents/git/my/IsleWhispers/IsleWhispers/.worktrees/launch-agreement-rich-text/IsleWhispers
xcodebuild -workspace IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  -parallel-testing-enabled NO \
  -only-testing:IsleWhispersTests/LocalizationTests \
  -resultBundlePath /tmp/task9-fix1-red2.xcresult \
  test CODE_SIGNING_ALLOWED=NO
```

结果：退出码 65，9 tests 中 7 passed、2 failed、0 skipped。两个失败精确证明：

- 普通插值内的 `"简体"`、`"繁體"` 漏报，raw interpolation 被错误报告为整段外层 raw string，而不是内部 `"原始插值"`。
- `// 中文行注释` 与嵌套 `/* 中文外层 /* 中文内层 */ 仍是注释 */` 被错误吞入外层字符串并报告。

新增 fixtures 同时锁定嵌套插值/嵌套字符串、escaped quote、独立 raw string、raw interpolation、多行字符串，以及每个真实中文 literal 的文件名与起始行号。期望值均为手写字面量，不复用扫描器逻辑生成。

### 最小修复与 GREEN

没有引入 SwiftSyntax 或生产依赖。test-only `SwiftChineseStringLiteralScanner` 使用递归状态机：

- 代码态解析行注释、可嵌套块注释和插值括号深度。
- 字符串态解析普通/raw、多行 delimiter 与普通 escape。
- 遇到 `\#*(...)` 时递归回代码态，因此会扫描插值内的嵌套字符串，但不会把插值注释算作外层字符串文字。
- 只以字符串的非插值片段判断是否含 Han 字符；诊断按 source offset 排序并保留 literal 起始行。
- allowlist 继续为空。

执行：

```bash
cd /Users/db/Documents/git/my/IsleWhispers/IsleWhispers/.worktrees/launch-agreement-rich-text/IsleWhispers
xcodebuild -workspace IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  -parallel-testing-enabled NO \
  -only-testing:IsleWhispersTests/LocalizationTests \
  -resultBundlePath /tmp/task9-fix1-green.xcresult \
  test CODE_SIGNING_ALLOWED=NO
```

结果：退出码 0，`** TEST SUCCEEDED **`；9 passed、0 failed、0 skipped。生产递归扫描仍为 0 命中。

随后执行：

```bash
xcodebuild -workspace IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/islewhispers-localization-derived-data \
  build CODE_SIGNING_ALLOWED=NO 2>&1 | tee /tmp/task9-fix1-generic-build.log
rg -n '"[^"\n]*[\p{Han}][^"\n]*"' IsleWhispers --glob '*.swift'
rg -n 'AppleLanguages' IsleWhispers ../IsleWhispersTests
git diff --check
```

结果：generic build 退出码 0、`** BUILD SUCCEEDED **`；三个静态检查均无输出。

Fix Round 1 只修改 test-only helper/fixtures 与报告，未修改生产代码，因此没有重跑全量 163 tests。上文 163/163 是 Fix 前的 Task 9 全量证据；Fix 后证据为 LocalizationTests 9/9 加 generic build。
