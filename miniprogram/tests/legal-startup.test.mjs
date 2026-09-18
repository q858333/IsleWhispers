import assert from 'node:assert/strict';
import test from 'node:test';
import vm from 'node:vm';
import { readFileSync } from 'node:fs';
const source = readFileSync(new URL('../pages/legal/index.js', import.meta.url), 'utf8');
function launch(storage = new Map()) {
  let page;
  const routes = [];
  vm.runInNewContext(source, { Page: value => { page = value; }, wx: {
    getStorageSync: key => storage.get(key),
    setStorageSync: (key, value) => storage.set(key, value),
    switchTab: ({ url }) => routes.push(url)
  } });
  page.onLoad?.();
  return { page, routes };
}
test('首次启动等待同意，同意后再次启动直接进入首页', () => {
  const storage = new Map();
  const first = launch(storage);
  assert.deepEqual(first.routes, []);
  first.page.start();
  assert.deepEqual(first.routes, ['/pages/home/index']);
  assert.deepEqual(launch(storage).routes, ['/pages/home/index']);
});
test('清除本地数据后重新展示同意提示', () => {
  const storage = new Map();
  launch(storage).page.start();
  storage.clear();
  assert.deepEqual(launch(storage).routes, []);
});
