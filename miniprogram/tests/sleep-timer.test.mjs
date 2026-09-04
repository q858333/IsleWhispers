import assert from 'node:assert/strict';
import test from 'node:test';

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

test('不限时会清除正在运行的计时', () => {
  const timer = createSleepTimer({ now: () => 0 });
  timer.schedule(15);
  timer.schedule(0);
  assert.equal(timer.remainingMs(), null);
  assert.equal(timer.consumeExpiry(), false);
});
