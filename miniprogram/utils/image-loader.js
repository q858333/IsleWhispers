export class ImageLoader {
  constructor({ cloud, fileSystem, userDataPath }) {
    this.cloud = cloud;
    this.fileSystem = fileSystem;
    this.userDataPath = userDataPath;
    this.pending = new Map();
    this.temporary = new Map();
  }

  exists(path) {
    return new Promise((resolve) => {
      this.fileSystem.access({ path, success: () => resolve(true), fail: () => resolve(false) });
    });
  }

  async load(fileID) {
    const filePath = `${this.userDataPath}/isle-image-${encodeURIComponent(fileID)}`;
    if (await this.exists(filePath)) return filePath;
    const cached = this.temporary.get(fileID);
    if (cached && await this.exists(cached)) return cached;
    this.temporary.delete(fileID);
    const { tempFilePath } = await this.cloud.downloadFile({ fileID });
    return new Promise((resolve) => {
      this.fileSystem.copyFile({
        srcPath: tempFilePath,
        destPath: filePath,
        success: () => resolve(filePath),
        fail: () => { this.temporary.set(fileID, tempFilePath); resolve(tempFilePath); }
      });
    });
  }

  // 返回可供 image 组件使用的本地路径，同一资源的并发请求共享下载。
  resolve(fileID) {
    if (!this.pending.has(fileID)) {
      this.pending.set(fileID, this.load(fileID).finally(() => this.pending.delete(fileID)));
    }
    return this.pending.get(fileID);
  }
}
