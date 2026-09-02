# IsleWhispers 全局多语言实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 IsleWhispers 的全部用户可见文案统一迁移到英文源语言、简体中文与通用繁體中文翻译的本地化体系，跟随 iOS 语言设置并在不支持的语言下回退英文。

**Architecture:** 使用一个 `Localizable.xcstrings` 保存运行时文案，使用轻量 `L10n` 从可注入的 `Bundle` 读取和格式化字符串；声音仍以 `audioResource` 作为稳定身份，展示名称改为按 Bundle 计算。各页面和服务默认使用 `.main`，测试传入 `en.lproj`、`zh-Hans.lproj` 或 `zh-Hant.lproj`，不修改 `AppleLanguages`。系统 LaunchScreen 以英文 Base 文案为回退，并用 `zh-Hans.lproj/LaunchScreen.strings` 与 `zh-Hant.lproj/LaunchScreen.strings` 覆盖两种中文。

**Tech Stack:** Swift 5、UIKit、Xcode String Catalog、SnapKit、YYText、XCTest、CocoaPods

**Spec:** `docs/superpowers/specs/2026-09-02-app-localization-design.md`

## Global Constraints

- 英文是 `developmentRegion`、源语言和不支持语言的回退；新增 `zh-Hans` 与通用 `zh-Hant`，不拆分 `zh-TW`/`zh-HK`。
- 生产代码不得设置或覆盖 `AppleLanguages`，不得新增 App 内语言切换入口。
- `audioResource`、`backgroundResource`、声音顺序、最近播放存储值、URL、邮箱、UserDefaults key、通知 identifier 和 accessibility identifier 保持原值。
- `IsleWhispers` 品牌名、音频/图片文件名和技术诊断文本不翻译。
- 所有可见文本、VoiceOver、通知、Now Playing、邮件主题和错误状态都必须来自本地化资源；每个 Catalog key 必须同时有 `en`、`zh-Hans`、`zh-Hant` 的非空值。
- 不修改 `Pods/`，不通过关闭项目级警告掩盖 YYText 1.0.7 的上游弃用警告。
- 每个任务先运行指定 RED 测试并确认按预期失败，再做最小实现并运行 GREEN；只暂存该任务列出的文件，提交信息使用中文。
- 所有命令从 `/Users/db/Documents/git/my/IsleWhispers/IsleWhispers/.worktrees/launch-agreement-rich-text/IsleWhispers` 执行。

---

### Task 1: 建立本地化基础、完整 Catalog 与英文回退

**Files:**

- Create: `IsleWhispers/Localization/L10n.swift`
- Create: `IsleWhispers/Localizable.xcstrings`
- Create: `../IsleWhispersTests/LocalizationTests.swift`
- Create: `../IsleWhispersTests/LocalizationTestSupport.swift`
- Modify: `IsleWhispers.xcodeproj/project.pbxproj`

- [ ] **Step 1: 写 Catalog 配置与访问层的失败测试**

在 `LocalizationTestSupport.swift` 增加唯一的测试 Bundle 入口，避免各测试自行修改全局语言：

```swift
import Foundation
import XCTest

enum LocalizationTestSupport {
    static func bundle(_ language: String, appBundle: Bundle = .main) throws -> Bundle {
        let path = try XCTUnwrap(appBundle.path(forResource: language, ofType: "lproj"))
        return try XCTUnwrap(Bundle(path: path))
    }
}
```

在 `LocalizationTests.swift` 先覆盖：

```swift
final class LocalizationTests: XCTestCase {
func testEnglishIsDevelopmentLanguageAndBothChineseLocalesArePackaged() throws
func testAllThreeLocalesHaveIdenticalNonemptyKeys() throws
    func testUnsupportedLanguageResolutionFallsBackToEnglish() throws
    func testFormattingUsesInjectedBundleAndLocale() throws
}
```

测试要断言：

- `Bundle.main.object(forInfoDictionaryKey: "CFBundleDevelopmentRegion") as? String == "en"`。
- `en.lproj`、`zh-Hans.lproj` 和 `zh-Hant.lproj` 均能从 App Bundle 解析。
- 读取源码 `Localizable.xcstrings` 后，三种语言的 key 集合完全一致且值非空。
- `L10n.bundle(for: "fr", in: .main)` 返回英文 lproj；`zh-Hans` 返回简体中文 Bundle，`zh-Hant` 返回繁體中文 Bundle。
- 英文 `about.version.format` 格式化为 `Version 1.2.3`，简体中文为 `版本 1.2.3`，繁體中文为 `版本 1.2.3`。
- 英文 `timer.duration.minutes` 在 1/2 时分别为 `1 minute`/`2 minutes`；简体中文为 `1 分钟`/`2 分钟`；繁體中文为 `1 分鐘`/`2 分鐘`。

- [ ] **Step 2: 运行 RED，确认缺少 `L10n`/Catalog/两种中文资源**

```bash
xcodebuild -workspace IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  -parallel-testing-enabled NO \
  -only-testing:IsleWhispersTests/LocalizationTests test CODE_SIGNING_ALLOWED=NO
```

Expected: 编译因 `L10n` 不存在而失败，或测试因 `zh-Hans.lproj`、`zh-Hant.lproj` 或 Catalog 不存在而失败；不得把环境启动失败当作 RED。

- [ ] **Step 3: 实现最小 `L10n`**

`L10n.swift` 保持无状态，不缓存语言：

```swift
import Foundation

enum L10n {
    static func text(_ key: String, bundle: Bundle = .main) -> String {
        bundle.localizedString(forKey: key, value: nil, table: "Localizable")
    }

    static func format(
        _ key: String,
        bundle: Bundle = .main,
        _ arguments: CVarArg...
    ) -> String {
        let language = bundle.preferredLocalizations.first ?? "en"
        return String(
            format: text(key, bundle: bundle),
            locale: Locale(identifier: language),
            arguments: arguments
        )
    }

    static func plural(_ key: String, count: Int, bundle: Bundle = .main) -> String {
        String.localizedStringWithFormat(text(key, bundle: bundle), count)
    }

    static func bundle(for language: String, in appBundle: Bundle = .main) -> Bundle {
        let path = appBundle.path(forResource: language, ofType: "lproj")
            ?? appBundle.path(forResource: "en", ofType: "lproj")
        return path.flatMap(Bundle.init(path:)) ?? appBundle
    }
}
```

生产调用仅使用默认 `.main`；`bundle(for:in:)` 仅提供确定性的预览和测试注入，不参与 App 语言偏好管理。

- [ ] **Step 4: 建立完整 key 清单和翻译**

`Localizable.xcstrings` 设置 `sourceLanguage: "en"`，为以下 key 提供完整 `en` / `zh-Hans` / `zh-Hant`。英文、简体中文与繁體中文值按表执行；格式参数保留在 Catalog 中，调用方不得拼接语序。

