import { fileTransfer } from '@ohos/filetransfer';

/**
 * YoLightTransfer - File Transfer Application
 * Main entry point for the file transfer application
 */
@Entry
@Component
struct Index {
  aboutToAppear() {
    // 正确：在生命周期函数中调用逻辑
    fileTransfer.start();
  }

  build() {
    Column() {
      // UI组件
    }
  }
}
