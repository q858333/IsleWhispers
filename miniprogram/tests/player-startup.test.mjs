import assert from 'node:assert/strict';
import test from 'node:test';
import { createPlayer } from '../services/player.js';

test('启动阶段不下载或设置音源，进入首页调用play后才加载播放', async () => {
  let downloads = 0;
  let sourceWrites = 0;
  let plays = 0;
  const audioManager = {
    set src(value) { sourceWrites++; this.onPlayCallback(); },
    play() { plays++; }, pause() {},
    onPlay(fn) { this.onPlayCallback = fn; }, onPause() {}, onStop() {}, onError() {}
  };
  const storage = { getSelectedSoundId: () => 'tea', getMuted: () => false };
  const player = createPlayer({ audioManager, storage, sounds: [{ id: 'tea', title: '咖啡厅' }],
    audioSource: { resolve: async () => { downloads++; return '/tmp/tea.mp3'; } } });
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(downloads, 0); assert.equal(sourceWrites, 0); assert.equal(plays, 0);
  assert.equal(player.getState().isPlaying, false);
  player.play();
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(downloads, 1); assert.equal(sourceWrites, 1); assert.equal(plays, 1);
  assert.equal(player.getState().isPlaying, true);
});
