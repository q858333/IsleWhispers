import { selectedTabIndex, tabBarAppearance, tabPaths } from '../services/tab-navigation';

Component({
  data: {
    selected: 0,
    appearance: 'dark',
    tabs: [
      { text: '首页', icon: '/assets/tab-icons/listen.png', activeIcon: '/assets/tab-icons/listen-active.png' },
      { text: '声音', icon: '/assets/tab-icons/library.png', activeIcon: '/assets/tab-icons/library-active.png' },
      { text: '设置', icon: '/assets/tab-icons/settings.png', activeIcon: '/assets/tab-icons/settings-active.png' }
    ]
  },
  methods: {
    setSelected(path) { this.setData({ selected: selectedTabIndex(path), appearance: tabBarAppearance(path) }); },
    switchTab(event) { wx.switchTab({ url: tabPaths[event.currentTarget.dataset.index] }); }
  }
});
