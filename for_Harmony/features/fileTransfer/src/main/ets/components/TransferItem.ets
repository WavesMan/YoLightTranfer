/**
 * Transfer item component for displaying file transfer progress
 */
@Component
export struct TransferItem {
  @Prop task: TransferTask;

  @Builder
  getFileIcon(type: string) {
    switch (type) {
      case 'pdf':
        SymbolGlyph($r('sys.symbol.picture_as_pdf'))
          .fontSize(24)
          .fontColor('#F44336')
        break;
      case 'image':
        SymbolGlyph($r('sys.symbol.image'))
          .fontSize(24)
          .fontColor('#4CAF50')
        break;
      case 'video':
        SymbolGlyph($r('sys.symbol.video_file'))
          .fontSize(24)
          .fontColor('#2196F3')
        break;
      case 'document':
        SymbolGlyph($r('sys.symbol.description'))
          .fontSize(24)
          .fontColor('#FF9800')
        break;
      default:
        SymbolGlyph($r('sys.symbol.insert_drive_file'))
          .fontSize(24)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
    }
  }

  @Builder
  getStatusIcon(status: string) {
    switch (status) {
      case 'transferring':
        SymbolGlyph($r('sys.symbol.sync'))
          .fontSize(16)
          .fontColor($r('sys.color.ohos_id_color_text_warning'))
        break;
      case 'completed':
        SymbolGlyph($r('sys.symbol.check_circle'))
          .fontSize(16)
          .fontColor($r('sys.color.ohos_id_color_text_success'))
        break;
      case 'failed':
        SymbolGlyph($r('sys.symbol.error'))
          .fontSize(16)
          .fontColor($r('sys.color.ohos_id_color_text_danger'))
        break;
      case 'waiting':
        SymbolGlyph($r('sys.symbol.schedule'))
          .fontSize(16)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        break;
      default:
        SymbolGlyph($r('sys.symbol.help'))
          .fontSize(16)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
    }
  }

  @Builder
  getStatusText(status: string): string {
    switch (status) {
      case 'transferring':
        return '传输中';
      case 'completed':
        return '已完成';
      case 'failed':
        return '传输失败';
      case 'waiting':
        return '等待中';
      default:
        return '未知状态';
    }
  }

  @Builder
  formatFileSize(size: number): string {
    if (size < 1024) {
      return `${size} B`;
    } else if (size < 1024 * 1024) {
      return `${(size / 1024).toFixed(1)} KB`;
    } else if (size < 1024 * 1024 * 1024) {
      return `${(size / (1024 * 1024)).toFixed(1)} MB`;
    } else {
      return `${(size / (1024 * 1024 * 1024)).toFixed(1)} GB`;
    }
  }

  @Builder
  getFileType(fileName: string): string {
    const ext = fileName.split('.').pop()?.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'pdf';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
        return 'image';
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
        return 'video';
      case 'doc':
      case 'docx':
      case 'txt':
      case 'xls':
      case 'xlsx':
        return 'document';
      default:
        return 'file';
    }
  }

  build() {
    Column() {
      // File info and progress
      Row() {
        this.getFileIcon(this.getFileType(this.task.fileName))
        
        Column() {
          Text(this.task.fileName)
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          
          // Progress bar
          Row() {
            // Progress track
            Row() {
              // Progress fill
              Row() {
                Blank()
              }
              .width(`${this.task.progress}%`)
              .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
              .borderRadius(4)
              
              // Progress background
              Blank()
                .layoutWeight(1)
                .backgroundColor($r('sys.color.ohos_id_color_background'))
                .borderRadius(4)
            }
            .width('100%')
            .height(8)
            .backgroundColor($r('sys.color.ohos_id_color_background'))
            .borderRadius(4)
          }
          .width('100%')
          .margin({ top: 4, bottom: 4 })

          // Progress details
          Row() {
            Text(`${this.task.progress}% · ${this.formatFileSize(this.task.transferredSize * 1024 * 1024)}/${this.formatFileSize(this.task.totalSize * 1024 * 1024)}`)
              .fontSize(12)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            
            Blank()
            
            Row() {
              this.getStatusIcon(this.task.status)
              Text(this.getStatusText(this.task.status))
                .fontSize(12)
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                .margin({ left: 4 })
            }
            .alignItems(VerticalAlign.Center)
          }
          .width('100%')

          // Estimated time
          if (this.task.status === 'transferring' && this.task.estimatedTime) {
            Text(`剩余${this.task.estimatedTime}`)
              .fontSize(11)
              .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
              .margin({ top: 2 })
          }
        }
        .margin({ left: 12 })
        .layoutWeight(1)

        // Action buttons
        if (this.task.status === 'transferring') {
          Button('暂停', { type: ButtonType.Normal })
            .fontSize(12)
            .backgroundColor($r('sys.color.ohos_id_color_background'))
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .border({ width: 1, color: $r('sys.color.ohos_id_color_border') })
            .borderRadius(4)
            .height(28)
            .width(48)
        } else if (this.task.status === 'failed') {
          Button('重试', { type: ButtonType.Normal })
            .fontSize(12)
            .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
            .fontColor($r('sys.color.ohos_id_color_white'))
            .borderRadius(4)
            .height(28)
            .width(48)
        } else if (this.task.status === 'waiting') {
          Button('取消', { type: ButtonType.Normal })
            .fontSize(12)
            .backgroundColor($r('sys.color.ohos_id_color_background'))
            .fontColor($r('sys.color.ohos_id_color_text_danger'))
            .border({ width: 1, color: $r('sys.color.ohos_id_color_border') })
            .borderRadius(4)
            .height(28)
            .width(48)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.ohos_id_color_background'))
    .border({ width: 1, color: $r('sys.color.ohos_id_color_border') })
    .borderRadius(12)
    .margin({ bottom: 8 })
  }
}

interface TransferTask {
  id: string;
  fileName: string;
  progress: number;
  totalSize: number;
  transferredSize: number;
  status: string;
  estimatedTime: string;
}