| Key | English | 简体中文 |
|---|---|---|
| `common.ok` | OK | 知道了 |
| `common.cancel` | Cancel | 取消 |
| `common.retry` | Retry | 重试 |
| `common.content_unavailable.title` | Coming Soon | 内容准备中 |
| `common.content_unavailable.message.format` | %@ will be available before release. | %@将在正式发布前补充。 |
| `launch.subtitle` | Listen to nature. Be here now. | 聆听自然，放松此刻 |
| `launch.agreement.title` | Welcome to IsleWhispers | 欢迎使用 IsleWhispers |
| `launch.agreement.body` | Please read and agree to the Terms of Use and Privacy Policy to continue. | 请阅读并同意《用户协议》和《隐私政策》后继续使用。 |
| `launch.agreement.terms` | Terms of Use | 用户协议 |
| `launch.agreement.privacy` | Privacy Policy | 隐私政策 |
| `launch.agreement.accept` | Agree & Continue | 同意并继续 |
| `launch.agreement.decline` | Not Now | 暂不同意 |
| `launch.agreement.required.title` | Agreement Required | 需要同意后继续 |
| `launch.agreement.required.message` | Please read and agree to the Terms of Use and Privacy Policy to continue using IsleWhispers. | 请阅读并同意用户协议和隐私政策后继续使用 IsleWhispers。 |
| `launch.agreement.open_terms` | Open Terms of Use | 打开用户协议 |
| `launch.agreement.open_privacy` | Open Privacy Policy | 打开隐私政策 |
| `tab.home` | Home | 首页 |
| `tab.sounds` | Sounds | 声音 |
| `tab.settings` | Settings | 设置 |
| `home.greeting` | Now · Hear the island | 此刻 · 听见岛屿 |
| `home.action.mute` | Mute | 静音 |
| `home.action.unmute` | Unmute | 恢复声音 |
| `home.action.recent` | Recent Sounds | 最近播放 |
| `home.action.open_player` | Open Player | 打开播放页 |
| `home.action.play_and_open` | Play and Open Player | 开始播放并打开播放页 |
| `home.mute.on` | Muted | 已静音 |
| `home.mute.off` | Sound On | 声音开启 |
| `home.retry.hint` | Reload the current sound | 重新载入当前声音 |
| `carousel.label` | Ambient sounds | 环境声音 |
| `carousel.position.format` | %@, %lld of %lld | %@，%lld / %lld |
| `sound.accessibility.title_subtitle.format` | %@: %@ | %@：%@ |
| `recent.title` | Recent Sounds | 最近播放 |
| `recent.list.label` | Recent sounds list | 最近播放列表 |
| `recent.close` | Close Recent Sounds | 关闭最近播放 |
| `recent.empty.title` | No Recent Sounds Yet | 还没有最近播放 |
| `recent.empty.detail` | Sounds you play will appear here. | 播放声音后会出现在这里 |
| `library.title` | Sound Library | 声音库 |
| `library.list.label` | Sound library | 声音库 |
| `focus.sound_picker.label` | Change Sound | 切换声音 |
| `focus.sound_picker.current.format` | Change sound. Current: %@ | 切换声音，当前%@ |
| `focus.sound_picker.hint` | Open sound selection | 打开声音选择 |
| `focus.countdown.label` | Set Timer | 设置倒计时 |
| `focus.close` | Close Player | 关闭播放页 |
| `focus.play` | Resume Playback | 继续播放 |
| `focus.pause` | Pause Playback | 暂停播放 |
| `focus.retry.label` | Retry Playback | 重试播放 |
| `focus.countdown.unlimited` | No Limit | 不限时 |
| `focus.countdown.remaining.format` | Remaining: %@ | 剩余 %@ |
| `focus.countdown.ended` | Timer Ended | 倒计时已结束 |
| `focus.timer.sheet.title` | Set Timer | 设置倒计时 |
| `timer.option.unlimited` | No Limit | 不限时 |
| `timer.option.short_unlimited` | No Limit | 不限 |
| `timer.option.minutes15` | 15 Minutes | 15 分钟 |
| `timer.option.minutes30` | 30 Minutes | 30 分钟 |
| `timer.option.minutes60` | 60 Minutes | 60 分钟 |
| `timer.duration.minutes_seconds.format` | %1$lld min %2$lld sec | %1$lld 分 %2$lld 秒 |
| `timer.accessibility.option.format` | Sleep timer: %@ | 睡眠定时：%@ |
| `player.status.ready` | Ready | 准备就绪 |
| `player.status.session_unavailable` | Audio Session Unavailable | 音频会话不可用 |
| `player.status.playback_failed` | Playback Failed | 音频播放失败 |
| `player.status.decode_failed` | Audio Decode Failed | 音频解码失败 |
| `player.status.resource_unavailable` | Audio Unavailable | 音频资源不可用 |
| `notification.playback_ended.title` | Playback Ended | 播放已结束 |
| `settings.title` | Settings | 设置 |
| `settings.subtitle` | Learn about the app, get help, and contact support. | 了解应用信息，获取帮助与联系支持 |
| `settings.about.title` | About IsleWhispers | 关于 IsleWhispers |
| `settings.about.detail` | Version, Privacy Policy, and Terms of Use | 版本、隐私政策与使用条款 |
| `settings.help.title` | Help & Feedback | 帮助与反馈 |
| `settings.help.detail` | FAQs and Support Email | 常见问题与联系邮箱 |
| `about.title` | About IsleWhispers | 关于 IsleWhispers |
| `about.tagline` | Ambient sounds for focus, relaxation, and sleep | 专注、放松与睡眠的环境声音播放器 |
| `about.version.format` | Version %@ | 版本 %@ |
| `about.local_privacy` | Sound selection, recent history, and timer preferences stay on this device. The app does not upload audio, create user accounts, or track you. | 声音选择、最近播放和计时偏好仅保存在本机。应用不会上传音频、建立用户账户或用于跟踪。 |
| `about.privacy` | Privacy Policy | 隐私政策 |
| `about.terms` | Terms of Use | 使用条款 |
| `help.title` | Help & Feedback | 帮助与反馈 |
| `help.faq.title` | Frequently Asked Questions | 常见问题 |
| `help.faq.playback.question` | How do I change sounds? | 如何切换声音？ |
| `help.faq.playback.answer` | Swipe left or right on Home, or choose a sound from the library. | 在首页左右滑动，或从声音列表选择。 |
| `help.faq.timer.question` | How does the timer work? | 倒计时如何工作？ |
| `help.faq.timer.answer` | Choose No Limit, 15, 30, or 60 minutes. The timer pauses when playback pauses. | 可选择不限时、15、30、60 分钟；暂停时倒计时同步暂停。 |
| `help.faq.background.question` | How do I play in the background? | 如何后台播放？ |
| `help.faq.background.answer` | Start playback, then leave the app. You can pause or resume from Control Center. | 开始播放后可切到后台，也可在控制中心暂停或继续。 |
| `help.faq.notifications.question` | Why did I not receive a notification? | 为什么没有通知？ |
| `help.faq.notifications.answer` | Allow IsleWhispers notifications in System Settings. | 请在系统设置中允许 IsleWhispers 发送通知。 |
| `help.contact.title` | Contact Support | 联系支持 |
| `help.action.email` | Send Email | 发送邮件 |
| `help.action.copy_email` | Copy Email | 复制邮箱 |
| `help.action.website` | Online Help | 在线帮助 |
| `help.email.subject` | IsleWhispers Help & Feedback | IsleWhispers 帮助与反馈 |
| `help.email.no_app` | No mail app was found. The email address was copied. | 未找到邮件应用，邮箱地址已复制。 |
| `help.email.copied` | The email address was copied. | 邮箱地址已复制。 |
| `help.email.copied.title` | Email Copied | 邮箱已复制 |
| `help.website.unavailable` | Online help will be available before release. | 在线帮助将在正式发布前补充。 |

