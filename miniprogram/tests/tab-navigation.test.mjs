import assert from 'node:assert/strict';
import test from 'node:test';

import { selectedTabIndex } from '../services/tab-navigation.js';

test('自定义底栏会为当前 Tab 页面返回正确选中项', () => {
  assert.equal(selectedTabIndex('/pages/home/index'), 0);
  assert.equal(selectedTabIndex('/pages/library/index'), 1);
  assert.equal(selectedTabIndex('/pages/settings/index'), 2);
});
