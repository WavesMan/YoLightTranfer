import { commonConstants } from '@ohos/common';
import { BreakpointSystem, BreakPointType } from '@ohos/common';
import { DeviceCard } from '../components/DeviceCard';
import { FileSelector } from '../components/FileSelector';
import { TransferItem } from '../components/TransferItem';

/**
 * File transfer main page with bottom navigation
 */
@Entry
@Component
export struct FileTransferMain {
  @State currentTab: number = 0;
  @StorageLink('mainBreakpoint') currentBreakpoint: string = commonConstants.breakpointsInitializeName;
  private readonly breakpointSystem: BreakpointSystem = new BreakpointSystem(commonConstants.breakpointSystemName);

  // Mock data for demonstration
  @State devices: DeviceInfo[] = [
    { id: '1', name: 'Windows-PC', type: 'windows', ip: '192.168.1.100:7431', status: 'online', lastSeen: '5秒前' },
    { id: '2', name: 'Android-12', type: 'android', ip: '192.168.1.101:7431', status: 'online', lastSeen: '2秒前' }
  ];

  @State selectedFiles: FileInfo[] = [];
  @State transferTasks: TransferTask[] = [
    { id: '1', fileName: 'document.pdf', progress: 45, totalSize: 5.1, transferredSize: 2.3, status: 'transferring', estimatedTime: '约30秒' }
  ];

  aboutToAppear() {
    this.breakpointSystem.register(this.getUIContext());
  }

  aboutToDisappear() {
    this.breakpointSystem.unregister();
  }

  @Builder
  HomePage() {
    Column() {
      // Status bar
      Row() {
        Text('连接状态: 已连接')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        Blank()
        Text('WiFi')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_success'))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })

      // Title and search
      Column() {
        Text('设备发现')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
        TextInput({ placeholder: '搜索设备...' })
          .width('100%')
          .height(40)
          .backgroundColor($r('sys.color.ohos_id_color_background'))
          .borderRadius(8)
          .padding({ left: 12, right: 12 })
      }
      .width('100%')
      .padding(16)

      // Online devices section
      Column() {
        Row() {
          Text('在线设备 (2)')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
          Blank()
        }
        .width('100%')

        Scroll() {
          Row() {
            ForEach(this.devices, (device: DeviceInfo) => {
              DeviceCard({ device: device })
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
        }
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .padding(16)

      // File selection section
      FileSelector({ selectedFiles: this.selectedFiles })

      // Transfer queue section
      Column() {
        Text('传输任务队列')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .margin({ bottom: 12 })

        ForEach(this.transferTasks, (task: TransferTask) => {
          TransferItem({ task: task })
        })
      }
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }

  @Builder
  SettingsPage() {
    Column() {
      Text('配置页面')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .margin({ top: 20, bottom: 20 })
      
      // Settings content will be implemented later
      Text('设备设置、传输设置、网络设置')
        .fontSize(16)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }

  @Builder
  ProfilePage() {
    Column() {
      Text('我的页面')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .margin({ top: 20, bottom: 20 })
      
      // Profile content will be implemented later
      Text('用户信息、应用信息、数据统计')
        .fontSize(16)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }

  @Builder
  BottomNavigation() {
    Row() {
      // Home tab
      Column() {
        SymbolGlyph($r('sys.symbol.home'))
          .fontSize(24)
          .fontColor(this.currentTab === 0 ? 
            $r('sys.color.ohos_id_color_emphasize') : 
            $r('sys.color.ohos_id_color_text_secondary'))
        Text('主页')
          .fontSize(12)
          .fontColor(this.currentTab === 0 ? 
            $r('sys.color.ohos_id_color_emphasize') : 
            $r('sys.color.ohos_id_color_text_secondary'))
      }
      .onClick(() => {
        this.currentTab = 0;
      })
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      // Settings tab
      Column() {
        SymbolGlyph($r('sys.symbol.settings'))
          .fontSize(24)
          .fontColor(this.currentTab === 1 ? 
            $r('sys.color.ohos_id_color_emphasize') : 
            $r('sys.color.ohos_id_color_text_secondary'))
        Text('配置')
          .fontSize(12)
          .fontColor(this.currentTab === 1 ? 
            $r('sys.color.ohos_id_color_emphasize') : 
            $r('sys.color.ohos_id_color_text_secondary'))
      }
      .onClick(() => {
        this.currentTab = 1;
      })
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      // Profile tab
      Column() {
        SymbolGlyph($r('sys.symbol.person'))
          .fontSize(24)
          .fontColor(this.currentTab === 2 ? 
            $r('sys.color.ohos_id_color_emphasize') : 
            $r('sys.color.ohos_id_color_text_secondary'))
        Text('我的')
          .fontSize(12)
          .fontColor(this.currentTab === 2 ? 
            $r('sys.color.ohos_id_color_emphasize') : 
            $r('sys.color.ohos_id_color_text_secondary'))
      }
      .onClick(() => {
        this.currentTab = 2;
      })
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height(64)
    .backgroundColor($r('sys.color.ohos_id_color_background'))
    .border({ width: { top: 1 }, color: $r('sys.color.ohos_id_color_border') })
  }

  build() {
    Column() {
      // Main content area
      Column() {
        if (this.currentTab === 0) {
          this.HomePage()
        } else if (this.currentTab === 1) {
          this.SettingsPage()
        } else {
          this.ProfilePage()
        }
      }
      .layoutWeight(1)

      // Bottom navigation
      this.BottomNavigation()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }
}

// Data models
interface DeviceInfo {
  id: string;
  name: string;
  type: string;
  ip: string;
  status: string;
  lastSeen: string;
}

interface FileInfo {
  id: string;
  name: string;
  size: number;
  type: string;
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
