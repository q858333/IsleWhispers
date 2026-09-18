import { appVersion } from '../../config/app-version';

Page({
  data: { version: `版本 ${appVersion}` },
  onLoad() {
    const { version } = wx.getAccountInfoSync().miniProgram;
    this.setData({ version: `版本 ${version || appVersion}` });
  }
});
