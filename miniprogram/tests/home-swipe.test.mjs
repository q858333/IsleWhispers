import assert from 'node:assert/strict';
import test from 'node:test';
import vm from 'node:vm';
import { readFileSync } from 'node:fs';
const root = new URL('../', import.meta.url).pathname;
const js = readFileSync(`${root}/pages/home/index.js`, 'utf8').replace(/^import .*;\n/gm, '');
const wxml = readFileSync(`${root}/pages/home/index.wxml`, 'utf8');
function fixture(index) {
  const sounds = Array.from({ length: 16 }, (_, i) => ({ id: String(i) }));
  let page, id = String(index); const selected = [];
  const app = { player: {
    getState: () => ({ soundId: id }),
    select(value) { id = value; selected.push(value); page.data.soundIndex = Number(value); },
    play() {}
  }, storage: { recordRecent() {} } };
  vm.runInNewContext(js, { sounds, getApp: () => app, Page: p => { page = p; } });
  page.data.soundIndex = index;
  return { page, selected };
}
for (const [label, start, target, x1, x2] of [['左滑', 0, 1, 300, 100], ['右滑', 2, 1, 100, 300], ['尾部循环', 15, 0, 300, 100]]) {
  test(`${label}一次手势只切换一个声音`, () => {
    const { page, selected } = fixture(start);
    const dispatch = (binding, event) => { const name = wxml.match(new RegExp(`${binding}="([^"]+)"`))?.[1]; if (name) page[name](event); };
    dispatch('bindtouchstart', { touches: [{ pageX: x1 }] });
    dispatch('bindchange', { detail: { current: target, source: 'touch' } });
    dispatch('bindtouchend', { changedTouches: [{ pageX: x2 }] });
    assert.deepEqual(selected, [String(target)]);
  });
}
test('程序同步 swiper 位置不会触发切歌', () => {
  const { page, selected } = fixture(3);
  page.changeSound({ detail: { current: 2, source: '' } });
  assert.deepEqual(selected, []);
});
