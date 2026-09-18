import assert from 'node:assert/strict';
import test from 'node:test';

import manifest from '../assets/licenses/manifest.json' with { type: 'json' };
import { sounds } from '../data/sounds.js';

test('素材清单与 App 的 15 段自有声音及滴水回声一一对应', () => {
  const expectedIds = [
    'tea', 'thunder', 'rain', 'fire', 'water', 'wind', 'day', 'night',
    'river', 'space', 'yacht', 'train', 'farm', 'chimes', 'whale', 'dripping-water'
  ];
  assert.equal(manifest.assets.length, 16);
  assert.deepEqual(
    new Set(manifest.assets.map(({ id }) => id)),
    new Set(expectedIds)
  );
  assert.deepEqual(new Set(sounds.map(({ id }) => id)), new Set(expectedIds));

  for (const asset of manifest.assets) {
    assert.equal(asset.license, '自有素材');
    assert.equal(asset.author, 'IsleWhispers');
    assert.match(asset.publishedFileName, /^[a-z0-9-]+\.mp3$/);
    assert.match(asset.sha256, /^[a-f0-9]{64}$/);
  }
});