以下为同一组 key 必须写入 Catalog 的 `zh-Hant` 值；表中值均为通用繁體中文，不按地区拆分，不能以简体中文值或自动转换替代。

| Key | 繁體中文（`zh-Hant`） |
|---|---|
| `common.ok` | 好 |
| `common.cancel` | 取消 |
| `common.retry` | 重試 |
| `common.content_unavailable.title` | 內容準備中 |
| `common.content_unavailable.message.format` | %@ 將在正式發布前補充。 |
| `launch.subtitle` | 聆聽自然，放鬆此刻 |
| `launch.agreement.title` | 歡迎使用 IsleWhispers |
| `launch.agreement.body` | 請閱讀並同意《使用者協議》和《隱私權政策》後繼續使用。 |
| `launch.agreement.terms` | 使用者協議 |
| `launch.agreement.privacy` | 隱私權政策 |
| `launch.agreement.accept` | 同意並繼續 |
| `launch.agreement.decline` | 暫不同意 |
| `launch.agreement.required.title` | 需要同意後繼續 |
| `launch.agreement.required.message` | 請閱讀並同意使用者協議和隱私權政策後繼續使用 IsleWhispers。 |
| `launch.agreement.open_terms` | 開啟使用者協議 |
| `launch.agreement.open_privacy` | 開啟隱私權政策 |
| `tab.home` | 首頁 |
| `tab.sounds` | 聲音 |
| `tab.settings` | 設定 |
| `home.greeting` | 此刻 · 聽見島嶼 |
| `home.action.mute` | 靜音 |
| `home.action.unmute` | 恢復聲音 |
| `home.action.recent` | 最近播放 |
| `home.action.open_player` | 開啟播放頁 |
| `home.action.play_and_open` | 開始播放並開啟播放頁 |
| `home.mute.on` | 已靜音 |
| `home.mute.off` | 聲音已開啟 |
| `home.retry.hint` | 重新載入目前聲音 |
| `carousel.label` | 環境聲音 |
| `carousel.position.format` | %@，%lld / %lld |
| `sound.accessibility.title_subtitle.format` | %@：%@ |
| `recent.title` | 最近播放 |
| `recent.list.label` | 最近播放列表 |
| `recent.close` | 關閉最近播放 |
| `recent.empty.title` | 尚無最近播放 |
| `recent.empty.detail` | 你播放過的聲音會顯示在這裡。 |
| `library.title` | 聲音庫 |
| `library.list.label` | 聲音庫 |
| `focus.sound_picker.label` | 切換聲音 |
| `focus.sound_picker.current.format` | 切換聲音，目前為 %@ |
| `focus.sound_picker.hint` | 開啟聲音選擇 |
| `focus.countdown.label` | 設定倒數計時 |
| `focus.close` | 關閉播放頁 |
| `focus.play` | 繼續播放 |
| `focus.pause` | 暫停播放 |
| `focus.retry.label` | 重試播放 |
| `focus.countdown.unlimited` | 不限時 |
| `focus.countdown.remaining.format` | 剩餘 %@ |
| `focus.countdown.ended` | 倒數計時已結束 |
| `focus.timer.sheet.title` | 設定倒數計時 |
| `timer.option.unlimited` | 不限時 |
| `timer.option.short_unlimited` | 不限 |
| `timer.option.minutes15` | 15 分鐘 |
| `timer.option.minutes30` | 30 分鐘 |
| `timer.option.minutes60` | 60 分鐘 |
| `timer.duration.minutes_seconds.format` | %1$lld 分 %2$lld 秒 |
| `timer.accessibility.option.format` | 睡眠計時：%@ |
| `player.status.ready` | 準備就緒 |
| `player.status.session_unavailable` | 音訊工作階段無法使用 |
| `player.status.playback_failed` | 音訊播放失敗 |
| `player.status.decode_failed` | 音訊解碼失敗 |
| `player.status.resource_unavailable` | 音訊資源無法使用 |
| `notification.playback_ended.title` | 播放已結束 |
| `settings.title` | 設定 |
| `settings.subtitle` | 了解 App 資訊、取得協助並聯絡支援。 |
| `settings.about.title` | 關於 IsleWhispers |
| `settings.about.detail` | 版本、隱私權政策與使用者協議 |
| `settings.help.title` | 說明與意見回饋 |
| `settings.help.detail` | 常見問題與支援信箱 |
| `about.title` | 關於 IsleWhispers |
| `about.tagline` | 為專注、放鬆與睡眠而設的環境聲音播放器 |
| `about.version.format` | 版本 %@ |
| `about.local_privacy` | 聲音選擇、最近播放和計時偏好只會保留在這部裝置上。App 不會上傳音訊、建立使用者帳號或追蹤你。 |
| `about.privacy` | 隱私權政策 |
| `about.terms` | 使用者協議 |
| `help.title` | 說明與意見回饋 |
| `help.faq.title` | 常見問題 |
| `help.faq.playback.question` | 如何切換聲音？ |
| `help.faq.playback.answer` | 在首頁向左或向右滑動，或從聲音庫選擇聲音。 |
| `help.faq.timer.question` | 倒數計時如何運作？ |
| `help.faq.timer.answer` | 可選擇不限時、15、30 或 60 分鐘；暫停播放時，倒數計時也會暫停。 |
| `help.faq.background.question` | 如何在背景播放？ |
| `help.faq.background.answer` | 開始播放後即可離開 App，也可從控制中心暫停或繼續播放。 |
| `help.faq.notifications.question` | 為什麼沒有收到通知？ |
| `help.faq.notifications.answer` | 請在系統設定中允許 IsleWhispers 傳送通知。 |
| `help.contact.title` | 聯絡支援 |
| `help.action.email` | 傳送電子郵件 |
| `help.action.copy_email` | 複製電子郵件地址 |
| `help.action.website` | 線上說明 |
| `help.email.subject` | IsleWhispers 說明與意見回饋 |
| `help.email.no_app` | 找不到郵件 App，已複製電子郵件地址。 |
| `help.email.copied` | 已複製電子郵件地址。 |
| `help.email.copied.title` | 已複製電子郵件地址 |
| `help.website.unavailable` | 線上說明將在正式發布前補充。 |

声音 key 完整加入：`sound.category.nature/life/atmosphere`，以及 `tea`、`thunder`、`rain`、`fire`、`water`、`wind`、`day`、`night`、`river`、`space`、`yacht`、`train`、`farm`、`chimes`、`whale` 每个 slug 的 `.title` 与 `.subtitle`。三类中文为 `自然`、`生活`、`氛围`，英文为 `Nature`、`Everyday`、`Atmosphere`。15 组文案精确使用：

