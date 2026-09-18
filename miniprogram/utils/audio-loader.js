export class AudioLoader {
  constructor({ cloud, fileSystem, userDataPath, fileIdPrefix, directory }) {
    this.cloud = cloud;
    this.fileSystem = fileSystem;
    this.userDataPath = userDataPath;
    this.fileIdPrefix = fileIdPrefix;
    this.directory = directory;
    this.pending = new Map();
  }

  async load(fileID) {
    const filePath = `${this.userDataPath}/islewhispers-${encodeURIComponent(fileID)}`;
    const exists = await new Promise((resolve) => {
      this.fileSystem.access({ path: filePath, success: () => resolve(true), fail: () => resolve(false) });
    });
    if (exists) return filePath;

    const { tempFilePath } = await this.cloud.downloadFile({ fileID });
    return new Promise((resolve) => {
      this.fileSystem.saveFile({
        tempFilePath,
        filePath,
        success: ({ savedFilePath }) => resolve(savedFilePath),
        fail: () => resolve(tempFilePath)
      });
    });
  }

  // 返回可供播放器使用的本地路径，同一声音的并发请求共享下载。
  resolve(sound) {
    const fileID = `${this.fileIdPrefix}/${this.directory}/${sound.audioFileName}`;
    if (!this.pending.has(fileID)) {
      this.pending.set(fileID, this.load(fileID).finally(() => this.pending.delete(fileID)));
    }
    return this.pending.get(fileID);
  }
}
