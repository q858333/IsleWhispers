export class AudioLoader {
  constructor({ cloud, fileSystem, userDataPath, fileIdPrefix, directory }) {
    this.cloud = cloud;
    this.fileSystem = fileSystem;
    this.userDataPath = userDataPath;
    this.fileIdPrefix = fileIdPrefix;
    this.directory = directory;
    this.pending = new Map();
    this.statuses = new Map();
    this.listeners = new Set();
  }

  fileID(sound) { return `${this.fileIdPrefix}/${this.directory}/${sound.audioFileName}`; }
  filePath(fileID) { return `${this.userDataPath}/islewhispers-${encodeURIComponent(fileID)}`; }
  getStatus(sound) { return this.statuses.get(this.fileID(sound))?.status || 'idle'; }
  subscribe(listener) { this.listeners.add(listener); return () => this.listeners.delete(listener); }
  setStatus(fileID, status) {
    this.statuses.set(fileID, { status });
    this.listeners.forEach((listener) => listener());
  }
  exists(path) {
    return new Promise((resolve) => {
      this.fileSystem.access({ path, success: () => resolve(true), fail: () => resolve(false) });
    });
  }
  async load(fileID) {
    const filePath = this.filePath(fileID);
    this.setStatus(fileID, 'checking');
    try {
      if (await this.exists(filePath)) {
        this.setStatus(fileID, 'cached');
        return filePath;
      }
      this.setStatus(fileID, 'downloading');
      const { tempFilePath } = await this.cloud.downloadFile({ fileID });
      return await new Promise((resolve) => {
        this.fileSystem.saveFile({
          tempFilePath,
          filePath,
          success: ({ savedFilePath }) => { this.setStatus(fileID, 'cached'); resolve(savedFilePath); },
          fail: () => { this.setStatus(fileID, 'temporary'); resolve(tempFilePath); }
        });
      });
    } catch (error) {
      this.setStatus(fileID, 'error');
      throw error;
    }
  }

  // 返回可供播放器使用的本地路径，同一声音的并发请求共享下载。
  resolve(sound) {
    const fileID = this.fileID(sound);
    if (!this.pending.has(fileID)) {
      this.pending.set(fileID, this.load(fileID).finally(() => this.pending.delete(fileID)));
    }
    return this.pending.get(fileID);
  }
}
