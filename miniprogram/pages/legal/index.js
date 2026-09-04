Page({ start() { wx.setStorageSync('isleWhispers.hasAcceptedLegalNotice', true); wx.switchTab({ url: '/pages/home/index' }); }, go(e) { wx.navigateTo({ url: e.currentTarget.dataset.url }); } });
