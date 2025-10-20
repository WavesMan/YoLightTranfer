package com.waveyo.yolighttransfer.ui.screens

import android.net.Uri
import android.util.Log
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Divider
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.waveyo.yolighttransfer.manager.AppManager
import com.waveyo.yolighttransfer.model.DeviceInfo
import com.waveyo.yolighttransfer.model.FileTransferInfo
import com.waveyo.yolighttransfer.ui.components.DeviceCard
import com.waveyo.yolighttransfer.ui.components.SectionCard
import com.waveyo.yolighttransfer.ui.components.TransferItem
import kotlinx.coroutines.delay

/**
 * 主屏幕 - 设备发现和文件传输
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    modifier: Modifier = Modifier,
    appManager: AppManager
) {
    val context = LocalContext.current
    
    // 状态管理
    var onlineDevices by rememberSaveable { mutableStateOf(emptyList<DeviceInfo>()) }
    val allTransfersState = appManager.getProgressManager().allTransfers.collectAsState()
    var selectedFiles by rememberSaveable { mutableStateOf<List<Uri>>(emptyList()) }
    var searchQuery by rememberSaveable { mutableStateOf("") }
    var selectedDevice by rememberSaveable { mutableStateOf<DeviceInfo?>(null) }
    var showDeviceSelection by rememberSaveable { mutableStateOf(false) }
    var showFileReceiveDialog by rememberSaveable { mutableStateOf(false) }
    var fileReceiveInfo by rememberSaveable { mutableStateOf<Triple<String, String, Long>?>(null) }
    var fileReceiveCallback by rememberSaveable { mutableStateOf<((Boolean) -> Unit)?>(null) }
    
    // 文件选择器 - 使用更稳定的实现
    val filePickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetMultipleContents(),
        onResult = { uris ->
            Log.d("HomeScreen", "文件选择器返回结果: ${uris.size} 个文件")
            if (uris.isNotEmpty()) {
                selectedFiles = uris
                Log.i("HomeScreen", "成功选择 ${uris.size} 个文件: ${uris.map { it.toString() }}")
            } else {
                Log.w("HomeScreen", "文件选择器返回空结果")
            }
        }
    )
    
    // 监听设备列表更新
    LaunchedEffect(Unit) {
        appManager.onDeviceListUpdated = {
            onlineDevices = appManager.getOnlineDevices()
        }
        
        // 设置文件接收请求回调
        appManager.onFileReceiveRequest = { senderDeviceName, fileName, fileSize, callback ->
            fileReceiveInfo = Triple(senderDeviceName, fileName, fileSize)
            fileReceiveCallback = callback
            showFileReceiveDialog = true
        }
        
        // 初始加载
        onlineDevices = appManager.getOnlineDevices()
        
        // 定期更新设备列表
        while (true) {
            delay(2000)
            onlineDevices = appManager.getOnlineDevices()
        }
    }
    
    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            TopAppBar(title = { Text("设备发现", fontWeight = FontWeight.Bold) })
        }
    ) { inner ->
        LazyColumn(
            modifier = Modifier
                .padding(inner)
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.surface),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item {
                // 状态栏: 连接状态
                Card(
                    modifier = Modifier
                        .padding(horizontal = 16.dp)
                        .fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
                ) {
                    Text(
                        text = "连接状态：已连接 (${onlineDevices.size} 个设备在线)",
                        modifier = Modifier.padding(16.dp),
                        style = MaterialTheme.typography.bodyLarge
                    )
                }
            }
            
            // item {
            //     // 搜索框
            //     Column(Modifier.padding(horizontal = 16.dp)) {
            //         Text("设备发现", fontWeight = FontWeight.SemiBold)
            //         Spacer(Modifier.height(8.dp))
            //         OutlinedTextField(
            //             value = searchQuery,
            //             onValueChange = { searchQuery = it },
            //             modifier = Modifier.fillMaxWidth(),
            //             label = { Text("搜索设备...") }
            //         )
            //     }
            // }
            
            item {
                // 设备选择区域
                Column(Modifier.padding(horizontal = 16.dp)) {
                    Text("目标设备", fontWeight = FontWeight.SemiBold)
                    Spacer(Modifier.height(8.dp))
                    
                    if (onlineDevices.isNotEmpty()) {
                        // 设备选择按钮
                        OutlinedButton(
                            onClick = { showDeviceSelection = true },
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text(
                                text = selectedDevice?.deviceName ?: "选择目标设备...",
                                color = if (selectedDevice != null) MaterialTheme.colorScheme.primary 
                                       else MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        
                        // 显示已选设备信息
                        selectedDevice?.let { device ->
                            Spacer(Modifier.height(8.dp))
                            Card(
                                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
                            ) {
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(12.dp),
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Column {
                                        Text(
                                            text = device.deviceName,
                                            fontWeight = FontWeight.Medium
                                        )
                                        Text(
                                            text = "IP: ${device.ipAddress}",
                                            style = MaterialTheme.typography.bodySmall,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }
                                    OutlinedButton(
                                        onClick = { selectedDevice = null },
                                        modifier = Modifier.height(32.dp)
                                    ) {
                                        Text("更换", style = MaterialTheme.typography.labelSmall)
                                    }
                                }
                            }
                        }
                    } else {
                        Text("未发现在线设备", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
            
            item {
                // 文件选择区域
                SectionCard(title = "文件传输") {
                    Button(
                        onClick = { filePickerLauncher.launch("*/*") }
                    ) { 
                        Text("选择文件") 
                    }
                    Spacer(Modifier.height(8.dp))
                    Text("或拖拽文件到此区域", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(Modifier.height(8.dp))
                    Text(
                        "已选择: ${selectedFiles.size}个文件",
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
            
            if (selectedDevice != null && selectedFiles.isNotEmpty()) {
                item {
                    // 上传按钮
                    Row(
                        modifier = Modifier
                            .padding(horizontal = 16.dp)
                            .fillMaxWidth(),
                        horizontalArrangement = Arrangement.End
                    ) {
                        Button(
                            onClick = {
                                Log.i("HomeScreen", "开始上传文件: ${selectedFiles.size} 个文件到设备 ${selectedDevice!!.deviceName}")
                                selectedFiles.forEach { fileUri ->
                                    selectedDevice?.let { device ->
                                        Log.d("HomeScreen", "添加文件到传输队列: $fileUri 到设备: ${device.deviceName} (${device.ipAddress})")
                                        
                                        // 创建传输信息并添加到队列
                                        val fileInfo = getFileInfo(fileUri, context)
                                        if (fileInfo != null) {
                                            val transferInfo = FileTransferInfo(
                                                fileName = fileInfo.first,
                                                fileSize = fileInfo.second,
                                                filePath = fileUri.toString(),
                                                targetDevice = device
                                            )
                                            appManager.addTransferToQueue(transferInfo)
                                        }
                                    }
                                }
                                // 清空选择状态
                                selectedFiles = emptyList()
                                selectedDevice = null
                            }
                        ) { 
                            Text("上传到 ${selectedDevice!!.deviceName}") 
                        }
                    }
                }
            }
            
            if (allTransfersState.value.isNotEmpty()) {
                item {
                    // 传输任务队列
                    SectionCard(title = "传输任务队列") {
                        allTransfersState.value.forEach { transfer ->
                            TransferItem(
                                name = transfer.fileName,
                                progressText = "${(transfer.progress * 100).toInt()}% · ${formatBytes(transfer.transferredBytes)}/${formatBytes(transfer.fileSize)}",
                                status = when (transfer.status) {
                                    com.waveyo.yolighttransfer.model.TransferStatus.TRANSFERRING -> "传输中"
                                    com.waveyo.yolighttransfer.model.TransferStatus.COMPLETED -> "已完成"
                                    com.waveyo.yolighttransfer.model.TransferStatus.FAILED -> "失败: ${transfer.errorMessage}"
                                    com.waveyo.yolighttransfer.model.TransferStatus.PAUSED -> "已暂停"
                                    com.waveyo.yolighttransfer.model.TransferStatus.CANCELLED -> "已取消"
                                    else -> "等待中"
                                },
                                progress = transfer.progress.toFloat(),
                                filePath = transfer.filePath,
                                transferStatus = transfer.status.name,
                                onPause = {
                                    if (transfer.status == com.waveyo.yolighttransfer.model.TransferStatus.TRANSFERRING) {
                                        appManager.pauseTransfer(transfer.fileName)
                                    }
                                },
                                onResume = {
                                    if (transfer.status == com.waveyo.yolighttransfer.model.TransferStatus.PAUSED) {
                                        appManager.resumeTransfer(transfer.fileName)
                                    }
                                },
                                onCancel = {
                                    if (transfer.status != com.waveyo.yolighttransfer.model.TransferStatus.COMPLETED && 
                                        transfer.status != com.waveyo.yolighttransfer.model.TransferStatus.CANCELLED) {
                                        appManager.cancelTransfer(transfer.fileName)
                                    }
                                },
                                onRetry = {
                                    if (transfer.status == com.waveyo.yolighttransfer.model.TransferStatus.FAILED) {
                                        appManager.retryTransfer(transfer.fileName)
                                    }
                                }
                            )
                        }
                    }
                }
            }
            
            item { Spacer(Modifier.height(16.dp)) }
        }
    }
    
    // 设备选择对话框
    if (showDeviceSelection) {
        DeviceSelectionDialog(
            onlineDevices = onlineDevices,
            onDeviceSelected = { device ->
                selectedDevice = device
                showDeviceSelection = false
            },
            onDismiss = { showDeviceSelection = false }
        )
    }
    
    // 文件接收确认对话框
    if (showFileReceiveDialog && fileReceiveInfo != null && fileReceiveCallback != null) {
        FileReceiveConfirmationDialog(
            senderDeviceName = fileReceiveInfo!!.first,
            fileName = fileReceiveInfo!!.second,
            fileSize = fileReceiveInfo!!.third,
            onAccept = {
                fileReceiveCallback?.invoke(true)
                showFileReceiveDialog = false
                fileReceiveInfo = null
                fileReceiveCallback = null
            },
            onReject = {
                fileReceiveCallback?.invoke(false)
                showFileReceiveDialog = false
                fileReceiveInfo = null
                fileReceiveCallback = null
            },
            onDismiss = {
                fileReceiveCallback?.invoke(false)
                showFileReceiveDialog = false
                fileReceiveInfo = null
                fileReceiveCallback = null
            }
        )
    }
}

