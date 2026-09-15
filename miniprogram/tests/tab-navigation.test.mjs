import assert from 'node:assert/strict';
import test from 'node:test';

import { selectedTabIndex, tabBarAppearance } from '../services/tab-navigation.js';

test('自定义底栏会为当前 Tab 页面返回正确选中项', () => {
  assert.equal(selectedTabIndex('/pages/home/index'), 0);
  assert.equal(selectedTabIndex('/pages/library/index'), 1);
  assert.equal(selectedTabIndex('/pages/settings/index'), 2);
});

test('首页使用深色磨砂底栏，声音库和设置页使用浅色磨砂底栏', () => {
  assert.equal(tabBarAppearance('/pages/home/index'), 'dark');
  assert.equal(tabBarAppearance('/pages/library/index'), 'light');
  assert.equal(tabBarAppearance('/pages/settings/index'), 'light');
});
