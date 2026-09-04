import { sounds } from './data/sounds';
import { createPlayer } from './services/player';
import { createStorage } from './services/storage';
import { createSleepTimer } from './services/sleep-timer';

App({
  onLaunch() {
    this.storage = createStorage(wx);
    this.player = createPlayer({ audioManager: wx.getBackgroundAudioManager(), storage: this.storage, sounds });
    this.sleepTimer = createSleepTimer({ now: Date.now });
  },
  onShow() { if (this.sleepTimer.consumeExpiry()) this.player.pause(); }
});
