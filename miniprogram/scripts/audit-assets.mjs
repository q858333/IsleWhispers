import { createHash } from 'node:crypto';
import { readFile, stat } from 'node:fs/promises';
import path from 'node:path';
import manifest from '../assets/licenses/manifest.json' with { type: 'json' };
import { sounds } from '../data/sounds.js';

const audioDirectory = new URL('../assets/audio/', import.meta.url);
const expectedIds = new Set(sounds.map(({ id }) => id));
const errors = [];

if (manifest.assets.length !== 15) errors.push(`expected 15 assets, received ${manifest.assets.length}`);
for (const asset of manifest.assets) {
  if (!expectedIds.delete(asset.id)) errors.push(`unexpected or duplicate id: ${asset.id}`);
  if (asset.license !== 'CC0-1.0') errors.push(`${asset.id}: license must be CC0-1.0`);
  if (!/^https:\/\//.test(asset.sourceUrl) || !/^https:\/\//.test(asset.licenseUrl)) errors.push(`${asset.id}: source and license URLs must be HTTPS`);
  if (!/^[a-z0-9-]+\.mp3$/.test(asset.publishedFileName)) errors.push(`${asset.id}: published file must be a lowercase MP3`);
  const file = new URL(asset.publishedFileName, audioDirectory);
  try {
    await stat(file);
    const actual = createHash('sha256').update(await readFile(file)).digest('hex');
    if (actual !== asset.sha256) errors.push(`${asset.id}: SHA-256 mismatch`);
  } catch {
    errors.push(`${asset.id}: missing audio file`);
  }
}
if (expectedIds.size) errors.push(`catalog assets missing from manifest: ${[...expectedIds].join(', ')}`);

if (errors.length) {
  console.error(errors.join('\n'));
  process.exitCode = 1;
} else {
  console.log('15 audited CC0 MP3 assets');
}
