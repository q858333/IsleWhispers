import { sounds } from '../../data/sounds';

const app = getApp();

Page({
  data: { state: {}, sound: {}, timerText: '∞', pickerOpen: false, timerOpen: false, sounds },
  onLoad() {
    this.unsubscribe = app.player.subscribe(() => this.render());
    this.clock = setInterval(() => this.tick(), 1000);
    this.render();
  },
  onShow() { this.render(); },
  onUnload() { this.unsubscribe?.(); clearInterval(this.clock); },
  tick() {
    if (app.sleepTimer.consumeExpiry()) app.player.pause();
    this.render();
  },
  render() {
    const state = app.player.getState();
    const remainingMs = app.sleepTimer.remainingMs();
    const seconds = Math.max(0, Math.ceil((remainingMs || 0) / 1000));
    this.setData({
      state,
      sound: sounds.find((item) => item.id === state.soundId),
      timerText: remainingMs === null ? '∞' : `${String(Math.floor(seconds / 60)).padStart(2, '0')}:${String(seconds % 60).padStart(2, '0')}`
    });
  },
  toggle() { app.player.toggle(); },
  showPicker() { this.setData({ pickerOpen: true }); },
  hidePicker() { this.setData({ pickerOpen: false }); },
  noop() {},
  chooseSound(event) {
    const id = event.currentTarget.dataset.id;
    app.player.select(id);
    app.player.play();
    app.storage.recordRecent(id);
    this.setData({ pickerOpen: false });
  },
  showTimer() { this.setData({ timerOpen: true }); },
  hideTimer() { this.setData({ timerOpen: false }); },
  timer(event) {
    app.sleepTimer.schedule(Number(event.currentTarget.dataset.minutes));
    this.setData({ timerOpen: false });
    this.render();
  },
  close() { wx.navigateBack({ delta: 1 }); }
});
