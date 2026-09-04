# IsleWhispers 微信小程序迁移 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 交付一个可在微信开发者工具导入、真实播放经过 CC0 审计的环境音，并具备首发合规资料的原生微信小程序。

**Architecture:** 在现有 iOS 工程旁创建独立 `miniprogram/`，以小程序原生 Page、WXML、WXSS 和 JavaScript 实现。`data/sounds.js` 为目录的唯一来源，`services/` 管理背景音频、本地状态和睡眠定时；页面只订阅这些服务。音频许可证数据、文件散列和音频文件一起版本化，拒绝无审计的资源进入代码包。

**Tech Stack:** 微信小程序原生框架、JavaScript、WXML、WXSS、Node.js 内置 `node:test`、FFmpeg、微信开发者工具。

**Spec:** `docs/superpowers/specs/2026-09-04-islewhispers-wechat-miniprogram-design.md`

## Global Constraints

- 不修改 `IsleWhispers/` UIKit 源码、Xcode 工程、Pods 或现有 Worker。
- 原 iOS 音频和配图不得复制、转换、引用或列入小程序。
- 首发恰好收录 15 个逐项记录为 CC0 的环境音；禁止 CC-BY、CC-BY-NC、Pixabay、Mixkit 与来源不明资源。
- 所有发布音频为本地打包 MP3；每项在许可证清单中记录来源、CC0 链接、下载日期和 SHA-256。
- 不添加登录、用户上传、UGC、支付、广告、推送、设备标识、位置、相册、麦克风、剪贴板或服务端数据上传。
- 最近播放最多 6 项；睡眠定时仅支持不限时、15、30、60 分钟。
- 不提交 AppID、AppSecret、管理员信息或其他凭据。

---

## File structure

| Path | Responsibility |
|---|---|
| `miniprogram/app.{js,json,wxss}` | 全局生命周期、页面注册、TabBar 和主题 token |
| `miniprogram/data/sounds.js` | 15 项声音目录与分类 |
| `miniprogram/services/player.js` | 背景音频单例、事件订阅与播放状态 |
| `miniprogram/services/storage.js` | 选中声音、静音与最近播放的本地持久化 |
| `miniprogram/services/sleep-timer.js` | 绝对截止时间的睡眠定时 |
| `miniprogram/pages/home/*` | 播放控制、最近播放与睡眠定时入口 |
| `miniprogram/pages/library/*` | 分类声音目录 |
| `miniprogram/pages/settings/*` | 隐私、条款、支持和素材授权入口 |
| `miniprogram/pages/legal/*` | 合规首次入口与公开链接承载页 |
| `miniprogram/pages/licenses/*` | 可浏览的素材许可证清单 |
| `miniprogram/assets/audio/*.mp3` | 经审计、转码后的 15 个发布音频 |
| `miniprogram/assets/licenses/manifest.json` | 每项音频的来源、许可证和散列 |
| `miniprogram/scripts/audit-assets.mjs` | 校验清单、数量、扩展名、散列和许可证字段 |
| `miniprogram/tests/*.test.mjs` | 纯数据、存储与定时逻辑的 Node 测试 |
| `miniprogram/README.md` | 导入、预览、素材审计与提审步骤 |
| `miniprogram/REVIEW_CHECKLIST.md` | 微信上架人工检查清单 |

### Task 1: 建立可导入的小程序骨架与纯逻辑测试基线

**Files:**
- Create: `miniprogram/package.json`
- Create: `miniprogram/app.js`, `miniprogram/app.json`, `miniprogram/app.wxss`, `miniprogram/sitemap.json`, `miniprogram/project.config.json`
- Create: `miniprogram/tests/sleep-timer.test.mjs`, `miniprogram/tests/storage.test.mjs`
- Create: `miniprogram/services/sleep-timer.js`, `miniprogram/services/storage.js`

**Interfaces:**
- Produces: `createSleepTimer(clock)`, `createStorage(adapter)`, Node command `npm test`.
- Consumes: an injected `{ now(): number }` clock and injected `{ getStorageSync(key), setStorageSync(key, value), removeStorageSync(key) }` adapter.

- [ ] **Step 1: 写入失败测试，锁定定时和本地记录的边界**

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import { createSleepTimer } from '../services/sleep-timer.js';

