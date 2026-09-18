import assert from 'node:assert/strict';
import test from 'node:test';
import { readFile } from 'node:fs/promises';

test('授权页不在运行时 require JSON 素材清单', async () => {
  const source = await readFile(new URL('../pages/licenses/index.js', import.meta.url), 'utf8');
  assert.doesNotMatch(source, /require\([^)]*manifest\.json/);
});

test('授权页不会将自有声音素材描述为 CC0', async () => {
  const source = await readFile(new URL('../pages/legal/index.wxml', import.meta.url), 'utf8');
  assert.doesNotMatch(source, /CC0/);
  assert.match(source, /自有/);
});
