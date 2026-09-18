import assert from 'node:assert/strict';
import test from 'node:test';
import { createPlayer } from '../services/player.js';

const sounds = [{ id: 'rain', title: '雨', audioPath: '/rain.mp3' }, { id: 'wind', title: '风', audioPath: '/wind.mp3' }];
const storage = { selected: null, muted: false, getSelectedSoundId() { return this.selected; }, setSelectedSoundId(id) { this.selected = id; }, getMuted() { return this.muted; }, setMuted(value) { this.muted = value; } };
function fakeAudio() { return { play() { this.played = true; }, pause() { this.paused = true; }, onPlay(fn) { this.playListener = fn; }, onPause(fn) { this.pauseListener = fn; }, onStop() {}, onError() {} }; }
test('播放中的切歌继续播放，暂停中的切歌保持暂停', () => {
  const player = createPlayer({ audioManager: fakeAudio(), storage, sounds });
  player.select('rain'); player.play(); player.select('wind');
  assert.deepEqual(player.getState(), { soundId: 'wind', isPlaying: true, muted: false, error: null });
  player.pause(); player.select('rain');
  assert.equal(player.getState().isPlaying, false);
});

test('云音频下载完成后再交给播放器播放', async () => {
  let resolveAudio;
  const audioManager = fakeAudio();
  const player = createPlayer({
    audioManager,
    storage,
    sounds,
    audioSource: { resolve: () => new Promise((resolve) => { resolveAudio = resolve; }) }
  });

  player.play();
  assert.equal(audioManager.src, undefined);
  resolveAudio('/tmp/rain.mp3');
  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(audioManager.src, '/tmp/rain.mp3');
  assert.equal(audioManager.played, true);
});

test('已删除声音的本地偏好会回退到新目录的第一段声音', () => {
  const staleStorage = { ...storage, selected: 'rain-garden' };
  const player = createPlayer({ audioManager: fakeAudio(), storage: staleStorage, sounds });

  assert.equal(player.getState().soundId, 'rain');
});
