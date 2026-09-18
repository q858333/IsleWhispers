import assert from 'node:assert/strict';
import test from 'node:test';
import { createTimerBell } from '../services/timer-bell.js';
import { createSleepTimer } from '../services/sleep-timer.js';

test('定时到期先停止白噪音再响铃，多处检查不会重复响铃', () => {
  let now = 0; const calls = [];
  const timer = createSleepTimer({ now: () => now }, () => { calls.push('pause'); calls.push('bell'); });
  timer.schedule(15); now = 900000;
  timer.consumeExpiry(); timer.consumeExpiry(); timer.consumeExpiry();
  assert.deepEqual(calls, ['pause', 'bell']);
});
test('暂停或取消定时不响铃', () => {
  let now = 0; let count = 0;
  const timer = createSleepTimer({ now: () => now }, () => count++);
  timer.schedule(15); timer.pause(); now = 900000; timer.consumeExpiry();
  timer.schedule(0); timer.consumeExpiry(); assert.equal(count, 0);
});
test('铃声循环30秒自动停止，出错或手动停止会释放资源', (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  const instances = [];
  const bell = createTimerBell({ createInnerAudioContext() {
    const audio = { played: 0, destroyed: 0, onEnded(fn) { this.ended = fn; }, onError(fn) { this.error = fn; }, play() { this.played++; }, destroy() { this.destroyed++; } };
    instances.push(audio); return audio;
  } });
  bell.play(); const first = instances[0];
  assert.equal(first.src, '/assets/notifications/timer-bell.mp3'); assert.equal(first.loop, true); assert.equal(first.played, 1);
  t.mock.timers.tick(29_999); assert.equal(first.destroyed, 0);
  t.mock.timers.tick(1); assert.equal(first.destroyed, 1);
  bell.play(); instances[1].error(); assert.equal(instances[1].destroyed, 1);
  bell.play(); bell.stop(); assert.equal(instances[2].destroyed, 1);
  t.mock.timers.tick(30_000); assert.equal(instances[1].destroyed, 1); assert.equal(instances[2].destroyed, 1);
});
