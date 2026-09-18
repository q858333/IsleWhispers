import { sounds } from '../../data/sounds';

const app = getApp();

Page({
  data: { state: {}, sound: {}, hasTimer: false, isRinging: false, isDevelop: false, currentHour: '', currentMinute: '', endTimeText: '', pickerOpen: false, timerOpen: false, sounds },
  onLoad() {
    const capsule = wx.getMenuButtonBoundingClientRect();
    const { envVersion } = wx.getAccountInfoSync().miniProgram;
    this.setData({ topInset: capsule.bottom + 16, isDevelop: envVersion === 'develop' });
    this.unsubscribe = app.player.subscribe(() => this.render());
    this.clock = setInterval(() => this.tick(), 1000);
    this.render();
  },
  onShow() { this.render(); },
  onUnload() { this.unsubscribe?.(); clearInterval(this.clock); app.sleepTimer.schedule(0); app.timerBell.stop(); },
  tick() {
    app.sleepTimer.consumeExpiry();
    this.render();
  },
  render() {
    const state = app.player.getState();
    const remainingMs = app.sleepTimer.remainingMs();
    const isRinging = app.timerBell.isRinging();
    const now = new Date();
    const deadline = app.sleepTimer.endsAt();
    const end = deadline === null ? null : new Date(deadline);
    const pad = (value) => String(value).padStart(2, '0');
    const nextDay = end && end.toDateString() !== now.toDateString();
    this.setData({
      hasTimer: remainingMs !== null,
      isRinging,
      currentHour: pad(now.getHours()),
      currentMinute: pad(now.getMinutes()),
      endTimeText: isRinging ? '关闭铃声' : end ? `${nextDay ? '次日 ' : ''}${pad(end.getHours())}:${pad(end.getMinutes())} 到期` : '已暂停 · 恢复后继续',
      state,
      sound: sounds.find((item) => item.id === state.soundId)
    });
  },
  toggle() {
    if (app.player.getState().isPlaying) app.sleepTimer.pause();
    else app.sleepTimer.resume();
    app.player.toggle();
  },
  retry() { app.player.retry(); },
  showPicker() { this.setData({ pickerOpen: true, timerOpen: false }); },
  hidePicker() { this.setData({ pickerOpen: false }); },
  noop() {},
  chooseSound(event) {
    const id = event.currentTarget.dataset.id;
    app.player.select(id);
    app.sleepTimer.resume();
    app.player.play();
    app.storage.recordRecent(id);
    this.setData({ pickerOpen: false });
  },
  tapDeadline() {
    if (app.timerBell.isRinging()) {
      app.timerBell.stop();
      this.render();
    } else this.showTimer();
  },
  showTimer() { this.setData({ timerOpen: true, pickerOpen: false }); },
  hideTimer() { this.setData({ timerOpen: false }); },
  timer(event) {
    const { minutes, seconds } = event.currentTarget.dataset;
    app.sleepTimer.schedule(seconds === undefined ? Number(minutes) : Number(seconds) / 60);
    if (!app.player.getState().isPlaying) app.sleepTimer.pause();
    this.setData({ timerOpen: false });
    this.render();
  },
  close() {
    app.timerBell.stop();
    app.sleepTimer.schedule(0);
    app.player.pause();
    wx.navigateBack({ delta: 1 });
  }
});
