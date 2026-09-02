# IsleWhispers 全局多语言设计

## 背景

IsleWhispers 当前工程的 `developmentRegion` 已经是 `en`，但界面、声音名称、辅助功能、错误状态和通知文案仍直接写在 Swift 中，并以简体中文为主。应用需要统一支持英文、简体中文和通用繁体中文，跟随 iOS 系统或“单独设置 App 语言”的选择；无法匹配支持语言时必须回退英文。

本设计基于 `codex/launch-agreement-rich-text` 分支，保留已完成的 YYText 首次协议弹窗。后续本地化实现与该弹窗一起交付，不提前合并到 `main`。

## 目标

- 英文作为开发语言和默认回退语言。
- 支持 `en`、`zh-Hans` 与通用繁体中文 `zh-Hant`，完全跟随系统语言，不提供 App 内手动语言开关。
- 覆盖所有用户可见文本，包括 VoiceOver、本地通知和系统正在播放信息。
- 不改变声音资源名、声音稳定 ID、最近播放记录和其他持久化格式。
- 在 320pt 小屏、常规 iPhone 和最大辅助字号下保持布局可用。
- 用自动化测试阻止缺失翻译、错误回退和重新引入硬编码中文。

## 非目标

- 不翻译品牌名 `IsleWhispers`。
- 不本地化音频文件名、图片文件名、URL、邮箱地址、UserDefaults key 或 accessibility identifier。
- 不在本次工作中实现 App 内语言切换或无需重启的动态换语。
- 不翻译当前尚未提供内容的 H5 用户协议、隐私政策和在线帮助页面；仅本地化原生页面中的入口、占位提示和错误信息。
- 不拆分 `zh-TW` 与 `zh-HK`；二者均使用通用 `zh-Hant` 资源。
- 不增加其他语言。

## 方案

### 1. String Catalog

新增 `Localizable.xcstrings`，源语言为英文，并提供完整的 `zh-Hans` 与中性、自然、适合 App Store 的 `zh-Hant` 翻译。工程保留 `developmentRegion = en`，`knownRegions` 增加 `zh-Hans` 与 `zh-Hant`。未匹配到三种支持语言的系统语言使用英文资源。

Key 使用稳定、语义化的命名，不直接使用英文句子作为 key：

- `launch.agreement.title`
- `home.action.mute`
- `sound.rain.title`
- `sound.rain.subtitle`
- `timer.remaining.minutes_seconds`
- `notification.playback_ended.title`

带变量的文案使用格式参数，不在调用方拼接语序。时间和计数使用 String Catalog 的复数及格式化能力，确保英文单复数与中文单位正确。

### 2. 本地化访问层

新增轻量 `L10n` 访问层，负责：

- 读取 String Catalog。
- 传入格式参数。
- 为测试注入指定语言 Bundle，而生产默认使用 `.main`。

测试/预览 helper 将 `zh-TW`、`zh-HK` 以及所有以 `zh-Hant-` 开头的语言 tag canonicalize 为 `zh-Hant` 后再解析 `.lproj`；它不参与生产语言选择。生产调用只使用 `.main`，仍由 iOS Bundle 自动匹配系统或 App Preferred Language。

访问层只封装本地化，不管理用户偏好，也不缓存当前语言。iOS 负责语言选择；应用随系统或单独 App 语言变更后按系统生命周期重新加载。

### 3. 声音与分类元数据

`Sound.audioResource` 继续作为稳定 ID，`backgroundResource` 和分类 case 保持稳定。声音标题、描述和分类名称改为本地化计算属性，不把显示语言写入最近播放记录。

例如雨声始终由 `2_sound_rain` 标识，但展示为：

- 英文：`Rain` / `A steady rhythm against the window`
- 简体中文：`雨声` / `均匀落在窗边`
- 繁體中文：`雨聲` / `均勻落在窗邊`

切换系统语言后，已保存的最近播放项会依据相同 ID 自动显示新语言，不需要迁移数据。

### 4. 覆盖范围

以下原生区域全部迁移：