test('30 分钟计时暂停后恢复剩余时间，过期只返回一次 true', () => {
  let now = 0;
  const timer = createSleepTimer({ now: () => now });
  timer.schedule(30);
  now = 10 * 60_000;
  timer.pause();
  assert.equal(timer.remainingMs(), 20 * 60_000);
  now += 4 * 60_000;
  timer.resume();
  now += 20 * 60_000;
  assert.equal(timer.consumeExpiry(), true);
  assert.equal(timer.consumeExpiry(), false);
});
```

- [ ] **Step 2: 运行测试，确认它因模块不存在而失败**

Run: `cd miniprogram && node --test tests/*.test.mjs`

Expected: `ERR_MODULE_NOT_FOUND` for `services/sleep-timer.js` and `services/storage.js`.

- [ ] **Step 3: 实现最小可测的定时和存储服务**

```js
export function createSleepTimer(clock) {
  let deadline = null;
  let pausedRemaining = null;
  return {
    schedule(minutes) { deadline = minutes ? clock.now() + minutes * 60_000 : null; pausedRemaining = null; },
    pause() { if (deadline !== null) { pausedRemaining = Math.max(0, deadline - clock.now()); deadline = null; } },
    resume() { if (pausedRemaining !== null) { deadline = clock.now() + pausedRemaining; pausedRemaining = null; } },
    remainingMs() { return deadline !== null ? Math.max(0, deadline - clock.now()) : pausedRemaining; },
    consumeExpiry() { if (deadline !== null && deadline <= clock.now()) { deadline = null; return true; } return false; }
  };
}
```

`createStorage(adapter)` 固定使用键 `isleWhispers.selectedSoundId`、`isleWhispers.muted` 和 `isleWhispers.recentSoundIds`；`recordRecent(id)` 去重后放到首位并截断为 6。

- [ ] **Step 4: 创建小程序配置**

`app.json` 的 `pages` 顺序为 `pages/legal/index`、`pages/home/index`、`pages/library/index`、`pages/settings/index`、`pages/licenses/index`；`tabBar.list` 只包含 home/library/settings。`project.config.json` 使用空字符串 AppID 与 `miniprogramRoot: "./"`，不得填入真实凭据。

- [ ] **Step 5: 运行测试与开发者工具导入检查**

Run: `cd miniprogram && npm test`

Expected: 所有 Node 测试通过；微信开发者工具选择 `miniprogram/` 后无 JSON 配置错误。

- [ ] **Step 6: Commit**

```bash
git add miniprogram/package.json miniprogram/app.js miniprogram/app.json miniprogram/app.wxss miniprogram/sitemap.json miniprogram/project.config.json miniprogram/services miniprogram/tests
git commit -m "feat：初始化原生微信小程序骨架"
```

### Task 2: 建立 CC0 素材审计链并加入 15 个 MP3

**Files:**
- Create: `miniprogram/assets/audio/`
- Create: `miniprogram/assets/licenses/manifest.json`
- Create: `miniprogram/scripts/audit-assets.mjs`
- Create: `miniprogram/tests/asset-manifest.test.mjs`
- Create: `miniprogram/data/sounds.js`

**Interfaces:**
- Produces: `sounds`（15 个 `{ id, title, subtitle, category, audioPath, theme }` 对象）与 `audit-assets.mjs` 成功退出码。
- Consumes: `manifest.json` 的 `assets` 数组，每项含 `id`, `sourceUrl`, `licenseUrl`, `license`, `downloadedAt`, `sourceFileName`, `publishedFileName`, `sha256`。

- [ ] **Step 1: 编写清单失败测试**

```js
test('素材清单仅含 15 项 CC0 MP3，且目录 ID 一一对应', () => {
  assert.equal(manifest.assets.length, 15);
  assert.deepEqual(new Set(manifest.assets.map(({ id }) => id)), new Set(sounds.map(({ id }) => id)));
  for (const asset of manifest.assets) {
    assert.equal(asset.license, 'CC0-1.0');
    assert.match(asset.licenseUrl, /^https:\/\//);
    assert.match(asset.sourceUrl, /^https:\/\//);
    assert.match(asset.publishedFileName, /^[a-z0-9-]+\.mp3$/);
    assert.match(asset.sha256, /^[a-f0-9]{64}$/);
  }
});
```

- [ ] **Step 2: 以公开资源页人工核验并下载 15 个声音**

对每个资源页逐项截图/保存页面副本，确认页面的许可证字段为 `CC0` 或 `CC0 1.0 Universal`，并排除人声、商标和音乐采样。将原文件放在不受 Git 跟踪的临时目录；禁止下载原 iOS 音频、CC-BY、CC-BY-NC、Pixabay 或 Mixkit 文件。

声音主题固定为：雨、雷、溪流、海浪、风、篝火、夜虫、森林鸟鸣、远处火车、帆船、鲸声、风铃、咖啡厅环境、农场晨景、白噪声。`id` 分别为 `rain`、`thunder`、`stream`、`waves`、`wind`、`fire`、`night-insects`、`forest-birds`、`distant-train`、`sailboat`、`whales`、`wind-chimes`、`cafe-ambience`、`farm-morning`、`white-noise`。

- [ ] **Step 3: 转换、散列并写入清单**

对每一个经过核验的源文件执行：

```bash
ffmpeg -i "SOURCE_FILE" -vn -ac 2 -ar 44100 -c:a libmp3lame -b:a 128k "miniprogram/assets/audio/ID.mp3"
shasum -a 256 "miniprogram/assets/audio/ID.mp3"
```

在 `manifest.json` 用上一步的固定 ID 填写真实来源 URL、CC0 许可证 URL、ISO 8601 下载日期、原文件名、发布文件名和输出散列；`data/sounds.js` 的 `audioPath` 统一为 `/assets/audio/${id}.mp3`。如果任何一项无法给出 CC0 资源页和许可证 URL，删除该文件并停止本任务，不以“免费”或“免署名”替代 CC0。

- [ ] **Step 4: 实现素材审计器**

`audit-assets.mjs` 读取清单与目录，验证 15 项数量、许可证精确值、字段格式、MP3 文件存在、文件 SHA-256 与清单相符，以及 `sounds` 的 ID/路径一对一匹配。任一失败 `process.exitCode = 1` 并输出失败 ID 与字段名。

- [ ] **Step 5: 运行素材检查和测试**

Run: `cd miniprogram && node scripts/audit-assets.mjs && npm test`

Expected: 输出 `15 audited CC0 MP3 assets`，全部测试通过。

- [ ] **Step 6: Commit**

```bash
git add miniprogram/assets miniprogram/data/sounds.js miniprogram/scripts/audit-assets.mjs miniprogram/tests/asset-manifest.test.mjs
git commit -m "feat：加入经审计的 CC0 环境音素材"
```

### Task 3: 实现背景播放器与本地播放状态

**Files:**
- Create: `miniprogram/services/player.js`
- Create: `miniprogram/tests/player-state.test.mjs`
- Modify: `miniprogram/app.js`

**Interfaces:**
- Consumes: `sounds`, `createStorage`, 和微信 `wx.getBackgroundAudioManager()`。
- Produces: `createPlayer({ audioManager, storage, sounds })`，提供 `getState()`, `subscribe(listener)`, `select(id)`, `play()`, `pause()`, `toggle()`, `setMuted(muted)`, `retry()`。

- [ ] **Step 1: 写播放器状态失败测试**

```js
test('播放中的切歌重新加载新 MP3，暂停中的切歌保持暂停', () => {
  const player = createPlayer({ audioManager: fakeAudio(), storage: fakeStorage(), sounds });
  player.select('rain'); player.play(); player.select('wind');
  assert.equal(player.getState().soundId, 'wind');
  assert.equal(player.getState().isPlaying, true);
  player.pause(); player.select('fire');
  assert.equal(player.getState().isPlaying, false);
});
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `cd miniprogram && node --test tests/player-state.test.mjs`

Expected: `ERR_MODULE_NOT_FOUND` for `services/player.js`.

- [ ] **Step 3: 实现播放器**

在 `select(id)` 中验证 ID、写入 storage、设置 `audioManager.src` 和 `title`，并仅在切歌前状态为播放时调用 `audioManager.play()`；设置 `audioManager.loop = true`。`onPlay/onPause/onStop/onError` 将状态发布给订阅者；`onError` 只保存用户可读错误，不上传日志。`setMuted` 设置 `audioManager.volume` 为 `0` 或 `1`。

- [ ] **Step 4: 绑定小程序生命周期**

`app.js` 在 `onLaunch` 创建一次播放器，`onShow` 让睡眠定时检查到期并暂停播放器；不得在页面 `onUnload` 中调用 `destroy()`。

- [ ] **Step 5: 运行单元测试**

Run: `cd miniprogram && npm test`

Expected: 播放状态、定时和存储测试均通过。

- [ ] **Step 6: Commit**

```bash
git add miniprogram/services/player.js miniprogram/tests/player-state.test.mjs miniprogram/app.js
git commit -m "feat：实现小程序背景音频播放"
```

### Task 4: 实现首页、声音库和最近播放

**Files:**
- Create: `miniprogram/pages/home/index.{js,json,wxml,wxss}`
- Create: `miniprogram/pages/library/index.{js,json,wxml,wxss}`
- Modify: `miniprogram/app.json`

**Interfaces:**
- Consumes: `getApp().player`, `sounds`, `createSleepTimer` 和 storage 的最近播放 ID。
- Produces: 首页的 `onTogglePlayback`, `onPrevious`, `onNext`, `onToggleMute`, `onChooseTimer`, `onOpenRecent`；声音库的 `onSelectSound`。

- [ ] **Step 1: 创建首页 WXML 结构**

首页必须包括声音标题/说明、依主题绑定的抽象渐变封面、上一首、播放/暂停、下一首、静音、睡眠定时和“最近播放”按钮。按钮使用 `button`/`aria-label` 等价可访问标签；禁止使用第三方图片或原 iOS 文案资源。

- [ ] **Step 2: 连接首页状态**

`onLoad` 订阅 `getApp().player.subscribe`，`onUnload` 取消订阅；每次 `onShow` 调用 `refresh()` 重绘当前状态和到期后的暂停状态。选择 15/30/60/不限时调用定时服务，倒计时每秒刷新显示但计时真值来自绝对截止时间。

- [ ] **Step 3: 实现声音库**

以自然、生活、氛围三节渲染 `sounds`。点击卡片调用 `player.select(id)` 再 `player.play()`，记录最近播放，并 `wx.switchTab({ url: '/pages/home/index' })`。选中项要有文字状态而非只依赖颜色。

- [ ] **Step 4: 实现最近播放弹层**

从 storage 读取最近 ID 并映射到 `sounds`；空状态显示“尚无最近播放”，非空时点击项目按首页方式选择和播放。严格限制 6 项且重复选择移到首位。

- [ ] **Step 5: 开发者工具手工验证**

在模拟器依次验证 15 个卡片、播放/暂停、切换、静音、最近播放去重和上限。真机验证退到后台后继续播放；记录失败机型和系统版本，不以模拟器结果代替。

- [ ] **Step 6: Commit**

```bash
git add miniprogram/pages/home miniprogram/pages/library miniprogram/app.json
git commit -m "feat：完成声音浏览与播放首页"
```

### Task 5: 实现首次合规入口、设置、授权清单与外链失败回退

**Files:**
- Create: `miniprogram/pages/legal/index.{js,json,wxml,wxss}`
- Create: `miniprogram/pages/legal/webview.{js,json,wxml,wxss}`
- Create: `miniprogram/pages/settings/index.{js,json,wxml,wxss}`
- Create: `miniprogram/pages/licenses/index.{js,json,wxml,wxss}`
- Create: `miniprogram/config/support-links.js`
- Create: `miniprogram/tests/support-links.test.mjs`

**Interfaces:**
- Produces: `supportLinks.terms`, `supportLinks.privacy`, `supportLinks.support` 和 `isleWhispers.hasAcceptedLegalNotice` 本地布尔值。
- Consumes: 已存在的公开 HTTPS 条款、隐私和支持链接，以及许可证清单。

- [ ] **Step 1: 写支持链接失败测试**

```js
test('公开合规链接均为 HTTPS 且指向预期 IsleWhispers 域名', () => {
  for (const value of Object.values(supportLinks)) {
    assert.match(value, /^https:\/\/islewhispersweb\.dengcheez\.workers\.dev\//);
  }
});
```

- [ ] **Step 2: 实现首次合规入口**

`pages/legal/index` 首次显示“开始使用”“服务条款”“用户隐私保护指引”。点开始使用后将 `isleWhispers.hasAcceptedLegalNotice` 写为 `true` 并 `wx.reLaunch({ url: '/pages/home/index' })`；不点同意不进入服务。后续启动在 `app.onLaunch` 根据该键决定 `reLaunch` 到 legal 或 home。

- [ ] **Step 3: 实现设置和许可证清单**

设置页列出服务条款、用户隐私保护指引、联系支持、素材与授权。许可证页加载 `manifest.json`，显示名称、作者、许可证、来源链接和下载日期；WXML 不显示原始来源文件路径或无关个人数据。

- [ ] **Step 4: 实现外链承载和失败提示**

`webview` 页仅接受 `supportLinks` 的三个白名单 URL，通过 `encodeURIComponent` 传递；未知 URL 返回设置页并 `wx.showToast({ title: '链接不可用，请联系支持', icon: 'none' })`。在小程序后台配置上述域名为业务域名后，真机打开三条链接。

- [ ] **Step 5: 运行测试和人工检查**

Run: `cd miniprogram && npm test`

Expected: 链接、素材、播放器、定时、存储测试通过；首次启动无法绕过合规入口，设置页能到达所有公开资料。

- [ ] **Step 6: Commit**

```bash
git add miniprogram/pages/legal miniprogram/pages/settings miniprogram/pages/licenses miniprogram/config/support-links.js miniprogram/tests/support-links.test.mjs miniprogram/app.js
git commit -m "feat：补齐小程序合规与授权页面"
```

### Task 6: 完善文档、审核清单与发布前验证

**Files:**
- Create: `miniprogram/README.md`
- Create: `miniprogram/REVIEW_CHECKLIST.md`
- Modify: `miniprogram/package.json`

**Interfaces:**
- Produces: `npm test`、`npm run audit:assets` 和可交接的人工提审清单。

- [ ] **Step 1: 写入 README 的精确操作**

README 必须写明：在微信开发者工具导入 `miniprogram/`、保持 AppID 空白或填写用户自己的 AppID、运行 `npm test` 与 `npm run audit:assets`、不填写 AppSecret、在公众平台配置三条 HTTPS 域名、上传体验版和真机预览路径。

- [ ] **Step 2: 写入 REVIEW_CHECKLIST.md**

按复选项列出：主体/类目、名称/图标/简介、隐私保护指引“不收集不上传个人信息”的实际一致性、客服联系方式、三条业务域名、首页与声音库体验路径、首次合规入口、15 项 CC0 清单、审计器通过、真机后台播放、15/30/60 分钟到期、最近播放 6 项上限、无原 iOS 素材、审核版本与线上版本一致。

- [ ] **Step 3: 添加 npm 脚本**

```json
{
  "scripts": {
    "test": "node --test tests/*.test.mjs",
    "audit:assets": "node scripts/audit-assets.mjs",
    "verify": "npm run audit:assets && npm test"
  }
}
```

- [ ] **Step 4: 运行完整验证**

Run: `cd miniprogram && npm run verify`

Expected: 素材审计器与全部纯逻辑测试通过；随后用微信开发者工具编译无错误，再在真机完成审核清单的每个可执行项目。

- [ ] **Step 5: 检查改动范围**

Run: `git diff --check && git status --short`

Expected: 无空白错误；除 `miniprogram/` 与本计划文档外，不出现 UIKit 或 Xcode 工程改动。原有 `xcuserdata` 改动保持不暂存。

- [ ] **Step 6: Commit**

```bash
git add miniprogram/README.md miniprogram/REVIEW_CHECKLIST.md miniprogram/package.json
git commit -m "docs：补充小程序提审与验证清单"
```

## Plan self-review

| Spec requirement | Plan coverage |
|---|---|
| 独立原生工程、三 Tab 页面 | Tasks 1, 4, 5 |
| 15 项 CC0 MP3、许可证与散列 | Task 2 |
| 背景播放、静音、最近播放、睡眠定时 | Tasks 1, 3, 4 |
| 无设备注册与敏感权限 | Global Constraints, Tasks 1, 3, 5, 6 |
| 首次合规入口、条款、隐私、支持 | Task 5 |
| 审核文件与真机验证 | Task 6 |

已检查：计划未保留未决定的资源类型、接口名称或验证命令；后续素材下载的唯一允许路径是每项资源页明确 CC0 且被写入清单，任何缺少证据的素材都会阻断 Task 2。
