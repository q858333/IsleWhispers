Component({
  properties: {
    src: { type: String, observer: 'loadImage' },
    mode: { type: String, value: 'aspectFill' }
  },
  data: { localPath: '' },
  lifetimes: {
    attached() { this.active = true; this.loadImage(); },
    detached() { this.active = false; this.requestId += 1; }
  },
  pageLifetimes: {
    show() { if (!this.data.localPath) this.loadImage(); }
  },
  methods: {
    async loadImage() {
      if (!this.active) return;
      const requestId = this.requestId = (this.requestId || 0) + 1;
      this.setData({ localPath: '' });
      if (!this.data.src) return;
      try {
        const localPath = await getApp().imageLoader.resolve(this.data.src);
        if (this.active && requestId === this.requestId) this.setData({ localPath });
      } catch (error) {
        if (this.active && requestId === this.requestId) this.triggerEvent('error', { message: '图片加载失败' });
      }
    }
  }
});
