const keys = {
  selectedSoundId: 'isleWhispers.selectedSoundId',
  muted: 'isleWhispers.muted',
  recentSoundIds: 'isleWhispers.recentSoundIds'
};

export function createStorage(adapter) {
  return {
    getSelectedSoundId() {
      const value = adapter.getStorageSync(keys.selectedSoundId);
      return typeof value === 'string' ? value : null;
    },
    setSelectedSoundId(id) {
      adapter.setStorageSync(keys.selectedSoundId, id);
    },
    getMuted() {
      return adapter.getStorageSync(keys.muted) === true;
    },
    setMuted(muted) {
      adapter.setStorageSync(keys.muted, muted === true);
    },
    getRecentSoundIds() {
      const ids = adapter.getStorageSync(keys.recentSoundIds);
      return Array.isArray(ids) ? ids.filter((id) => typeof id === 'string').slice(0, 6) : [];
    },
    recordRecent(id) {
      const next = [id, ...this.getRecentSoundIds().filter((value) => value !== id)].slice(0, 6);
      adapter.setStorageSync(keys.recentSoundIds, next);
    }
  };
}