- Launch 品牌副标题、协议标题、正文、链接、按钮和提示弹窗。
- 首页标题、播放、静音、最近播放、重试和轮播辅助功能。
- 声音列表标题、分组、声音标题与描述。
- 独立播放页的播放状态、倒计时、声音切换、错误和辅助功能。
- 最近播放空状态与关闭操作。
- 设置、关于、帮助反馈、常见问题、邮件主题和占位提示。
- Tab Bar 标题。
- 音频服务错误状态。
- 播放结束本地通知。
- Now Playing 的声音标题和描述。

测试诊断文本和开发注释不要求本地化，但用户可见的 XCTest 断言必须按对应语言更新。

### 5. YYText 协议富文本

协议正文由完整的本地化格式串生成，并通过独立的协议名称 key 定位高亮范围。英文、简体中文和繁體中文都必须包含用户协议与隐私政策高亮；每种语言的正文内协议名称必须与对应高亮 key 的值逐字完全一致。点击回调及 VoiceOver 自定义操作保持一致。

如果翻译文本缺少协议名称，测试应失败，而不是静默显示不可点击的普通文本。

### 6. 辅助功能与布局

VoiceOver 的 label、hint、value 和 custom action 与可见文本使用同一语言来源。英文通常比中文更长，繁體中文也可能较简体中文更宽，因此现有按钮、标题和卡片继续支持多行及 Dynamic Type；重点覆盖 320×568、390×844 和最大辅助字号。

不依赖固定字符串宽度，不通过缩小字体解决英文溢出。

## 数据与生命周期

应用不保存语言设置。生产环境启动时 `.main` Bundle 根据 iOS 当前语言自动解析资源：

1. 简体中文匹配 `zh-Hans`。
2. 繁體中文（包括系统解析为 `zh-Hant` 的繁中地区）匹配 `zh-Hant`，不拆分 `zh-TW`/`zh-HK`。
3. 英文匹配 `en`。
4. 其他语言回退开发语言 `en`。

声音选择、最近播放、倒计时和协议同意状态都继续使用现有稳定值，不含本地化文本，因此不需要数据迁移。

## 测试策略

### Catalog 测试

- Catalog 恰好包含 129 个 key：94 个非声音 key、3 个声音分类 key、30 个声音 title/subtitle key、2 个复数 key。
- 英文、简体中文与繁體中文的 key 集合均严格等于同一份 129-key manifest；每个 key 都有非空英文值、非空简体中文值和非空繁體中文值。
- 不支持的 Locale 回退英文。
- 测试/预览 helper 对 `zh-TW`、`zh-HK`、`zh-Hant-TW`、`zh-Hant-HK` 都解析 `zh-Hant.lproj`；生产 `.main` Bundle 仍由系统自动选择。
- 格式化倒计时、计数和版本信息在三种语言下符合预期。

### 模型与服务测试

- 15 个声音及 3 个分类在英文、简体中文和繁體中文下返回正确名称。
- 声音 ID、音频资源名和背景资源名在本地化前后不变。
- 播放状态、本地通知和 Now Playing 使用当前语言文案。

### 界面测试

- 默认英文验证 Launch、Tab、首页、声音列表、播放页和设置页面的关键文案。
- 指定简体中文与繁體中文 Bundle 验证相同流程的关键文案。
- YYText 的两个高亮和 VoiceOver 自定义操作在英文、简体中文、繁體中文下均存在并可触发。
- 三种语言在小屏和最大辅助字号下不截断关键标题、按钮或倒计时内容。

### 静态约束

扫描生产 Swift 文件中的中文字符串。允许列表仅包含不可本地化的技术内容；新出现的用户可见中文必须进入 String Catalog。

## 验证与交付

实施完成后执行：

- 本地化定向测试。
- 全量 XCTest。
- 通用 iOS Simulator clean build。
- 英文、简体中文和繁體中文各一次模拟器启动截图检查。
- `git diff --check` 与资源产物检查。

YYText 1.0.7 的上游弃用警告属于已知第三方警告；本次不得通过修改 Pods 源码或关闭项目级警告来掩盖。

## 风险控制

- 不能用显示文字作为声音身份，否则切换语言会破坏最近播放；身份只使用现有资源 ID。
- 不能在 Swift 中继续拼接中文单位，否则英文语序和复数会错误；统一使用带参数的 catalog key。
- 不能通过修改 `AppleLanguages` 做生产逻辑；测试使用可注入 Bundle，避免污染其他测试。
- 不能只翻译可见 UILabel 而遗漏 VoiceOver、通知和 Now Playing。