```text
tea: Tea — Quiet cups and a gentle tea ritual | 茶香 — 茶与安静器皿
thunder: Thunder — A deep rumble in the distance | 雷声 — 低沉而遥远
rain: Rain — A steady rhythm against the window | 雨声 — 均匀落在窗边
fire: Fireplace — Soft crackling firewood | 火炉 — 轻柔木柴噼啪
water: Flowing Water — A calm, continuous stream | 水流 — 舒缓连续水声
wind: Wind — Air moving slowly around you | 风声 — 空气缓慢流动
day: Daylight — A bright natural soundscape | 白昼 — 明亮自然环境
night: Night — A quiet late-night ambience | 夜晚 — 深夜低噪氛围
river: River — Clear water flowing in gentle patterns | 河流 — 清澈而连续的水纹
space: Space — A wide, weightless ambience | 太空 — 宽阔漂浮氛围
yacht: Yacht — Sea breeze and the soft creak of a boat | 游艇 — 海面与船体轻响
train: Train — A steady rhythm for a long journey | 火车 — 规律远行节奏
farm: Farm — An open countryside soundscape | 农场 — 开阔乡间声景
chimes: Wind Chimes — Clear, occasional echoes | 风铃 — 清脆稀疏回响
whale: Whale Song — Long, low calls from the deep | 鲸歌 — 深海悠长低吟
```

`zh-Hant` 声音分类必须精确为 `自然`、`日常`、`氛圍`；15 组声音 title/subtitle 必须精确使用：

```text
tea: 茶香 — 茶與安靜器皿
thunder: 雷聲 — 低沉而遙遠
rain: 雨聲 — 均勻落在窗邊
fire: 壁爐 — 輕柔木柴劈啪聲
water: 流水 — 舒緩不斷的水流
wind: 風聲 — 空氣緩緩流動
day: 白晝 — 明亮的自然聲景
night: 夜晚 — 深夜的安靜氛圍
river: 河流 — 清澈水流的柔和節奏
space: 太空 — 寬闊無重力的氛圍
yacht: 遊艇 — 海風與船身的輕微吱呀聲
train: 火車 — 漫長旅途的穩定節奏
farm: 農場 — 開闊的鄉間聲景
chimes: 風鈴 — 清澈而偶爾響起的回聲
whale: 鯨歌 — 來自深海的悠長低鳴
```

`timer.duration.minutes` 与 `timer.duration.seconds` 使用 String Catalog plural variations；英文分别提供 one/other（`%lld minute(s)`、`%lld second(s)`），简体中文 one/other 都使用 `%lld 分钟`、`%lld 秒`，繁體中文 one/other 都使用 `%lld 分鐘`、`%lld 秒`。

- [ ] **Step 5: 配置工程语言区域**

在 `project.pbxproj` 保持 `developmentRegion = en;`，把 `knownRegions` 改为：

```text
knownRegions = (
    en,
    Base,
    "zh-Hans",
    "zh-Hant",
);
```

不手工添加文件引用；工程使用 `PBXFileSystemSynchronizedRootGroup`，新增资源和 Swift 文件会自动加入 App/Test target。

- [ ] **Step 6: 运行 GREEN 和资源产物检查**

重复 Step 2，Expected: `LocalizationTests` 全部通过。然后：

```bash
xcodebuild -workspace IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/islewhispers-localization-derived-data \
  build CODE_SIGNING_ALLOWED=NO
test -f /tmp/islewhispers-localization-derived-data/Build/Products/Debug-iphonesimulator/IsleWhispers.app/en.lproj/Localizable.strings
test -f /tmp/islewhispers-localization-derived-data/Build/Products/Debug-iphonesimulator/IsleWhispers.app/zh-Hans.lproj/Localizable.strings
test -f /tmp/islewhispers-localization-derived-data/Build/Products/Debug-iphonesimulator/IsleWhispers.app/zh-Hant.lproj/Localizable.strings
```

Expected: build 成功且三个编译后的 `Localizable.strings` 都存在。

- [ ] **Step 7: 提交基础设施**

```bash
git add IsleWhispers/Localization/L10n.swift IsleWhispers/Localizable.xcstrings \
  ../IsleWhispersTests/LocalizationTests.swift ../IsleWhispersTests/LocalizationTestSupport.swift \
  IsleWhispers.xcodeproj/project.pbxproj
git commit -m "功能：建立英文默认的本地化基础"
```

---

### Task 2: 本地化声音模型并保持稳定身份

**Files:**

- Modify: `IsleWhispers/Models/Sound.swift`
- Modify: `../IsleWhispersTests/SoundCatalogGroupingTests.swift`
- Modify: `../IsleWhispersTests/RecentSoundsStoreTests.swift`

- [ ] **Step 1: 为三语元数据和身份不变写 RED 测试**

在 `SoundCatalogGroupingTests` 增加：

```swift
func testCatalogReturnsAllEnglishSimplifiedAndTraditionalChineseMetadata() throws
func testCategoryTitlesUseInjectedLanguageBundle() throws
func testLocalizedDisplayDoesNotChangeStableResourceIdentity() throws
```

测试使用 `LocalizationTestSupport.bundle("en")`、`bundle("zh-Hans")` 与 `bundle("zh-Hant")`，精确断言 15 个英文、15 个简体中文、15 个繁體中文标题、三个语言版本的分类值，以及每项的 `id/audioResource/backgroundResource/category` 在三种语言读取前后完全相同。把原 `map(\.title)` 的中文分组断言改为按 `title(bundle:)` 显式验证。

在 `RecentSoundsStoreTests` 增加：保存 `2_sound_rain` 后分别用英文、简体中文、繁體中文 Bundle 重新解析，ID 仍为 `2_sound_rain`，显示为 `Rain`/`雨声`/`雨聲`。

- [ ] **Step 2: 运行 RED**

```bash
xcodebuild -workspace IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  -parallel-testing-enabled NO \
  -only-testing:IsleWhispersTests/SoundCatalogGroupingTests \
  -only-testing:IsleWhispersTests/RecentSoundsStoreTests test CODE_SIGNING_ALLOWED=NO
```

Expected: 因 `title(bundle:)`/`category.title(bundle:)` 不存在而编译失败。

- [ ] **Step 3: 将存储文案改为稳定 key**

`SoundCategory` raw value 改为稳定英文 identifier：

```swift
enum SoundCategory: String, CaseIterable, Sendable {
    case nature
    case life
    case atmosphere

    var title: String { title(bundle: .main) }
    func title(bundle: Bundle) -> String {
        L10n.text("sound.category.\(rawValue)", bundle: bundle)
    }
}
```

`Sound` 只存 slug 与资源身份，显示文案按需读取：

```swift
struct Sound: Equatable, Hashable, Sendable, Identifiable {
    let localizationKey: String
    let audioResource: String
    let backgroundResource: String
    let category: SoundCategory

    var id: String { audioResource }
    var title: String { title(bundle: .main) }
    var subtitle: String { subtitle(bundle: .main) }

    func title(bundle: Bundle) -> String {
        L10n.text("sound.\(localizationKey).title", bundle: bundle)
    }

    func subtitle(bundle: Bundle) -> String {
        L10n.text("sound.\(localizationKey).subtitle", bundle: bundle)
    }
}
```

15 个 catalog 项只把 `title/subtitle` 替换为确定 slug；资源名、顺序和分类不变。不要把 Bundle 存入 `Sound`，以保持 `Sendable` 和稳定 Hashable 语义。

- [ ] **Step 4: 运行 GREEN 与现有持久化回归**

重复 Step 2。Expected: 两组测试全部通过，三语元数据与 15 个 CAF 解析测试仍通过。

- [ ] **Step 5: 提交模型迁移**

```bash
git add IsleWhispers/Models/Sound.swift \
  ../IsleWhispersTests/SoundCatalogGroupingTests.swift \
  ../IsleWhispersTests/RecentSoundsStoreTests.swift
git commit -m "功能：本地化声音与分类元数据"
```

