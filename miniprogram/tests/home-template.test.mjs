import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const template = readFileSync(new URL('../pages/home/index.wxml', import.meta.url), 'utf8');

test('首页只在 recentOpen 为真时展示最近播放弹窗', () => {
  assert.match(template, /wx:if="\{\{recentOpen\}\}"/);
  assert.doesNotMatch(template, /wx:if="recentOpen"/);
});