/**
 * 格式化时间戳为可读格式
 */
private fun formatTimestamp(timestamp: Long): String {
    val diff = System.currentTimeMillis() - timestamp
    return when {
        diff < 1000 -> "刚刚"
        diff < 60000 -> "${diff / 1000}秒前"
        diff < 3600000 -> "${diff / 60000}分钟前"
        diff < 86400000 -> "${diff / 3600000}小时前"
        else -> "${diff / 86400000}天前"
    }
}

/**
 * 格式化字节大小为可读格式
 */
private fun formatBytes(bytes: Long): String {
    return when {
        bytes < 1024 -> "$bytes B"
        bytes < 1024 * 1024 -> "${bytes / 1024} KB"
        bytes < 1024 * 1024 * 1024 -> "${bytes / (1024 * 1024)} MB"
        else -> "${bytes / (1024 * 1024 * 1024)} GB"
    }
}

/**
 * 设备选择对话框
 */
@Composable
private fun DeviceSelectionDialog(
    onlineDevices: List<DeviceInfo>,
    onDeviceSelected: (DeviceInfo) -> Unit,
    onDismiss: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("选择目标设备") },
        text = {
            Column {
                if (onlineDevices.isEmpty()) {
                    Text("未发现在线设备", color = MaterialTheme.colorScheme.onSurfaceVariant)
                } else {
                    onlineDevices.forEach { device ->
                        Card(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 4.dp),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                            onClick = { onDeviceSelected(device) }
                        ) {
                            Column(
                                modifier = Modifier.padding(16.dp)
                            ) {
                                Text(
                                    text = device.deviceName,
                                    fontWeight = FontWeight.Medium
                                )
                                Text(
                                    text = "IP: ${device.ipAddress} · 在线时间: ${formatTimestamp(device.timestamp)}",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {
            Button(onClick = onDismiss) {
                Text("取消")
            }
        }
    )
}

/**
 * 获取文件信息
 */
private fun getFileInfo(fileUri: Uri, context: android.content.Context): Pair<String, Long>? {
    return try {
        context.contentResolver.query(fileUri, null, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val displayNameIndex = cursor.getColumnIndex("_display_name")
                val sizeIndex = cursor.getColumnIndex("_size")
                
                val fileName = if (displayNameIndex != -1) {
                    cursor.getString(displayNameIndex)
                } else {
                    fileUri.lastPathSegment ?: "unknown_file"
                }
                
                val fileSize = if (sizeIndex != -1) {
                    cursor.getLong(sizeIndex)
                } else {
                    0L
                }
                
                Pair(fileName, fileSize)
            } else {
                null
            }
        }
    } catch (e: Exception) {
        Log.e("HomeScreen", "获取文件信息失败: ${e.message}")
        null
    }
}

/**
 * 文件接收确认对话框
 */
@Composable
private fun FileReceiveConfirmationDialog(
    senderDeviceName: String,
    fileName: String,
    fileSize: Long,
    onAccept: () -> Unit,
    onReject: () -> Unit,
    onDismiss: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("文件传输请求", fontWeight = FontWeight.Bold) },
        text = {
            Column {
                Text("来自设备: $senderDeviceName")
                Spacer(Modifier.height(8.dp))
                Text("文件名: $fileName")
                Spacer(Modifier.height(8.dp))
                Text("文件大小: ${formatBytes(fileSize)}")
            }
        },
        confirmButton = {
            Button(onClick = onAccept) {
                Text("接受")
            }
        },
        dismissButton = {
            OutlinedButton(onClick = onReject) {
                Text("拒绝")
            }
        }
    )
}