---

### Task 3: 本地化播放服务、通知与 Now Playing

**Files:**

- Modify: `IsleWhispers/Services/AudioPlayerService.swift`
- Modify: `IsleWhispers/Services/PlaybackEndNotificationScheduler.swift`
- Modify: `../IsleWhispersTests/AudioPlayerPersistenceTests.swift`
- Modify: `../IsleWhispersTests/PlaybackEndNotificationSchedulerTests.swift`

- [ ] **Step 1: 写服务层 RED 测试**

新增/调整测试覆盖：

```swift
func testPlaybackStatusesUseInjectedEnglishSimplifiedAndTraditionalChineseBundles() throws
func testPlaybackStatusIdentityDoesNotDependOnLocalizedCopy() throws
func testNowPlayingMetadataUsesInjectedLocalizedSoundCopy() throws
func testPlaybackEndNotificationTitleUsesInjectedBundle() throws
```

为 `AudioPlayerService` 测试初始化新增 `localizationBundle:`；依次触发准备成功、缺资源、解码失败的可控路径，断言英文、简体中文、繁體中文状态。Now Playing 不直接读取全局 `MPNowPlayingInfoCenter`：把现有写入字典的内部组装提取为 `nowPlayingInfo()`（internal、`@MainActor`），测试三语 title/albumTitle 等显示字段，远程控制行为保持原样。通知测试以注入 bundle 的 scheduler 断言三语 content title；stable request identifier 仍精确为 `isleWhispers.playbackEnded`。

- [ ] **Step 2: 运行 RED**

```bash
xcodebuild -workspace IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  -parallel-testing-enabled NO \
  -only-testing:IsleWhispersTests/AudioPlayerPersistenceTests \
  -only-testing:IsleWhispersTests/PlaybackEndNotificationSchedulerTests test CODE_SIGNING_ALLOWED=NO
```

Expected: `localizationBundle:` 或本地化通知/Now Playing API 尚不存在而失败。

- [ ] **Step 3: 注入 Bundle 并替换服务文案**

为 `AudioPlayerService.init` 增加 `localizationBundle: Bundle = .main`，保存为只读属性。把显示文字与可判断状态分离，避免页面用翻译文本做流程判断：

```swift
enum AudioPlayerStatus: Equatable, Sendable {
    case ready
    case sessionUnavailable
    case playbackFailed
    case decodeFailed
    case resourceUnavailable

    var localizationKey: String {
        switch self {
        case .ready: return "player.status.ready"
        case .sessionUnavailable: return "player.status.session_unavailable"
        case .playbackFailed: return "player.status.playback_failed"
        case .decodeFailed: return "player.status.decode_failed"
        case .resourceUnavailable: return "player.status.resource_unavailable"
        }
    }
}
```

服务保存 `private(set) var status: AudioPlayerStatus`，`statusMessage` 改为用实例 Bundle 读取 `status.localizationKey` 的计算属性。所有旧 `statusMessage = "…"` 改为赋对应 status case；初始值为 `.ready`。`updateNowPlayingInfo` 通过 `currentSound.title(bundle:)` 和 `subtitle(bundle:)` 生成元数据。

为 `LocalPlaybackEndNotificationScheduler.init` 增加 `localizationBundle: Bundle = .main`，删除硬编码 `notificationTitle` 常量，增加：

```swift
static func notificationTitle(bundle: Bundle = .main) -> String {
    L10n.text("notification.playback_ended.title", bundle: bundle)
}
```

实际 `UNMutableNotificationContent.title` 使用实例注入 Bundle。不得改变授权、generation token、deadline 和取消逻辑。

- [ ] **Step 4: 运行 GREEN 和定时器/中断回归**

重复 Step 2。Expected: 测试全绿，原有中断、路由移除、远程控制、定时通知测试无行为变化。

- [ ] **Step 5: 提交服务本地化**

```bash
git add IsleWhispers/Services/AudioPlayerService.swift \
  IsleWhispers/Services/PlaybackEndNotificationScheduler.swift \
  ../IsleWhispersTests/AudioPlayerPersistenceTests.swift \
  ../IsleWhispersTests/PlaybackEndNotificationSchedulerTests.swift
git commit -m "功能：本地化播放状态与结束通知"
```

---

### Task 4: 本地化 Launch、协议富文本与系统 LaunchScreen

**Files:**

- Modify: `IsleWhispers/ViewControllers/LaunchViewController.swift`
- Modify: `IsleWhispers/Base.lproj/LaunchScreen.storyboard`
- Create: `IsleWhispers/zh-Hans.lproj/LaunchScreen.strings`
- Create: `IsleWhispers/zh-Hant.lproj/LaunchScreen.strings`
- Modify: `../IsleWhispersTests/AppLaunchCoordinatorTests.swift`
- Modify: `../IsleWhispersTests/AppConfigurationTests.swift`

- [ ] **Step 1: 写英文、简体中文、繁體中文协议和 LaunchScreen RED 测试**

把 Launch 测试构造器统一扩展为可传 `localizationBundle:`，新增：

```swift
func testAgreementCopyAndActionsAreLocalizedInAllThreeLanguages() throws
func testAgreementHighlightsBothLocalizedDocumentNames() throws
func testAgreementVoiceOverActionsUseLocalizedNames() throws
func testEnglishAgreementActionsRemainReachableAt320By568WithAccessibilityText() throws
func testSimplifiedChineseLaunchScreenOverrideExists() throws
func testTraditionalChineseLaunchScreenOverrideExists() throws
```

英文断言完整 body 中包含 `Terms of Use` 与 `Privacy Policy`，简体中文断言包含 `用户协议` 与 `隐私政策`，繁體中文断言包含 `使用者協議` 与 `隱私權政策`；三种语言的 YYText highlight range 都非空、点击仍分别打开同一个 terms/privacy URL，VoiceOver custom actions 名称匹配当前 Bundle。每种语言均断言正文中的协议名称与各自的 `launch.agreement.terms`、`launch.agreement.privacy` 值完全一致。小屏测试继续查按钮位于 scroll content 内且可滚动到达，不用固定字符串宽度。

`AppConfigurationTests` 将 Base LaunchScreen 期望改为英文 `Listen to nature. Be here now.`，并读取 `zh-Hans.lproj/LaunchScreen.strings` 验证 `"lch-sub-txt.text" = "聆听自然，放松此刻";`，读取 `zh-Hant.lproj/LaunchScreen.strings` 验证 `"lch-sub-txt.text" = "聆聽自然，放鬆此刻";`。

- [ ] **Step 2: 运行 RED**

```bash
xcodebuild -workspace IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  -parallel-testing-enabled NO \
  -only-testing:IsleWhispersTests/AppLaunchCoordinatorTests \
  -only-testing:IsleWhispersTests/AppConfigurationTests test CODE_SIGNING_ALLOWED=NO
```

Expected: 英文 Launch/协议断言失败，或因 `localizationBundle:` 不存在而编译失败。

- [ ] **Step 3: 注入本地化并保持 YYText 交互**

`LaunchViewController.init` 增加 `localizationBundle: Bundle = .main`。标题、正文、按钮、拒绝提示、空链接提示、VoiceOver action 全部从 Task 1 key 读取。富文本必须先取得三个独立值再定位：

