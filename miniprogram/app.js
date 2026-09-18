import { createTimerBell } from './services/timer-bell';
import { ImageLoader } from './utils/image-loader';
import { cloudAudio } from './config/cloud-audio';
import { sounds } from './data/sounds';
import { AudioLoader } from './utils/audio-loader';
import { createPlayer } from './services/player';
import { createStorage } from './services/storage';
import { createSleepTimer } from './services/sleep-timer';

App({
  onLaunch() {
    wx.cloud.init({ env: cloudAudio.envId });
    this.imageLoader = new ImageLoader({ cloud: wx.cloud, fileSystem: wx.getFileSystemManager(), userDataPath: wx.env.USER_DATA_PATH });
    this.storage = createStorage(wx);
    this.player = createPlayer({
      audioManager: wx.getBackgroundAudioManager(),
      storage: this.storage,
      sounds,
      audioSource: new AudioLoader({
        cloud: wx.cloud,
        fileSystem: wx.getFileSystemManager(),
        userDataPath: wx.env.USER_DATA_PATH,
        ...cloudAudio
      })
    });
    this.timerBell = createTimerBell(wx);
    this.sleepTimer = createSleepTimer({ now: Date.now }, () => {
      this.player.pause();
      this.timerBell.play();
    });
  },
  onShow() { this.sleepTimer.consumeExpiry(); }
});
