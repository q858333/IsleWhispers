export function createCloudAudioSource({ cloud, fileSystem, userDataPath, fileIdPrefix, directory }) {
  const pending = new Map();

  const load = async (fileID) => {
    const filePath = `${userDataPath}/islewhispers-${encodeURIComponent(fileID)}`;
    const exists = await new Promise((resolve) => {
      fileSystem.access({ path: filePath, success: () => resolve(true), fail: () => resolve(false) });
    });
    if (exists) return filePath;

    const { tempFilePath } = await cloud.downloadFile({ fileID });
    return new Promise((resolve) => {
      fileSystem.saveFile({
        tempFilePath,
        filePath,
        success: ({ savedFilePath }) => resolve(savedFilePath),
        fail: () => resolve(tempFilePath)
      });
    });
  };

  return {
    resolve(sound) {
      const fileID = `${fileIdPrefix}/${directory}/${sound.audioFileName}`;
      if (!pending.has(fileID)) {
        pending.set(fileID, load(fileID).finally(() => pending.delete(fileID)));
      }
      return pending.get(fileID);
    }
  };
}
