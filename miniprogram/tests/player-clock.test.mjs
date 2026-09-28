import assert from 'node:assert/strict';
import test from 'node:test';
import vm from 'node:vm';
import { readFileSync } from 'node:fs';
import { createSleepTimer } from '../services/sleep-timer.js';
const source = readFileSync(new URL('../pages/player/index.js', import.meta.url), 'utf8').replace(/^import .*;\n/gm, '');
function fixture(hour = 16, minute = 14) {
  let now = new Date(2026, 8, 18, hour, minute).getTime();
  const timer = createSleepTimer({ now: () => now });
  let page;
  const bell = { ringing: false, isRinging() { return this.ringing; }, stop() { this.ringing = false; } };
  class ClockDate extends Date { constructor(...args) { super(...(args.length ? args : [now])); } }
  vm.runInNewContext(source, { Date: ClockDate, clearInterval() {}, sounds: [{ id: 'tea' }], getApp: () => ({ sleepTimer: timer, timerBell: bell, storage: { getTimerBellEnabled: () => true }, player: { getState: () => ({ soundId: 'tea' }) } }), Page: p => { page = p; } });
  page.setData = d => Object.assign(page.data, d);
  return { timer, bell, page, advance(ms) { now += ms; } };
}
test('显示当前时间和固定到期时间，当前时间随时钟更新', () => {
  const f = fixture(); f.timer.schedule(15); f.page.render();
  assert.equal(f.page.data.hasTimer, true);
  assert.equal(f.page.data.currentHour, '16'); assert.equal(f.page.data.currentMinute, '14');
  assert.equal(f.page.data.endTimeText, '16:29 到期');
  f.advance(60000); f.page.render();
  assert.equal(f.page.data.currentMinute, '15'); assert.equal(f.page.data.endTimeText, '16:29 到期');
});
test('跨午夜标注次日', () => {
  const f = fixture(23, 50); f.timer.schedule(30); f.page.render();
  assert.equal(f.page.data.endTimeText, '次日 00:20 到期');
});
test('暂停标注暂停，恢复后顺延到期时间', () => {
  const f = fixture(); f.timer.schedule(15); f.timer.pause(); f.advance(60000); f.page.render();
  assert.equal(f.page.data.endTimeText, '已暂停 · 恢复后继续');
  f.timer.resume(); f.page.render(); assert.equal(f.page.data.endTimeText, '16:30 到期');
});
test('不限时和定时结束不显示时钟区域', () => {
  const f = fixture(); f.page.render(); assert.equal(f.page.data.hasTimer, false);
  f.timer.schedule(15); f.advance(900000); f.timer.consumeExpiry(); f.page.render();
  assert.equal(f.page.data.hasTimer, false);
});

test('到期响铃时胶囊显示关闭铃声，点击后停止且不打开定时菜单', () => {
  const f = fixture(); f.bell.ringing = true; f.page.render();
  assert.equal(f.page.data.isRinging, true); assert.equal(f.page.data.endTimeText, '关闭铃声');
  f.page.tapDeadline();
  assert.equal(f.bell.ringing, false); assert.equal(f.page.data.isRinging, false); assert.equal(f.page.data.timerOpen, false);
});
test('退出播放页关闭铃声并清除定时', () => {
  const f = fixture(); f.bell.ringing = true; f.timer.schedule(15); f.page.onUnload();
  assert.equal(f.bell.ringing, false); assert.equal(f.timer.remainingMs(), null);
});
test('未响铃时点击胶囊仍打开定时菜单', () => {
  const f = fixture(); f.page.tapDeadline(); assert.equal(f.page.data.timerOpen, true);
});
