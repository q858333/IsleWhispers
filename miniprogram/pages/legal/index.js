Page({
  onLoad() {
    if (wx.getStorageSync('isleWhispers.hasAcceptedLegalNotice') === true) {
      wx.switchTab({ url: '/pages/home/index' });
    }
  },
  start() {
    wx.setStorageSync('isleWhispers.hasAcceptedLegalNotice', true);
    wx.switchTab({ url: '/pages/home/index' });
  },
  go(e) { wx.navigateTo({ url: e.currentTarget.dataset.url }); }
});
