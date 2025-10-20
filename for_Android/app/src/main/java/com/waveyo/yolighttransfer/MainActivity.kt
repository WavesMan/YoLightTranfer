package com.waveyo.yolighttransfer

import android.Manifest
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.*
import androidx.core.app.ActivityCompat
import com.waveyo.yolighttransfer.manager.AppManager
import com.waveyo.yolighttransfer.navigation.YoLightTransferApp
import com.waveyo.yolighttransfer.ui.components.FileReceiveDialog
import com.waveyo.yolighttransfer.ui.theme.YoLightTransfer_for_andriodTheme

/**
 * 主Activity
 * 负责权限请求和应用管理器初始化
 */
class MainActivity : ComponentActivity() {
    private lateinit var appManager: AppManager
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 请求必要的权限
        ActivityCompat.requestPermissions(
            this,
            arrayOf(
                Manifest.permission.INTERNET,
                Manifest.permission.ACCESS_NETWORK_STATE,
                Manifest.permission.ACCESS_WIFI_STATE,
                Manifest.permission.READ_EXTERNAL_STORAGE,
                Manifest.permission.WRITE_EXTERNAL_STORAGE
            ),
            100
        )
        
        // 初始化应用管理器
        appManager = AppManager(this)
        appManager.initialize()
        
        enableEdgeToEdge()
        setContent {
            YoLightTransfer_for_andriodTheme {
                // 接收确认弹窗状态
                var showReceiveDialog by remember { mutableStateOf(false) }
                var senderDeviceName by remember { mutableStateOf("") }
                var receiveFileName by remember { mutableStateOf("") }
                var receiveFileSize by remember { mutableStateOf(0L) }
                var onUserDecision by remember { mutableStateOf<(Boolean) -> Unit>({}) }
                
                // 设置TCPServer的文件接收请求回调
                appManager.getTCPServer().onFileReceiveRequest = { deviceName, fileName, fileSize, callback ->
                    showReceiveDialog = true
                    senderDeviceName = deviceName
                    receiveFileName = fileName
                    receiveFileSize = fileSize
                    onUserDecision = callback
                }
                
                // 主应用
                YoLightTransferApp(appManager)
                
                // 文件接收确认弹窗
                if (showReceiveDialog) {
                    FileReceiveDialog(
                        senderDeviceName = senderDeviceName,
                        fileName = receiveFileName,
                        fileSize = receiveFileSize,
                        onAccept = {
                            showReceiveDialog = false
                            // 确认接收文件
                            onUserDecision(true)
                        },
                        onReject = {
                            showReceiveDialog = false
                            // 拒绝接收文件
                            onUserDecision(false)
                        },
                        onDismiss = {
                            showReceiveDialog = false
                            // 用户关闭弹窗，默认拒绝
                            onUserDecision(false)
                        }
                    )
                }
            }
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        appManager.cleanup()
    }
}
