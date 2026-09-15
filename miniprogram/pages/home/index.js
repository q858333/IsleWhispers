import { sounds } from '../../data/sounds';
import { nextSoundIndexFromSwipe } from '../../services/swipe-navigation';

const app = getApp();

Page({
  data: { state: {}, sound: {}, sounds, soundIndex: 0, recent: [], recentOpen: false, timerChoice: 0 },
  onLoad() {
    this.setData({ recentOpen: false });
    this.unsubscribe = app.player.subscribe(() => this.render());
    this.clock = setInterval(() => this.tick(), 1000);
    app.storage.recordRecent(app.player.getState().soundId);
    app.player.play();
    this.render();
  },
  onShow() { this.getTabBar?.()?.setSelected('/pages/home/index'); this.render(); },
  onUnload() { this.unsubscribe?.(); clearInterval(this.clock); },
  tick() {
    if (app.sleepTimer.consumeExpiry()) app.player.pause();
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
    if (!app.player.getState().isPlaying) app.player.play();
    wx.navigateTo({ url: '/pages/player/index' });
  },
  changeSound(event) {
    this.selectSoundAt(event.detail.current);
  },
  startSwipe(event) {
    this.swipeStartX = event.touches?.[0]?.pageX;
  },
  finishSwipe(event) {
    const endX = event.changedTouches?.[0]?.pageX;
    if (typeof this.swipeStartX !== 'number' || typeof endX !== 'number') return;
    this.selectSoundAt(nextSoundIndexFromSwipe(this.data.soundIndex, sounds.length, this.swipeStartX, endX));
    this.swipeStartX = null;
  },
  selectSoundAt(index) {
    const sound = sounds[index];
    if (!sound || sound.id === app.player.getState().soundId) return;
    app.player.select(sound.id);
    app.player.play();
    app.storage.recordRecent(sound.id);
  },
  togglePlayback() { app.player.toggle(); },
  toggleMute() { app.player.setMuted(!app.player.getState().muted); },
  setTimer(event) {
    const minutes = Number(event.currentTarget.dataset.minutes);
    app.sleepTimer.schedule(minutes);
    this.setData({ timerChoice: minutes });
    this.render();
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
