Page({
  data: { version: '' },
  onLoad() {
    const { version, envVersion } = wx.getAccountInfoSync().miniProgram;
    const environment = { develop: '开发版', trial: '体验版', release: '正式版' };
    this.setData({ version: version ? `版本 ${version}` : (environment[envVersion] || '版本信息暂不可用') });
  }
});
