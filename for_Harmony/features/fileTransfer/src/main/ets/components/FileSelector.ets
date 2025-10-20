/**
 * File selector component for selecting and displaying files
 */
@Component
export struct FileSelector {
  @Prop selectedFiles: FileInfo[];

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
  getTotalSize(): number {
    let total = 0;
    this.selectedFiles.forEach(file => {
      total += file.size;
    });
    return total;
  }

  build() {
    Column() {
      // File selection area
      Column() {
        Button('选择文件', { type: ButtonType.Normal })
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
          .fontColor($r('sys.color.ohos_id_color_white'))
          .borderRadius(8)
          .height(48)
          .width(200)
        
        Text('或拖拽文件到此区域')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .margin({ top: 8 })
      }
      .width('100%')
      .padding(32)
      .backgroundColor($r('sys.color.ohos_id_color_background'))
      .border({ width: 2, style: BorderStyle.Dashed, color: $r('sys.color.ohos_id_color_border') })
      .borderRadius(12)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      // Selected files list
      if (this.selectedFiles.length > 0) {
        Column() {
          Text('已选择文件:')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .margin({ bottom: 12 })

          ForEach(this.selectedFiles, (file: FileInfo) => {
            Row() {
              this.getFileIcon(file.type)
              
              Column() {
                Text(file.name)
                  .fontSize(14)
                  .fontColor($r('sys.color.ohos_id_color_text_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                
                Text(this.formatFileSize(file.size))
                  .fontSize(12)
                  .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              }
              .margin({ left: 12 })
              .layoutWeight(1)

              Button('删除', { type: ButtonType.Normal })
                .fontSize(12)
                .backgroundColor($r('sys.color.ohos_id_color_background'))
                .fontColor($r('sys.color.ohos_id_color_text_danger'))
                .border({ width: 1, color: $r('sys.color.ohos_id_color_border') })
                .borderRadius(4)
                .height(28)
                .width(48)
            }
            .width('100%')
            .padding(12)
            .backgroundColor($r('sys.color.ohos_id_color_background'))
            .borderRadius(8)
            .margin({ bottom: 8 })
          })

          // Summary
          Row() {
            Text(`总计: ${this.selectedFiles.length}个文件`)
              .fontSize(14)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
            
            Blank()
            
            Text(this.formatFileSize(this.getTotalSize()))
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.ohos_id_color_emphasize'))
          }
          .width('100%')
          .padding({ top: 12 })
          .border({ width: { top: 1 }, color: $r('sys.color.ohos_id_color_border') })

          // Upload button
          Button('上传到设备', { type: ButtonType.Normal })
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
            .fontColor($r('sys.color.ohos_id_color_white'))
            .borderRadius(8)
            .height(48)
            .width('100%')
            .margin({ top: 16 })
        }
        .width('100%')
        .padding(16)
        .backgroundColor($r('sys.color.ohos_id_color_background'))
        .border({ width: 1, color: $r('sys.color.ohos_id_color_border') })
        .borderRadius(12)
        .margin({ top: 16 })
      }
    }
    .width('100%')
    .padding(16)
  }
}

interface FileInfo {
  id: string;
  name: string;
  size: number;
  type: string;
}
