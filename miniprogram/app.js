import { sounds } from './data/sounds';
import { createPlayer } from './services/player';
import { createStorage } from './services/storage';

App({
  onLaunch() {
    this.storage = createStorage(wx);
    this.player = createPlayer({ audioManager: wx.getBackgroundAudioManager(), storage: this.storage, sounds });
  }
});
