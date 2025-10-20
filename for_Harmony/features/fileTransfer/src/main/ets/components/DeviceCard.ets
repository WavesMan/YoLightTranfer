/**
 * Device card component for displaying device information
 */
@Component
export struct DeviceCard {
  @Prop device: DeviceInfo;

  @Builder
  getDeviceIcon(type: string) {
    switch (type) {
      case 'windows':
        SymbolGlyph($r('sys.symbol.laptop'))
          .fontSize(32)
          .fontColor('#0078D4')
        break;
      case 'android':
        SymbolGlyph($r('sys.symbol.smartphone'))
          .fontSize(32)
          .fontColor('#3DDC84')
        break;
      case 'harmony':
        SymbolGlyph($r('sys.symbol.devices'))
          .fontSize(32)
          .fontColor('#FF0000')
        break;
      case 'linux':
        SymbolGlyph($r('sys.symbol.computer'))
          .fontSize(32)
          .fontColor('#FCC624')
        break;
      case 'macos':
        SymbolGlyph($r('sys.symbol.desktop_mac'))
          .fontSize(32)
          .fontColor('#000000')
        break;
      default:
        SymbolGlyph($r('sys.symbol.devices'))
          .fontSize(32)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
    }
  }

  @Builder
  getStatusBadge(status: string) {
    let bgColor: Resource = $r('sys.color.ohos_id_color_text_success');
    let text: string = '在线';
    
    if (status === 'offline') {
      bgColor = $r('sys.color.ohos_id_color_text_danger');
      text = '离线';
    } else if (status === 'connecting') {
      bgColor = $r('sys.color.ohos_id_color_text_warning');
      text = '连接中';
    }

    Text(text)
      .fontSize(10)
      .fontColor($r('sys.color.ohos_id_color_white'))
      .backgroundColor(bgColor)
      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
      .borderRadius(4)
  }

  build() {
    Column() {
      // Device icon and info
      Row() {
        this.getDeviceIcon(this.device.type)
        
        Column() {
          Text(this.device.name)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          
          Text(this.device.ip)
            .fontSize(12)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          
          Row() {
            this.getStatusBadge(this.device.status)
            Text(`· ${this.device.lastSeen}`)
              .fontSize(10)
              .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
          }
          .alignItems(VerticalAlign.Center)
        }
        .margin({ left: 12 })
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      // Action buttons
      Row() {
        Button('发送文件', { type: ButtonType.Normal })
          .fontSize(12)
          .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
          .fontColor($r('sys.color.ohos_id_color_white'))
          .borderRadius(6)
          .height(32)
          .layoutWeight(1)
        
        Button('查看详情', { type: ButtonType.Normal })
          .fontSize(12)
          .backgroundColor($r('sys.color.ohos_id_color_background'))
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .border({ width: 1, color: $r('sys.color.ohos_id_color_border') })
          .borderRadius(6)
          .height(32)
          .margin({ left: 8 })
          .layoutWeight(1)
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width(280)
    .padding(16)
    .backgroundColor($r('sys.color.ohos_id_color_background'))
    .border({ width: 1, color: $r('sys.color.ohos_id_color_border') })
    .borderRadius(12)
    .shadow({ radius: 8, color: '#1A000000', offsetX: 0, offsetY: 2 })
  }
}

interface DeviceInfo {
  id: string;
  name: string;
  type: string;
  ip: string;
  status: string;
  lastSeen: string;
}
