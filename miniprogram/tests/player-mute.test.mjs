import assert from 'node:assert/strict';
import test from 'node:test';
import { createPlayer } from '../services/player.js';
const flush = () => new Promise(r => setImmediate(r));
function fixture(muted = false, source) {
  const audio = {
    paused: true, sources: [],
    set src(value) { this.sources.push(value); this.play(); },
    set volume(value) {}, // 后台播放器不支持音量设置。
    play() { this.paused = false; this.playListener?.(); },
    pause() { this.paused = true; this.pauseListener?.(); },
    onPlay(fn) { this.playListener = fn; }, onPause(fn) { this.pauseListener = fn; }, onStop() {}, onError() {}
  };
  const storage = { getSelectedSoundId: () => 'rain', getMuted: () => muted, setMuted(v) { muted = v; }, setSelectedSoundId() {} };
  const player = createPlayer({ audioManager: audio, storage, sounds: [{ id: 'rain', audioPath: '/rain.mp3' }, { id: 'wind', audioPath: '/wind.mp3' }], ...(source ? { audioSource: source } : {}) });
  return { player, audio };
}
test('点击静音真正停止输出，取消静音恢复，保持逻辑播放状态', async () => {
  const { player, audio } = fixture(); player.play(); await flush();
  player.setMuted(true); assert.equal(audio.paused, true); assert.equal(player.getState().isPlaying, true);
  player.setMuted(false); assert.equal(audio.paused, false);
});
test('记住静音状态时进入首页不设置音源，静音切歌后取消静音播放新声音', async () => {
  const { player, audio } = fixture(true); player.play(); await flush();
  assert.deepEqual(audio.sources, []);
  player.select('wind'); await flush(); assert.deepEqual(audio.sources, []);
  player.setMuted(false); await flush(); assert.deepEqual(audio.sources, ['/wind.mp3']);
});
test('下载期间静音，完成下载也不会出声', async () => {
  let done; const { player, audio } = fixture(false, { resolve: () => new Promise(r => done = r) });
  player.play(); player.setMuted(true); done('/rain.mp3'); await flush();
  assert.deepEqual(audio.sources, []); assert.equal(audio.paused, true);
});
test('用户暂停后取消静音不恢复播放', async () => {
  const { player, audio } = fixture(); player.play(); await flush(); player.setMuted(true); player.pause(); player.setMuted(false); await flush();
  assert.equal(audio.paused, true); assert.equal(player.getState().isPlaying, false);
});
