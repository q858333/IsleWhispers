export const sounds = [
  ['rain-garden', '庭院细雨', '自然', '雨声落在安静的庭院'],
  ['rain-window', '窗边小雨', '自然', '贴近窗玻璃的雨声'],
  ['rain-roof', '屋檐雨滴', '自然', '屋顶与檐下的连绵雨声'],
  ['rain-evening', '傍晚阵雨', '自然', '适合放慢节奏的雨声'],
  ['wind-soft', '轻风掠过', '自然', '轻柔、开阔的风声'],
  ['wind-deep', '深谷风声', '自然', '低沉而持续的风声'],
  ['wind-ridge', '山脊来风', '自然', '起伏变化的空气流动'],
  ['wind-distant', '远方风声', '自然', '更遥远、疏朗的风声'],
  ['wind-night', '夜风微响', '自然', '夜晚陪伴感的风声'],
  ['wave-shore', '岸边海浪', '自然', '缓慢拍岸的海浪'],
  ['wave-tide', '潮汐回响', '自然', '轻盈回退的潮水'],
  ['wave-drift', '漂流水声', '自然', '细碎流动的水面声'],
  ['wave-swell', '海面涌动', '自然', '更有层次的海浪起伏'],
  ['night-crickets', '夏夜虫鸣', '氛围', '可循环的夜间虫鸣'],
  ['fire-spark', '微小火花', '生活', '短促、温暖的火焰声']
].map(([id, title, category, subtitle], index) => ({
  id,
  title,
  category,
  subtitle,
  audioPath: `/assets/audio/${id}.mp3`,
  theme: ['ocean', 'rain', 'sunset', 'forest'][index % 4]
}));
