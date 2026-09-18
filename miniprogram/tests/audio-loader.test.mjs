import assert from 'node:assert/strict';
import test from 'node:test';
import { mkdtemp, mkdir, access, rename, writeFile, readFile, unlink, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

import { AudioLoader } from '../utils/audio-loader.js';
import { cloudAudio } from '../config/cloud-audio.js';

const sound = { id: 'tea', audioFileName: 'tea.mp3' };

async function fixture(t) {
  const root = await mkdtemp(join(tmpdir(), 'isle-audio-test-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  const userDataPath = join(root, 'saved');
  await mkdir(userDataPath);
  const calls = [];
  const fileSystem = {
    access({ path, success, fail }) { access(path).then(success, fail); },
    saveFile({ tempFilePath, filePath, success, fail }) {
      rename(tempFilePath, filePath).then(() => success({ savedFilePath: filePath }), fail);
    }
  };
  const cloud = {
    async downloadFile({ fileID }) {
      calls.push(fileID);
      const tempFilePath = join(root, `download-${calls.length}.mp3`);
      await writeFile(tempFilePath, `audio:${fileID}`);
      return { tempFilePath };
    }
  };
  const options = { cloud, fileSystem, userDataPath, ...cloudAudio };
  return { calls, cloud, fileSystem, userDataPath, create: (overrides = {}) => new AudioLoader({ ...options, ...overrides }) };
}

test('首次下载保存为本地文件，重建来源后不联网即可复用', async (t) => {
  const f = await fixture(t);
  const path = await f.create().resolve(sound);
  assert.ok(path.startsWith(`${f.userDataPath}/`));
  assert.equal(await readFile(path, 'utf8'), `audio:${cloudAudio.fileIdPrefix}/${cloudAudio.directory}/tea.mp3`);
  f.cloud.downloadFile = async () => { throw new Error('offline'); };
  assert.equal(await f.create().resolve(sound), path);
  assert.deepEqual(f.calls, [`${cloudAudio.fileIdPrefix}/${cloudAudio.directory}/tea.mp3`]);
});

test('本地音频被清理后重新下载', async (t) => {
  const f = await fixture(t);
  const source = f.create();
  const path = await source.resolve(sound);
  await unlink(path);
  await source.resolve(sound);
  assert.equal(f.calls.length, 2);
  await access(path);
});

test('同一音频并发请求只下载一次', async (t) => {
  const f = await fixture(t);
  const source = f.create();
  const paths = await Promise.all([source.resolve(sound), source.resolve(sound), source.resolve(sound)]);
  assert.equal(new Set(paths).size, 1);
  assert.equal(f.calls.length, 1);
});

test('下载失败不阻止后续重试', async (t) => {
  const f = await fixture(t);
  const download = f.cloud.downloadFile;
  f.cloud.downloadFile = async () => { throw new Error('offline'); };
  const source = f.create();
  await assert.rejects(source.resolve(sound), /offline/);
  f.cloud.downloadFile = download;
  await access(await source.resolve(sound));
  assert.equal(f.calls.length, 1);
});

test('持久保存失败仍可播放临时文件，下次重试保存', async (t) => {
  const f = await fixture(t);
  const save = f.fileSystem.saveFile;
  f.fileSystem.saveFile = ({ fail }) => fail({ errMsg: 'storage full' });
  const source = f.create();
  const temporaryPath = await source.resolve(sound);
  await access(temporaryPath);
  assert.ok(!temporaryPath.startsWith(`${f.userDataPath}/`));
  f.fileSystem.saveFile = save;
  const savedPath = await source.resolve(sound);
  assert.ok(savedPath.startsWith(`${f.userDataPath}/`));
});

test('云路径或音频文件名变化时不会使用旧缓存', async (t) => {
  const f = await fixture(t);
  const first = await f.create().resolve(sound);
  const second = await f.create({ directory: 'audio-v2' }).resolve(sound);
  const third = await f.create().resolve({ ...sound, audioFileName: 'tea-v2.mp3' });
  assert.equal(new Set([first, second, third]).size, 3);
  assert.equal(f.calls.length, 3);
});
