import assert from 'node:assert/strict';
import test from 'node:test';

import manifest from '../assets/licenses/manifest.json' with { type: 'json' };
import { sounds } from '../data/sounds.js';

test('素材清单仅含 16 项 CC0 MP3，且目录 ID 一一对应', () => {
  assert.equal(manifest.assets.length, 16);
  assert.deepEqual(
    new Set(manifest.assets.map(({ id }) => id)),
    new Set(sounds.map(({ id }) => id))
  );

  for (const asset of manifest.assets) {
    assert.equal(asset.license, 'CC0-1.0');
    assert.match(asset.licenseUrl, /^https:\/\//);
    assert.match(asset.sourceUrl, /^https:\/\//);
    assert.match(asset.publishedFileName, /^[a-z0-9-]+\.mp3$/);
    assert.match(asset.sha256, /^[a-f0-9]{64}$/);
  }
});
