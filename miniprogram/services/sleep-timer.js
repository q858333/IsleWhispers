export function createSleepTimer(clock) {
  let deadline = null;
  let pausedRemaining = null;

  return {
    schedule(minutes) {
      deadline = minutes > 0 ? clock.now() + minutes * 60_000 : null;
      pausedRemaining = null;
    },
    pause() {
      if (deadline === null) return;
      pausedRemaining = Math.max(0, deadline - clock.now());
      deadline = null;
    },
    resume() {
      if (pausedRemaining === null) return;
      deadline = clock.now() + pausedRemaining;
      pausedRemaining = null;
    },
    remainingMs() {
      if (deadline !== null) return Math.max(0, deadline - clock.now());
      return pausedRemaining;
    },
    consumeExpiry() {
      if (deadline === null || deadline > clock.now()) return false;
      deadline = null;
      return true;
    }
  };
}
