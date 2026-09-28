Page({
  data: { statusBarHeight: 0, navBarHeight: 44, topInset: 0 },
  onLoad() {
    const capsule = wx.getMenuButtonBoundingClientRect();
    const { statusBarHeight } = wx.getWindowInfo();
    const navBarHeight = capsule.height + (capsule.top - statusBarHeight) * 2;
    this.setData({ statusBarHeight, navBarHeight, topInset: capsule.bottom + 8 });
  },
  back() {
    wx.navigateBack({ delta: 1 });
  }
});
