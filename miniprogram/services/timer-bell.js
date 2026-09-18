export function createTimerBell(wxApi) {
  let audio = null;
  let stopTimer = null;
  const stop = () => {
    if (stopTimer !== null) clearTimeout(stopTimer);
    stopTimer = null;
    if (!audio) return;
    const previous = audio;
    audio = null;
    previous.destroy();
  };
  return {
    play() {
      stop();
      const current = wxApi.createInnerAudioContext();
      audio = current;
      current.loop = true;
      current.volume = 0.6;
      current.src = '/assets/notifications/timer-bell.mp3';
      const finish = () => { if (audio === current) stop(); };
      current.onEnded(finish);
      current.onError(finish);
      stopTimer = setTimeout(finish, 30_000);
      current.play();
    },
    isRinging: () => audio !== null,
    stop
  };
}
