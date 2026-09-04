export function createPlayer({ audioManager, storage, sounds }) {
  let state = { soundId: storage.getSelectedSoundId() || sounds[0].id, isPlaying: false, muted: storage.getMuted(), error: null };
  const listeners = new Set();
  const publish = () => listeners.forEach((listener) => listener({ ...state }));
  const soundFor = (id) => sounds.find((sound) => sound.id === id);
  const load = () => { const sound = soundFor(state.soundId); audioManager.src = sound.audioPath; audioManager.title = sound.title; audioManager.loop = true; audioManager.volume = state.muted ? 0 : 1; };
  load();
  audioManager.onPlay(() => { state.isPlaying = true; state.error = null; publish(); });
  audioManager.onPause(() => { state.isPlaying = false; publish(); });
  audioManager.onStop(() => { state.isPlaying = false; publish(); });
  audioManager.onError((event) => { state.isPlaying = false; state.error = event?.errMsg || '音频播放失败'; publish(); });
  return {
    getState: () => ({ ...state }), subscribe(listener) { listeners.add(listener); return () => listeners.delete(listener); },
    select(id) { if (!soundFor(id)) return; const resume = state.isPlaying; state.soundId = id; storage.setSelectedSoundId(id); load(); if (resume) audioManager.play(); publish(); },
    play() { audioManager.play(); state.isPlaying = true; state.error = null; publish(); },
    pause() { audioManager.pause(); state.isPlaying = false; publish(); },
    toggle() { state.isPlaying ? this.pause() : this.play(); },
    setMuted(muted) { state.muted = muted === true; storage.setMuted(state.muted); audioManager.volume = state.muted ? 0 : 1; publish(); },
    retry() { load(); this.play(); }
  };
}
