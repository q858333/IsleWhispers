import assert from 'node:assert/strict';
import test from 'node:test';
import vm from 'node:vm';
import { readFileSync } from 'node:fs';
const root = new URL('../', import.meta.url).pathname;
const js = readFileSync(`${root}/pages/home/index.js`, 'utf8').replace(/^import .*;\n/gm, '');
const wxml = readFileSync(`${root}/pages/home/index.wxml`, 'utf8');
function fixture(index, initiallyMuted = false) {
  const sounds = Array.from({ length: 16 }, (_, i) => ({ id: String(i) }));
  let page, id = String(index), isPlaying = false, muted = initiallyMuted; const selected = [], recent = [];
  let playCalls = 0;
  const app = { player: {
    getState: () => ({ soundId: id, isPlaying, muted }),
    select(value) { id = value; selected.push(value); page.data.soundIndex = Number(value); },
    play() { isPlaying = true; playCalls++; },
    pause() { isPlaying = false; },
    setMuted(value) { muted = value; }
  }, storage: { recordRecent(id) { recent.push(id); } } };
  vm.runInNewContext(js, { sounds, getApp: () => app, Page: p => { page = p; } });
  page.data.soundIndex = index;
  return { page, selected, recent, state: app.player.getState, playCalls: () => playCalls };
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

test('默认暂停时左右切换只选择声音，不播放或记录播放历史', () => {
  const f = fixture(0);
  f.page.changeSound({ detail: { current: 1, source: 'touch' } });
  f.page.changeSound({ detail: { current: 0, source: 'touch' } });
  assert.equal(f.state().isPlaying, false);
  assert.equal(f.playCalls(), 0);
  assert.deepEqual(f.recent, []);
});
test('右上角开启后切换保持播放，关闭后切换保持暂停', () => {
  const f = fixture(0);
  const handler = wxml.match(/class="header-button mute-button" bindtap="([^"]+)"/)[1];
  f.page[handler]();
  f.page.changeSound({ detail: { current: 1, source: 'touch' } });
  assert.equal(f.state().isPlaying, true);
  assert.equal(f.playCalls(), 1);
  assert.deepEqual(f.recent, ['0', '1']);
  f.page[handler]();
  f.page.changeSound({ detail: { current: 2, source: 'touch' } });
  assert.equal(f.state().isPlaying, false);
  assert.equal(f.playCalls(), 1);
  assert.deepEqual(f.recent, ['0', '1']);
});
test('以前保存的静音状态不会阻止右上角开启播放', () => {
  const f = fixture(0, true);
  f.page.togglePlayback();
  assert.equal(f.state().muted, false);
  assert.equal(f.state().isPlaying, true);
  assert.equal(f.playCalls(), 1);
});
