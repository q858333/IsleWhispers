import assert from 'node:assert/strict';
import test from 'node:test';
import vm from 'node:vm';
import { readFileSync } from 'node:fs';
const root = new URL('../', import.meta.url);
const { AudioLoader } = await import(new URL('utils/audio-loader.js', root));
const { createPlayer } = await import(new URL('services/player.js', root));
const { createStorage } = await import(new URL('services/storage.js', root));
const sounds = [{ id: 'a', title: 'A', audioFileName: 'a.mp3' }, { id: 'b', title: 'B', audioFileName: 'b.mp3' }];
function loaderFixture({ save = true } = {}) {
  const files = new Set(); const pending = []; let downloads = 0;
  const options = { fileIdPrefix: 'cloud://env', directory: 'audio', userDataPath: '/local',
    cloud: { downloadFile() { downloads++; return new Promise((resolve, reject) => pending.push({ resolve, reject })); } },
    fileSystem: { access({ path, success, fail }) { (files.has(path) ? success : fail)(); },
      saveFile({ filePath, success, fail }) { if (save) { files.add(filePath); success({ savedFilePath: filePath }); } else fail(); } }
  };
  const loader = new AudioLoader(options);
  return { loader, files, pending, newLoader: () => new AudioLoader(options), downloads: () => downloads };
}
const flush = () => new Promise(resolve => setImmediate(resolve));
test('下载期间通知页面，完成后退出下载状态，已有本地文件不重复下载', async () => {
  const f = loaderFixture(); const statuses = [];
  f.loader.subscribe(() => statuses.push(f.loader.getStatus(sounds[0])));
  assert.equal(f.downloads(), 0);
  const loading = f.loader.resolve(sounds[0]); await flush();
  assert.equal(f.loader.getStatus(sounds[0]), 'downloading');
  f.pending[0].resolve({ tempFilePath: '/tmp/audio' }); await loading;
  assert.equal(f.loader.getStatus(sounds[0]), 'cached');
  assert.ok(statuses.includes('checking'));
  await f.loader.resolve(sounds[0]); assert.equal(f.downloads(), 1);
  const reopened = f.newLoader(); await reopened.resolve(sounds[0]);
  assert.equal(reopened.getStatus(sounds[0]), 'cached');
  assert.equal(f.downloads(), 1);
});
test('保存失败和下载失败不能标为离线可用', async () => {
  const f = loaderFixture({ save: false });
  const loading = f.loader.resolve(sounds[0]); await flush();
  f.pending[0].resolve({ tempFilePath: '/tmp/audio' });
  assert.equal(await loading, '/tmp/audio');
  assert.equal(f.loader.getStatus(sounds[0]), 'temporary');
  const failed = f.loader.resolve(sounds[1]); await flush();
  f.pending[1].reject(new Error('offline')); await assert.rejects(failed);
  assert.equal(f.loader.getStatus(sounds[1]), 'error');
});
test('快速切歌后旧下载完成，不覆盖当前下载状态', async () => {
  const f = loaderFixture(); const callbacks = {};
  const storage = { getSelectedSoundId: () => 'a', getMuted: () => false, setSelectedSoundId() {} };
  const audio = { play() {}, pause() {}, onPlay(fn) { callbacks.play = fn; }, onPause() {}, onStop() {}, onError() {} };
  const player = createPlayer({ audioManager: audio, storage, sounds, audioSource: f.loader });
  player.play(); await flush(); player.select('b'); await flush();
  f.pending[0].resolve({ tempFilePath: '/tmp/a' }); await flush();
  assert.equal(player.getState().soundId, 'b');
  assert.equal(player.getState().audioStatus, 'downloading');
  f.pending[1].resolve({ tempFilePath: '/tmp/b' }); await flush();
  assert.equal(player.getState().audioStatus, 'cached');
});
function storageFixture() {
  const values = new Map(); const adapter = { getStorageSync: key => values.get(key), setStorageSync: (key, value) => values.set(key, value) };
  return { adapter, storage: createStorage(adapter) };
}
test('到期提醒默认开启，关闭后重建存储仍然关闭', () => {
  const { adapter, storage } = storageFixture();
  assert.equal(storage.getTimerBellEnabled(), true);
  storage.setTimerBellEnabled(false);
  assert.equal(createStorage(adapter).getTimerBellEnabled(), false);
  storage.setTimerBellEnabled(true);
  assert.equal(createStorage(adapter).getTimerBellEnabled(), true);
});
test('应用到期回调总是暂停声音，仅在当前设置开启时响铃', () => {
  let app, expire; const calls = []; const { storage } = storageFixture();
  const source = readFileSync(new URL('app.js', root), 'utf8').replace(/^import .*;\n/gm, '');
  vm.runInNewContext(source, { App: value => { app = value; }, Date, sounds,
    cloudAudio: {}, wx: { cloud: { init() {} }, env: { USER_DATA_PATH: '/local' }, getFileSystemManager() {}, getBackgroundAudioManager() {} },
    ImageLoader: class {}, AudioLoader: class {}, createStorage: () => storage,
    createPlayer: () => ({ pause: () => calls.push('pause') }),
    createTimerBell: () => ({ play: () => calls.push('bell') }),
    createSleepTimer: (clock, callback) => { expire = callback; return {}; }
  });
  app.onLaunch(); expire(); assert.deepEqual(calls, ['pause', 'bell']);
  calls.length = 0; storage.setTimerBellEnabled(false); expire(); assert.deepEqual(calls, ['pause']);
});
test('睡眠定时弹窗恢复响铃选择，切换立即保存且不关闭弹窗', () => {
  let page, stopped = 0; const { storage } = storageFixture();
  const source = readFileSync(new URL('pages/player/index.js', root), 'utf8').replace(/^import .*;\n/gm, '');
  vm.runInNewContext(source, { sounds, Page: value => { page = value; }, getApp: () => ({ storage, timerBell: { stop() { stopped++; } } }) });
  page.setData = data => Object.assign(page.data, data);
  page.showTimer(); assert.equal(page.data.timerBellEnabled, true);
  page.changeTimerBell({ detail: { value: false } });
  assert.equal(storage.getTimerBellEnabled(), false); assert.equal(stopped, 1);
  assert.equal(page.data.timerOpen, true);
  page.hideTimer(); page.showTimer();
  assert.equal(page.data.timerBellEnabled, false);
  page.changeTimerBell({ detail: { value: true } });
  assert.equal(storage.getTimerBellEnabled(), true);
});
