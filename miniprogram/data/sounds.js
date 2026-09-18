import { cloudAudio } from '../config/cloud-audio.js';

export const sounds = [
  { id: 'tea', title: '咖啡厅', category: '生活', subtitle: '咖啡厅环境声', audioFileName: 'tea.mp3', backgroundPath: `${cloudAudio.fileIdPrefix}/backgrounds/tea.jpg`, theme: 'forest' },
  { id: 'thunder', title: '雷声', category: '自然', subtitle: '低沉而遥远', audioFileName: 'thunder.mp3', backgroundPath: `${cloudAudio.fileIdPrefix}/backgrounds/thunder.jpg`, theme: 'sunset' },
  { id: 'rain', title: '雨声', category: '自然', subtitle: '均匀落在窗边', audioFileName: 'rain.mp3', backgroundPath: `${cloudAudio.fileIdPrefix}/backgrounds/rain.jpg`, theme: 'rain' },
  { id: 'fire', title: '火炉', category: '生活', subtitle: '轻柔木柴噼啪', audioFileName: 'fire.mp3', backgroundPath: `${cloudAudio.fileIdPrefix}/backgrounds/fire.jpg`, theme: 'forest' },
  { id: 'water', title: '水流', category: '自然', subtitle: '舒缓连续水声', audioFileName: 'water.mp3', backgroundPath: `${cloudAudio.fileIdPrefix}/backgrounds/water.jpg`, theme: 'ocean' },
  { id: 'wind', title: '风声', category: '自然', subtitle: '空气缓慢流动', audioFileName: 'wind.mp3', backgroundPath: `${cloudAudio.fileIdPrefix}/backgrounds/wind.jpg`, theme: 'ocean' },
  { id: 'day', title: '林间', category: '氛围', subtitle: '林间自然环境', audioFileName: 'day.mp3', backgroundPath: `${cloudAudio.fileIdPrefix}/backgrounds/day.jpg`, theme: 'sunset' },
  { id: 'night', title: '夜晚', category: '氛围', subtitle: '深夜低噪氛围', audioFileName: 'night.mp3', backgroundPath: `${cloudAudio.fileIdPrefix}/backgrounds/night.jpg`, theme: 'rain' },
  { id: 'river', title: '河流', category: '自然', subtitle: '清澈而连续的水纹', audioFileName: 'river.mp3', backgroundPath: `${cloudAudio.fileIdPrefix}/backgrounds/river.jpg`, theme: 'ocean' },
  { id: 'space', title: '太空', category: '氛围', subtitle: '宽阔漂浮氛围', audioFileName: 'space.mp3', backgroundPath: `${cloudAudio.fileIdPrefix}/backgrounds/space.jpg`, theme: 'rain' },
  { id: 'yacht', title: '游艇', category: '生活', subtitle: '海面与船体轻响', audioFileName: 'yacht.mp3', backgroundPath: `${cloudAudio.fileIdPrefix}/backgrounds/yacht.jpg`, theme: 'ocean' },
  { id: 'train', title: '火车', category: '生活', subtitle: '规律远行节奏', audioFileName: 'train.mp3', backgroundPath: `${cloudAudio.fileIdPrefix}/backgrounds/train.jpg`, theme: 'sunset' },
  { id: 'farm', title: '农场', category: '自然', subtitle: '开阔乡间声景', audioFileName: 'farm.mp3', backgroundPath: `${cloudAudio.fileIdPrefix}/backgrounds/farm.jpg`, theme: 'forest' },
  { id: 'chimes', title: '风铃', category: '生活', subtitle: '清脆稀疏回响', audioFileName: 'chimes.mp3', backgroundPath: `${cloudAudio.fileIdPrefix}/backgrounds/chimes.jpg`, theme: 'ocean' },
  { id: 'whale', title: '鲸歌', category: '自然', subtitle: '深海悠长低吟', audioFileName: 'whale.mp3', backgroundPath: `${cloudAudio.fileIdPrefix}/backgrounds/whale.jpg`, theme: 'rain' },
  { id: 'dripping-water', title: '滴水回声', category: '自然', subtitle: '可循环的洞穴滴水声', audioFileName: 'dripping-water.mp3', backgroundPath: `${cloudAudio.fileIdPrefix}/backgrounds/dripping-water.jpg`, theme: 'rain' }
];
