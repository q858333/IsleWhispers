import { cloudAudio } from './config/cloud-audio';
import { sounds } from './data/sounds';
import { createCloudAudioSource } from './services/cloud-audio-source';
import { createPlayer } from './services/player';
import { createStorage } from './services/storage';
import { createSleepTimer } from './services/sleep-timer';

App({
  onLaunch() {
    wx.cloud.init({ env: cloudAudio.envId });
    this.storage = createStorage(wx);
    this.player = createPlayer({
      audioManager: wx.getBackgroundAudioManager(),
      storage: this.storage,
      sounds,
      audioSource: createCloudAudioSource({
        cloud: wx.cloud,
        fileSystem: wx.getFileSystemManager(),
        userDataPath: wx.env.USER_DATA_PATH,
        ...cloudAudio
      })
    });
    this.sleepTimer = createSleepTimer({ now: Date.now });
  },
  onShow() { if (this.sleepTimer.consumeExpiry()) this.player.pause(); }
});
