import { sounds } from '../../data/sounds';

const app = getApp();

Page({
  data: { state: {}, sound: {}, sounds, soundIndex: 0, recent: [], recentOpen: false, timerChoice: 0, topInset: 0 },
  onLoad() {
    const capsule = wx.getMenuButtonBoundingClientRect();
    this.setData({ recentOpen: false, topInset: capsule.bottom + 16 });
    this.unsubscribe = app.player.subscribe(() => this.render());
    this.clock = setInterval(() => this.tick(), 1000);
    this.render();
  },
  onShow() { this.getTabBar?.()?.setSelected('/pages/home/index'); app.sleepTimer.schedule(0); this.setData({ timerChoice: 0 }); this.render(); },
  onUnload() { this.unsubscribe?.(); clearInterval(this.clock); },
  tick() {
    app.sleepTimer.consumeExpiry();
    this.render();
  },
  render() {
    const state = app.player.getState();
    const soundIndex = sounds.findIndex((item) => item.id === state.soundId);
    this.setData({
      state,
      sound: sounds[soundIndex],
      soundIndex,
      recent: app.storage.getRecentSoundIds().map((id) => sounds.find((item) => item.id === id)).filter(Boolean)
    });
  },
  openPlayer() {
    app.storage.recordRecent(app.player.getState().soundId);
    if (!app.player.getState().isPlaying) app.player.play();
    wx.navigateTo({ url: '/pages/player/index' });
  },
  changeSound(event) {
    if (event.detail.source !== 'touch') return;
    this.selectSoundAt(event.detail.current);
  },
  selectSoundAt(index) {
    const sound = sounds[index];
    if (!sound || sound.id === app.player.getState().soundId) return;
    app.player.select(sound.id);
    if (app.player.getState().isPlaying) app.storage.recordRecent(sound.id);
  },
  togglePlayback() {
    const state = app.player.getState();
    if (state.isPlaying && !state.muted) {
      app.player.pause();
      return;
    }
    if (state.muted) app.player.setMuted(false);
    if (!app.player.getState().isPlaying) app.player.play();
    app.storage.recordRecent(state.soundId);
  },
  setTimer(event) {
    const minutes = Number(event.currentTarget.dataset.minutes);
    app.sleepTimer.schedule(minutes);
    this.setData({ timerChoice: minutes });
    this.openPlayer();
  },
  openRecent() { this.setData({ recentOpen: true }); },
  closeRecent() { this.setData({ recentOpen: false }); },
  selectRecent(event) {
    const id = event.currentTarget.dataset.id;
    app.player.select(id);
    app.player.play();
    app.storage.recordRecent(id);
    this.closeRecent();
  },
  noop() {}
});
