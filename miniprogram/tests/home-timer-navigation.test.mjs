import assert from 'node:assert/strict';
import test from 'node:test';
import vm from 'node:vm';
import { readFileSync } from 'node:fs';
import { createSleepTimer } from '../services/sleep-timer.js';
const source = readFileSync(new URL('../pages/home/index.js', import.meta.url), 'utf8').replace(/^import .*;\n/gm, '');
function fixture() {
  let page, playing = false;
  const timer = createSleepTimer({ now: () => 0 });
  const navigations = [];
  vm.runInNewContext(source, { sounds: [], getApp: () => ({ sleepTimer: timer, player: { getState: () => ({ isPlaying: playing }), play() { playing = true; } } }), Page: p => { page = p; }, wx: { navigateTo(options) { navigations.push({ url: options.url, remaining: timer.remainingMs(), playing }); } } });
  page.setData = data => Object.assign(page.data, data); page.render = () => {};
  return { page, timer, navigations };
}
test('进入首页时重置为不限时并清除旧定时', () => {
  const f = fixture(); f.timer.schedule(30); f.page.data.timerChoice = 30;
  f.page.onShow(); assert.equal(f.page.data.timerChoice, 0); assert.equal(f.timer.remainingMs(), null);
});
test('选择任一定时选项后立即进入播放页并开始播放', () => {
  for (const minutes of [0, 15, 30, 60, 90, 120]) {
    const f = fixture(); f.page.setTimer({ currentTarget: { dataset: { minutes } } });
    assert.deepEqual(f.navigations, [{ url: '/pages/player/index', remaining: minutes ? minutes * 60000 : null, playing: true }]);
    assert.equal(f.page.data.timerChoice, minutes);
  }
});
