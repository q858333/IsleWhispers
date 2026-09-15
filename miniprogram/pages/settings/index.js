Page({ onShow() { this.getTabBar?.()?.setSelected('/pages/settings/index'); }, go(e) { wx.navigateTo({ url: e.currentTarget.dataset.url }); } });
