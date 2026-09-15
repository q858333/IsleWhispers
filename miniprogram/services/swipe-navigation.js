const minimumSwipeDistance = 48;

export function nextSoundIndexFromSwipe(currentIndex, total, startX, endX) {
  if (!Number.isInteger(currentIndex) || total < 1 || Math.abs(endX - startX) < minimumSwipeDistance) return currentIndex;
  return endX < startX ? (currentIndex + 1) % total : (currentIndex - 1 + total) % total;
}
