export function createPlayer({ audioManager, storage, sounds, audioSource = { resolve: (sound) => Promise.resolve(sound.audioPath) } }) {
  const storedSoundId = storage.getSelectedSoundId();
  const initialSoundId = sounds.some((sound) => sound.id === storedSoundId) ? storedSoundId : sounds[0].id;
  if (storedSoundId && storedSoundId !== initialSoundId) storage.setSelectedSoundId(initialSoundId);
  let state = { soundId: initialSoundId, isPlaying: false, muted: storage.getMuted(), error: null };
  const listeners = new Set();
  const publish = () => listeners.forEach((listener) => listener({ ...state }));
  const soundFor = (id) => sounds.find((sound) => sound.id === id);
  let loadedSoundId = null;
  let loadingSoundId = null;
  let loadingPromise = null;
  const load = () => {
    const sound = soundFor(state.soundId);
    if (loadedSoundId === sound.id) return Promise.resolve();
    if (loadingSoundId === sound.id) return loadingPromise;
    loadingSoundId = sound.id;
    loadingPromise = Promise.resolve(audioSource.resolve(sound))
      .then((source) => {
        if (state.soundId !== sound.id) return;
        audioManager.src = source;
        audioManager.title = sound.title;
        audioManager.loop = true;
        audioManager.volume = state.muted ? 0 : 1;
        loadedSoundId = sound.id;
        if (state.isPlaying) audioManager.play();
      })
      .catch((error) => {
        if (state.soundId !== sound.id) return;
        state.isPlaying = false;
        state.error = error?.errMsg || error?.message || '音频加载失败';
        publish();
      })
      .finally(() => {
        if (loadingSoundId === sound.id) {
          loadingSoundId = null;
          loadingPromise = null;
        }
      });
    return loadingPromise;
  };
  load();
  audioManager.onPlay(() => { state.isPlaying = true; state.error = null; publish(); });
  audioManager.onPause(() => { state.isPlaying = false; publish(); });
  audioManager.onStop(() => { state.isPlaying = false; publish(); });
  audioManager.onError((event) => { state.isPlaying = false; state.error = event?.errMsg || '音频播放失败'; publish(); });
  return {
    getState: () => ({ ...state }), subscribe(listener) { listeners.add(listener); return () => listeners.delete(listener); },
    select(id) { if (!soundFor(id)) return; state.soundId = id; storage.setSelectedSoundId(id); load(); publish(); },
    play() { state.isPlaying = true; state.error = null; if (loadedSoundId === state.soundId) audioManager.play(); else load(); publish(); },
    pause() { audioManager.pause(); state.isPlaying = false; publish(); },
    toggle() { state.isPlaying ? this.pause() : this.play(); },
    setMuted(muted) { state.muted = muted === true; storage.setMuted(state.muted); audioManager.volume = state.muted ? 0 : 1; publish(); },
    retry() { load(); this.play(); }
  };
}
