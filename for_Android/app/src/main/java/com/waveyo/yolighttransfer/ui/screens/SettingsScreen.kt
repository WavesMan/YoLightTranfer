package com.waveyo.yolighttransfer.ui.screens

import android.content.Context
import android.content.Intent
import android.net.Uri
import java.io.File
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.waveyo.yolighttransfer.manager.AppManager
import com.waveyo.yolighttransfer.ui.components.SectionCard

/**
 * 设置屏幕
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    modifier: Modifier = Modifier,
    appManager: AppManager
) {
    // 设置状态 - 从配置管理器加载
    var deviceName by rememberSaveable { mutableStateOf(appManager.getCurrentDeviceInfo().deviceName) }
    var tcpPort by rememberSaveable { mutableStateOf(appManager.getConfigManager().getTcpPort().toString()) }
    var chunkSize by rememberSaveable { mutableStateOf("1MB") }
    var timeout by rememberSaveable { mutableStateOf("30秒") }
    var autoReceive by rememberSaveable { mutableStateOf("启用") }
    var broadcastPort by rememberSaveable { mutableStateOf("7431") }
    var discoveryInterval by rememberSaveable { mutableStateOf("5秒") }
    
    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = { TopAppBar(title = { Text("配置") }) }
    ) { inner ->
        LazyColumn(
            modifier = Modifier
                .padding(inner)
                .fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item {
                SectionCard(title = "设备设置") {
                    OutlinedTextField(
                        value = deviceName,
                        onValueChange = { deviceName = it },
                        label = { Text("设备名称") },
                        modifier = Modifier.fillMaxWidth()
                    )
                    Spacer(Modifier.height(8.dp))
                    OutlinedTextField(
                        value = tcpPort,
                        onValueChange = { tcpPort = it },
                        label = { Text("TCP端口") },
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }
            
            item {
                SectionCard(title = "传输设置") {
                    OutlinedTextField(
                        value = chunkSize,
                        onValueChange = { chunkSize = it },
                        label = { Text("分片大小") },
                        modifier = Modifier.fillMaxWidth()
                    )
                    Spacer(Modifier.height(8.dp))
                    OutlinedTextField(
                        value = timeout,
                        onValueChange = { timeout = it },
                        label = { Text("超时时间") },
                        modifier = Modifier.fillMaxWidth()
                    )
                    Spacer(Modifier.height(8.dp))
                    OutlinedTextField(
                        value = autoReceive,
                        onValueChange = { autoReceive = it },
                        label = { Text("自动接收") },
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }
            
            item {
                SectionCard(title = "网络设置") {
                    OutlinedTextField(
                        value = "7431",
                        onValueChange = { },
                        label = { Text("广播端口") },
                        modifier = Modifier.fillMaxWidth(),
                        enabled = false,
                        readOnly = true
                    )
                    Spacer(Modifier.height(8.dp))
                    OutlinedTextField(
                        value = discoveryInterval,
                        onValueChange = { discoveryInterval = it },
                        label = { Text("发现间隔") },
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }
            
            item {
                SectionCard(title = "文件管理") {
                    Text(
                        text = "部分系统可能无法打开下载文件夹，或不显示文件，请尝试手动打开 “公共下载目录/YoLightTransfer” ",
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(bottom = 8.dp),
                        fontWeight = FontWeight.Normal
                    )
                    val context = LocalContext.current
                    Button(
                        onClick = {
                            // 打开下载文件夹
                            openDownloadsFolder(context)
                        },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("打开下载文件夹")
                    }
                }
            }
            
            item {
                Row(
                    modifier = Modifier
                        .padding(horizontal = 16.dp)
                        .fillMaxWidth(),
                    horizontalArrangement = Arrangement.End
                ) {
                    Button(
                        onClick = {
                            // 保存配置
                            appManager.updateDeviceName(deviceName)
                            // 保存TCP端口
                            try {
                                val port = tcpPort.toInt()
                                appManager.getConfigManager().saveTcpPort(port)
                            } catch (e: NumberFormatException) {
                                // 端口格式错误，使用默认值
                                appManager.getConfigManager().saveTcpPort(7431)
                            }
                        }
                    ) { 
                        Text("保存") 
                    }
                }
            }
            
            item { Spacer(Modifier.height(16.dp)) }
        }
    }
}

/**
 * 打开下载文件夹
 */
private fun openDownloadsFolder(context: Context) {
    try {
        // 尝试直接打开YoLightTransfer文件夹
        val intent = Intent(Intent.ACTION_VIEW)
        val uri = Uri.parse("content://com.android.externalstorage.documents/document/primary:Download/YoLightTransfer")
        intent.setDataAndType(uri, "vnd.android.document/directory")
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    } catch (e: Exception) {
        try {
            // 如果上面的方法失败，尝试使用文件URI
            val downloadsDir = android.os.Environment.getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_DOWNLOADS)
            val appDir = File(downloadsDir, "YoLightTransfer")
            
            // 确保目录存在
            if (!appDir.exists()) {
                appDir.mkdirs()
            }
            
            val intent = Intent(Intent.ACTION_VIEW)
            val uri = Uri.fromFile(appDir)
            intent.setDataAndType(uri, "resource/folder")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        } catch (e2: Exception) {
            try {
                // 如果还是失败，使用默认文件管理器打开下载目录
                val intent = Intent(Intent.ACTION_VIEW)
                val uri = Uri.parse("content://downloads/public_downloads")
                intent.setDataAndType(uri, "vnd.android.document/directory")
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
            } catch (e3: Exception) {
                // 最后尝试使用系统设置
                val intent = Intent(android.provider.Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
            }
        }
    }
}
