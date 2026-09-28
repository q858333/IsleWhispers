import { appVersion } from '../../config/app-version';

Page({
  data: { version: `版本 ${appVersion}`, statusBarHeight: 0, navBarHeight: 44, topInset: 0 },
  onLoad() {
    const capsule = wx.getMenuButtonBoundingClientRect();
    const { statusBarHeight } = wx.getWindowInfo();
    const navBarHeight = capsule.height + (capsule.top - statusBarHeight) * 2;
    const { version } = wx.getAccountInfoSync().miniProgram;
    this.setData({
      version: `版本 ${version || appVersion}`,
      statusBarHeight,
      navBarHeight,
      topInset: capsule.bottom + 8
    });
  },
  back() {
    wx.navigateBack({ delta: 1 });
  }
});