```swift
let message = L10n.text("launch.agreement.body", bundle: localizationBundle)
let terms = L10n.text("launch.agreement.terms", bundle: localizationBundle)
let privacy = L10n.text("launch.agreement.privacy", bundle: localizationBundle)
let addedTerms = addAgreementHighlight(terms, to: text) { [weak self] in self?.showTerms() }
let addedPrivacy = addAgreementHighlight(privacy, to: text) { [weak self] in self?.showPrivacy() }
assert(addedTerms && addedPrivacy, "Localized agreement body must contain both document names")
```

把 `addAgreementHighlight` 的返回值改为 `Bool`（找到并添加 highlight 时为 true），继续复用两个 URL 回调，不改变同意存储、延迟路由、设备上报时序。Debug assertion 提供开发期诊断；三语测试必须显式检查两个 range/highlight，资源缺失时测试失败而不是只依赖 assertion。

把 Base storyboard subtitle 改为英文回退；在 `zh-Hans.lproj/LaunchScreen.strings` 与 `zh-Hant.lproj/LaunchScreen.strings` 仅覆盖 subtitle object ID，品牌标题不重复翻译。两份文件分别精确写入 `"lch-sub-txt.text" = "聆听自然，放松此刻";` 和 `"lch-sub-txt.text" = "聆聽自然，放鬆此刻";`。

- [ ] **Step 4: 运行 GREEN 和 Launch 全套回归**

重复 Step 2。Expected: Launch/配置测试全部通过，协议首次启动与设备上报测试不变。

- [ ] **Step 5: 提交 Launch 本地化**

```bash
git add IsleWhispers/ViewControllers/LaunchViewController.swift \
  IsleWhispers/Base.lproj/LaunchScreen.storyboard \
  IsleWhispers/zh-Hans.lproj/LaunchScreen.strings \
  IsleWhispers/zh-Hant.lproj/LaunchScreen.strings \
  ../IsleWhispersTests/AppLaunchCoordinatorTests.swift \
  ../IsleWhispersTests/AppConfigurationTests.swift
git commit -m "功能：本地化启动页与协议弹窗"
```

---

### Task 5: 本地化首页、轮播、最近播放与 Tab Bar

**Files:**

- Modify: `IsleWhispers/ViewControllers/HomeViewController.swift`
- Modify: `IsleWhispers/ViewControllers/RecentSoundsViewController.swift`
- Modify: `IsleWhispers/ViewControllers/RootTabBarController.swift`
- Modify: `IsleWhispers/UI/InfiniteSoundCarousel.swift`
- Modify: `IsleWhispers/UI/RecentSoundCell.swift`
- Modify: `../IsleWhispersTests/HomeViewControllerTests.swift`
- Modify: `../IsleWhispersTests/InfiniteSoundCarouselTests.swift`
- Modify: `../IsleWhispersTests/RecentSoundsViewControllerTests.swift`
- Modify: `../IsleWhispersTests/RootTabBarControllerTests.swift`

- [ ] **Step 1: 写三语 UI 与 VoiceOver RED 测试**

各控制器/组件测试构造器增加注入 Bundle，新增：

```swift
func testHomeVisibleCopyAndAccessibilityUseEnglishBundle() throws
func testHomeVisibleCopyAndAccessibilityUseSimplifiedChineseBundle() throws
func testHomeVisibleCopyAndAccessibilityUseTraditionalChineseBundle() throws
func testCarouselAccessibilityValueUsesLocalizedSoundAndPosition() throws
func testRecentPageAndCellsUseInjectedLanguageBundle() throws
func testRootTabTitlesUseInjectedLanguageBundle() throws
```

通过已有 identifier 查 greeting、mute、recent、retry、play 控件；同时断言静音前后 label/value。Carousel 在边界增减后断言 `Rain, 3 of 15` / `雨声，3 / 15` / `雨聲，3 / 15`。最近播放验证三语标题、空状态、关闭按钮及 cell 的 title/accessible copy。Tab 分别断言 `Home/Sounds/Settings`、`首页/声音/设置` 与 `首頁/聲音/設定`；原 tab 背景、切换自动播放和最近记录测试继续保留。

- [ ] **Step 2: 运行 RED**

```bash
xcodebuild -workspace IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  -parallel-testing-enabled NO \
  -only-testing:IsleWhispersTests/HomeViewControllerTests \
  -only-testing:IsleWhispersTests/InfiniteSoundCarouselTests \
  -only-testing:IsleWhispersTests/RecentSoundsViewControllerTests \
  -only-testing:IsleWhispersTests/RootTabBarControllerTests test CODE_SIGNING_ALLOWED=NO
```

Expected: 注入 API 不存在或英文断言仍读到中文而失败。

- [ ] **Step 3: 串起页面级 Bundle**

为 `RootTabBarController`、`HomeViewController`、`RecentSoundsViewController`、`InfiniteSoundCarousel` 增加 `localizationBundle: Bundle = .main`，Root 构造三个 tab 时把同一 Bundle 向下传递。`RecentSoundCell.configure` 改为：

```swift
func configure(sound: Sound, selected: Bool, localizationBundle: Bundle = .main) {
    let title = sound.title(bundle: localizationBundle)
    let subtitle = sound.subtitle(bundle: localizationBundle)
    titleLabel.text = title
    accessibilityLabel = L10n.format(
        "sound.accessibility.title_subtitle.format",
        bundle: localizationBundle,
        title,
        subtitle
    )
    // artwork、selected border 与 traits 保持现状
}
```

可见文本与 accessibility 从 Catalog 读取。Carousel 位置必须用 `carousel.position.format`，不要手写中文逗号。Home 不再以硬编码 `"准备就绪"` 判断状态，统一改为 `playerService.status == .ready`；只替换显示文字判断，不改变播放状态机。

- [ ] **Step 4: 运行 GREEN 与轮播交互回归**

重复 Step 2。Expected: 所列测试全绿，左右滑动、无限循环、自动播放、recent 记录、tab appearance 无回归。

- [ ] **Step 5: 提交首页链路本地化**

```bash
git add IsleWhispers/ViewControllers/HomeViewController.swift \
  IsleWhispers/ViewControllers/RecentSoundsViewController.swift \
  IsleWhispers/ViewControllers/RootTabBarController.swift \
  IsleWhispers/UI/InfiniteSoundCarousel.swift IsleWhispers/UI/RecentSoundCell.swift \
  ../IsleWhispersTests/HomeViewControllerTests.swift \
  ../IsleWhispersTests/InfiniteSoundCarouselTests.swift \
  ../IsleWhispersTests/RecentSoundsViewControllerTests.swift \
  ../IsleWhispersTests/RootTabBarControllerTests.swift
git commit -m "功能：本地化首页与最近播放"
```

---

### Task 6: 本地化声音列表及卡片

**Files:**

- Modify: `IsleWhispers/ViewControllers/SoundLibraryViewController.swift`
- Modify: `IsleWhispers/UI/LibrarySoundCardCell.swift`
- Modify: `../IsleWhispersTests/SoundLibraryViewControllerTests.swift`

- [ ] **Step 1: 写分组、卡片和英文布局 RED 测试**

新增：

```swift
func testEnglishLibraryUsesLocalizedTitleGroupsAndCards() throws
func testSimplifiedChineseLibraryUsesLocalizedTitleGroupsAndCards() throws
func testTraditionalChineseLibraryUsesLocalizedTitleGroupsAndCards() throws
func testEnglishCardsRemainReadableAt320WidthAndAccessibilitySize() throws
```

