import assert from 'node:assert/strict';
import test from 'node:test';

import { nextSoundIndexFromSwipe } from '../services/swipe-navigation.js';

test('向左滑动切到下一段声音并在末尾循环', () => {
  assert.equal(nextSoundIndexFromSwipe(0, 3, 220, 120), 1);
  assert.equal(nextSoundIndexFromSwipe(2, 3, 220, 120), 0);
});

test('向右滑动切到上一段声音，短触摸不切换', () => {
  assert.equal(nextSoundIndexFromSwipe(0, 3, 120, 220), 2);
  assert.equal(nextSoundIndexFromSwipe(1, 3, 220, 190), 1);
});
