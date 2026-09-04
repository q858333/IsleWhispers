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
