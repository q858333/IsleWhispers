import assert from 'node:assert/strict';
import test from 'node:test';

import { createStorage } from '../services/storage.js';

function createAdapter() {
  const values = new Map();
  return {
    getStorageSync(key) { return values.get(key); },
    setStorageSync(key, value) { values.set(key, value); },
    removeStorageSync(key) { values.delete(key); }
  };
}

test('最近播放去重后置顶且只保留六项', () => {
  const storage = createStorage(createAdapter());
  for (const id of ['rain', 'wind', 'fire', 'waves', 'stream', 'forest', 'rain']) {
    storage.recordRecent(id);
  }
  assert.deepEqual(storage.getRecentSoundIds(), ['rain', 'forest', 'stream', 'waves', 'fire', 'wind']);
});

test('选中声音和静音状态会保存并恢复', () => {
  const adapter = createAdapter();
  const first = createStorage(adapter);
  first.setSelectedSoundId('waves');
  first.setMuted(true);
  const second = createStorage(adapter);
  assert.equal(second.getSelectedSoundId(), 'waves');
  assert.equal(second.getMuted(), true);
});
