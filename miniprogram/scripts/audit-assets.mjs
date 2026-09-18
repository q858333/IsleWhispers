import manifest from '../assets/licenses/manifest.json' with { type: 'json' };
import { sounds } from '../data/sounds.js';

const expectedIds = new Set(sounds.map(({ id }) => id));
const errors = [];

if (manifest.assets.length !== 16) errors.push(`expected 16 assets, received ${manifest.assets.length}`);
for (const asset of manifest.assets) {
  if (!expectedIds.delete(asset.id)) errors.push(`unexpected or duplicate id: ${asset.id}`);
  if (asset.license !== '自有素材') errors.push(`${asset.id}: license must be 自有素材`);
  if (asset.author !== 'IsleWhispers') errors.push(`${asset.id}: author must be IsleWhispers`);
  if (!/^[a-z0-9-]+\.mp3$/.test(asset.publishedFileName)) errors.push(`${asset.id}: published file must be a lowercase MP3`);
  if (!/^[a-f0-9]{64}$/.test(asset.sha256)) errors.push(`${asset.id}: SHA-256 must be recorded`);
}
if (expectedIds.size) errors.push(`catalog assets missing from manifest: ${[...expectedIds].join(', ')}`);

if (errors.length) {
  console.error(errors.join('\n'));
  process.exitCode = 1;
} else {
  console.log('16 audited self-owned CloudBase MP3 assets');
}