分别注入 en/zh-Hans/zh-Hant，断言标题、三个 section header、第一/最后卡片 title/subtitle/accessibility。繁體中文分类精确断言为 `自然`、`日常`、`氛圍`。英文及繁體中文小屏测试使用 320×568 与 `.accessibilityExtraExtraExtraLarge`，layout 后断言 collection content 可滚动、cell label 多行且所有可访问元素位于 cell bounds 内，不断言固定文本宽度。

- [ ] **Step 2: 运行 RED**

```bash
xcodebuild -workspace IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  -parallel-testing-enabled NO \
  -only-testing:IsleWhispersTests/SoundLibraryViewControllerTests test CODE_SIGNING_ALLOWED=NO
```

Expected: `localizationBundle:`/本地化 cell API 不存在或英文断言失败。

- [ ] **Step 3: 本地化列表并传递 Bundle 到复用 Cell**

`SoundLibraryViewController.init` 增加 `localizationBundle: Bundle = .main`；标题、collection accessibility、section header 使用 Catalog 与 `SoundCategory.title(bundle:)`。`LibrarySoundCardCell.configure` 增加同名 Bundle 参数并通过 `sound.title(bundle:)`/`subtitle(bundle:)` 设置显示和 accessibility。现有 self-sizing、两列/辅助字号一列、背景渐变、选中描边逻辑不变。

- [ ] **Step 4: 运行 GREEN**

重复 Step 2。Expected: 新旧 Library 测试全部通过。

- [ ] **Step 5: 提交声音列表本地化**

```bash
git add IsleWhispers/ViewControllers/SoundLibraryViewController.swift \
  IsleWhispers/UI/LibrarySoundCardCell.swift \
  ../IsleWhispersTests/SoundLibraryViewControllerTests.swift
git commit -m "功能：本地化声音列表与分组"
```

---

### Task 7: 本地化独立播放页与倒计时

**Files:**

- Modify: `IsleWhispers/ViewControllers/FocusPlaybackViewController.swift`
- Modify: `IsleWhispers/UI/SleepTimerView.swift`
- Modify: `../IsleWhispersTests/FocusPlaybackViewControllerTests.swift`
- Modify: `../IsleWhispersTests/HomeViewControllerTests.swift`

- [ ] **Step 1: 写倒计时格式、操作与布局 RED 测试**

替换现有 `testCountdownKeepsVisualClockAndUsesChineseVoiceOverDuration`，拆成：

```swift
func testCountdownKeepsVisualClockAndUsesEnglishVoiceOverDuration() throws
func testCountdownUsesSimplifiedChineseVoiceOverDuration() throws
func testCountdownUsesTraditionalChineseVoiceOverDuration() throws
func testTimerSheetAndPlaybackActionsUseInjectedLanguageBundle() throws
func testEnglishFocusControlsFitAt320By568AndMaximumAccessibilityText() throws
```

精确验证：

- 可见数字时钟仍为 `15:00`/`00:09`，不本地化数字结构。
- VoiceOver 分别为 `Remaining: 15 minutes`、`剩余 15 分钟`、`剩餘 15 分鐘`，1 minute/1 second 使用英文单数。
- unlimited/expired、播放/暂停、关闭、重试、切换声音与 action sheet 选项三语正确；繁體中文精确使用 `不限時`、`倒數計時已結束`、`繼續播放`、`暫停播放`、`關閉播放頁`、`重試播放`、`切換聲音`。
- 320×568 和 390×844 最大辅助字号下英文、简体中文与繁體中文关键按钮不相交，超高内容可通过现有滚动容器访问。

- [ ] **Step 2: 运行 RED**

```bash
xcodebuild -workspace IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  -parallel-testing-enabled NO \
  -only-testing:IsleWhispersTests/FocusPlaybackViewControllerTests \
  -only-testing:IsleWhispersTests/HomeViewControllerTests test CODE_SIGNING_ALLOWED=NO
```

Expected: 注入 API 不存在或英文/复数断言失败。

- [ ] **Step 3: 迁移 Focus 与 SleepTimerView 文案**

`FocusPlaybackViewController.init` 与 `SleepTimerView.init` 增加 `localizationBundle: Bundle = .main`。Home 创建 Focus 与 SleepTimerView 时传同一 Bundle；Focus 创建声音选择页时继续向 `SoundLibraryViewController` 传同一 Bundle。Focus 的就绪判断使用 Task 3 的 `playerService.status == .ready`，不比较 `statusMessage`。倒计时辅助文本遵循：

```swift
private func countdownAccessibilityDuration() -> String {
    let seconds = max(Int(ceil(playerService.sleepTimerRemaining ?? 0)), 0)
    let minutes = seconds / 60
    let remainder = seconds % 60
    if remainder == 0 {
        return L10n.plural("timer.duration.minutes", count: minutes, bundle: localizationBundle)
    }
    if minutes == 0 {
        return L10n.plural("timer.duration.seconds", count: remainder, bundle: localizationBundle)
    }
    return L10n.format(
        "timer.duration.minutes_seconds.format",
        bundle: localizationBundle,
        minutes,
        remainder
    )
}
```

可见 `mm:ss` 保持现有实现。Timer sheet 与 `SleepTimerView` 使用同一组选项 key，避免同一选项出现两套翻译。不得改变暂停冻结、恢复、到期清理、关闭不保存状态和本地通知排期行为。

- [ ] **Step 4: 运行 GREEN 与定时器回归**

重复 Step 2。Expected: Focus/Home 全部测试通过，无 timer 生命周期回归。

- [ ] **Step 5: 提交播放页本地化**

```bash
git add IsleWhispers/ViewControllers/FocusPlaybackViewController.swift \
  IsleWhispers/UI/SleepTimerView.swift \
  ../IsleWhispersTests/FocusPlaybackViewControllerTests.swift \
  ../IsleWhispersTests/HomeViewControllerTests.swift
git commit -m "功能：本地化播放页与倒计时"
```

---

### Task 8: 本地化设置、关于与帮助反馈

**Files:**

- Modify: `IsleWhispers/ViewControllers/SettingsViewController.swift`
- Modify: `IsleWhispers/ViewControllers/AboutViewController.swift`
- Modify: `IsleWhispers/ViewControllers/HelpFeedbackViewController.swift`
- Modify: `../IsleWhispersTests/SettingsViewControllerTests.swift`

- [ ] **Step 1: 写设置链路三语与小屏 RED 测试**

新增：

```swift
func testSettingsAboutAndHelpUseEnglishBundle() throws
func testSettingsAboutAndHelpUseSimplifiedChineseBundle() throws
func testSettingsAboutAndHelpUseTraditionalChineseBundle() throws
func testEnglishMailSubjectAndFallbackAlertsAreLocalized() throws
func testTraditionalChineseMailSubjectAndFallbackAlertsAreLocalized() throws
func testEnglishSettingsPagesRemainScrollableAt320By568WithAccessibilityText() throws
func testTraditionalChineseSettingsPagesRemainScrollableAt320By568WithAccessibilityText() throws
```

