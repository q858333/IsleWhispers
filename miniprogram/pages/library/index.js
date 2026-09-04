import { sounds } from '../../data/sounds';
const app = getApp();
Page({ data: { groups: [] }, onLoad() { const byCategory = {}; sounds.forEach((sound) => (byCategory[sound.category] ||= []).push(sound)); this.setData({ groups: Object.entries(byCategory).map(([name, items]) => ({ name, items })) }); }, select(event) { const id = event.currentTarget.dataset.id; app.player.select(id); app.player.play(); app.storage.recordRecent(id); wx.switchTab({ url: '/pages/home/index' }); } });
