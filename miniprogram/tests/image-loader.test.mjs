import assert from 'node:assert/strict';
import test from 'node:test';
import { ImageLoader } from '../utils/image-loader.js';

function fixture() {
  const files = new Set();
  let downloads = 0;
  const fileSystem = {
    access({ path, success, fail }) { files.has(path) ? success() : fail(); },
    copyFile({ srcPath, destPath, success }) { assert.ok(files.has(srcPath)); files.add(destPath); success(); }
  };
  const cloud = { async downloadFile() { const tempFilePath = `/tmp/${++downloads}`; files.add(tempFilePath); return { tempFilePath }; } };
  const create = () => new ImageLoader({ cloud, fileSystem, userDataPath: '/usr' });
  return { files, fileSystem, cloud, create, count: () => downloads };
}
test('图片持久缓存可跨实例离线读取，清理后重新下载', async () => {
  const f = fixture();
  const path = await f.create().resolve('cloud://env/backgrounds/tea.jpg');
  assert.ok(path.startsWith('/usr/'));
  assert.equal(await f.create().resolve('cloud://env/backgrounds/tea.jpg'), path);
  assert.equal(f.count(), 1);
  f.files.delete(path);
  await f.create().resolve('cloud://env/backgrounds/tea.jpg');
  assert.equal(f.count(), 2);
});
test('图片并发请求只下载一次，不同文件独立缓存', async () => {
  const f = fixture(); const source = f.create();
  const paths = await Promise.all([source.resolve('cloud://a'), source.resolve('cloud://a')]);
  assert.equal(paths[0], paths[1]); assert.equal(f.count(), 1);
  assert.notEqual(await source.resolve('cloud://b'), paths[0]);
});
test('空间不足时复用临时图片，临时文件失效后重新下载', async () => {
  const f = fixture(); f.fileSystem.copyFile = ({ fail }) => fail();
  const source = f.create(); const path = await source.resolve('cloud://a');
  assert.equal(await source.resolve('cloud://a'), path); assert.equal(f.count(), 1);
  f.files.delete(path); await source.resolve('cloud://a'); assert.equal(f.count(), 2);
});
test('下载失败后允许重试', async () => {
  const f = fixture(); const download = f.cloud.downloadFile;
  f.cloud.downloadFile = async () => { throw new Error('offline'); };
  const source = f.create(); await assert.rejects(source.resolve('cloud://a'), /offline/);
  f.cloud.downloadFile = download; assert.ok(await source.resolve('cloud://a'));
});