断言三语设置两行、About version/privacy/terms、四个 FAQ、联系按钮、mail subject、无邮件 App、空 H5 链接和复制成功提示。繁體中文需精确断言 `設定`、`關於 IsleWhispers`、`說明與意見回饋`、`IsleWhispers 說明與意見回饋`、`找不到郵件 App，已複製電子郵件地址。`。邮箱地址、URL 与 accessibility identifier 必须与改动前一致。小屏测试沿用当前 scroll view 检查，不要求所有长文一次显示在 viewport 中，只要求可滚动访问且按钮标题不被裁掉。

- [ ] **Step 2: 运行 RED**

```bash
xcodebuild -workspace IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  -parallel-testing-enabled NO \
  -only-testing:IsleWhispersTests/SettingsViewControllerTests test CODE_SIGNING_ALLOWED=NO
```

Expected: init 注入 API 不存在或英文断言失败。

- [ ] **Step 3: 迁移设置链路文案**

三个控制器 init 均增加 `localizationBundle: Bundle = .main`；Settings push About/Help 时继续传同一 Bundle。所有标题、详情、FAQ、链接占位提示、alert、按钮和邮件 subject 使用 Task 1 key；`supportEmail`、`AppSupportLinks` 和 URL 打开行为不变。About 版本必须用 `L10n.format("about.version.format", ...)`，内容缺失提示必须用 `common.content_unavailable.message.format`，不得用字符串插值拼接中英文句子。

- [ ] **Step 4: 运行 GREEN**

重复 Step 2。Expected: Settings 测试全绿，导航只 push 一次和 H5 空链接行为不变。

- [ ] **Step 5: 提交设置链路本地化**

```bash
git add IsleWhispers/ViewControllers/SettingsViewController.swift \
  IsleWhispers/ViewControllers/AboutViewController.swift \
  IsleWhispers/ViewControllers/HelpFeedbackViewController.swift \
  ../IsleWhispersTests/SettingsViewControllerTests.swift
git commit -m "功能：本地化设置与帮助页面"
```

---

### Task 9: 加入硬编码守卫并完成全量验证

**Files:**

- Modify: `../IsleWhispersTests/LocalizationTests.swift`
- Create: `docs/superpowers/reports/2026-09-02-app-localization-verification.md`

- [ ] **Step 1: 写生产 Swift 中文字面量守卫的 RED 测试**

在 `LocalizationTests` 增加：

```swift
func testChineseStringLiteralScannerReportsFileAndLineFromFixture()
func testProductionSwiftContainsNoUserFacingChineseStringLiterals()
```

先让 fixture 测试调用尚不存在的 test-only `chineseStringLiteralMatches(in:path:)` helper，输入 `label.text = "中文"` 并精确期待文件名、行号和字面量，从而形成真实 RED。随后在 `LocalizationTests.swift` 内实现 helper；生产扫描从 `#filePath` 解析 repo 根目录，递归扫描 `IsleWhispers/IsleWhispers/**/*.swift` 的字符串字面量。允许列表只包含明确不可本地化的技术值；本项目当前不需要任何中文生产字面量，因此初始 allowlist 为空。诊断输出文件与行号。不要为制造 RED 临时修改生产文件。

- [ ] **Step 2: 运行 RED 并清理遗漏**

```bash
xcodebuild -workspace IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  -parallel-testing-enabled NO \
  -only-testing:IsleWhispersTests/LocalizationTests test CODE_SIGNING_ALLOWED=NO
```

Expected: 若前 8 个任务遗漏中文用户文案，测试列出精确文件与行号。只修复扫描命中的用户可见字符串；注释和测试诊断不在扫描范围，技术标识不得伪装进 allowlist。

- [ ] **Step 3: 运行本地化定向测试**

```bash
xcodebuild -workspace IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  -parallel-testing-enabled NO \
  -only-testing:IsleWhispersTests/LocalizationTests \
  -only-testing:IsleWhispersTests/AppLaunchCoordinatorTests \
  -only-testing:IsleWhispersTests/SoundCatalogGroupingTests \
  -only-testing:IsleWhispersTests/HomeViewControllerTests \
  -only-testing:IsleWhispersTests/SoundLibraryViewControllerTests \
  -only-testing:IsleWhispersTests/FocusPlaybackViewControllerTests \
  -only-testing:IsleWhispersTests/SettingsViewControllerTests test CODE_SIGNING_ALLOWED=NO
```

Expected: 所列测试全部通过、0 skipped。

- [ ] **Step 4: 运行全量 XCTest、clean build 与静态检查**

```bash
xcodebuild -workspace IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  -parallel-testing-enabled NO test CODE_SIGNING_ALLOWED=NO
xcodebuild -workspace IsleWhispers.xcworkspace -scheme IsleWhispers \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/islewhispers-localization-derived-data \
  clean build CODE_SIGNING_ALLOWED=NO
rg -n '"[^"\n]*[\p{Han}][^"\n]*"' IsleWhispers --glob '*.swift'
rg -n 'AppleLanguages' IsleWhispers ../IsleWhispersTests
git diff --check
```

Expected: 全量测试和 build 成功；生产 Swift 中文扫描无输出；`AppleLanguages` 无输出；`git diff --check` 无输出。YYText 上游 warning 可存在，但不得出现新项目 warning/error。

- [ ] **Step 5: 做英文、简体中文、繁體中文运行时截图检查**

使用同一已构建 App，通过 Simulator 的“Settings → IsleWhispers → Preferred Language”或独立模拟器分别选择 English、简体中文与繁體中文；不要用 launch argument/UserDefaults 覆盖语言。每种语言至少检查并截图：

1. 首次启动协议弹窗（两个 YYText 链接和按钮）。
2. 首页与 Tab Bar。
3. 声音列表三组卡片。
4. 独立播放页的倒计时与暂停/关闭状态。
5. 设置、关于、帮助反馈。

尺寸至少覆盖 320×568 等效小屏与 390×844 常规屏；再以最大辅助字号检查英文、简体中文与繁體中文的 Launch、Library、Focus、Settings 滚动可达性。把截图绝对路径、设备/系统版本、检查结果与物理设备未验证项写入 verification report；不得把仅编译通过写成运行时已验证。

- [ ] **Step 6: 检查资源产物和稳定数据**

检查 Step 4 固定 DerivedData 下的准确 `.app`：

```bash
plutil -p /tmp/islewhispers-localization-derived-data/Build/Products/Debug-iphonesimulator/IsleWhispers.app/Info.plist | rg 'CFBundleDevelopmentRegion|CFBundleLocalizations'
find /tmp/islewhispers-localization-derived-data/Build/Products/Debug-iphonesimulator/IsleWhispers.app -path '*lproj/Localizable.strings' -print | sort
find /tmp/islewhispers-localization-derived-data/Build/Products/Debug-iphonesimulator/IsleWhispers.app -name '*.caf' | wc -l
```

Expected: development region 为 `en`，存在 en/zh-Hans/zh-Hant 本地化资源，CAF 仍为 15 个。补充运行/测试证据证明最近播放中的 `audioResource` 与通知 request identifier 未变。

- [ ] **Step 7: 提交守卫与验证报告**

```bash
git add ../IsleWhispersTests/LocalizationTests.swift \
  docs/superpowers/reports/2026-09-02-app-localization-verification.md
git commit -m "测试：补全多语言回退与界面验证"
```

最终执行 `git status --short`，Expected: 空输出。若物理设备通知、控制中心或 VoiceOver 手势没有实测，在报告中标为“待实机验证”，不能写成通过。
