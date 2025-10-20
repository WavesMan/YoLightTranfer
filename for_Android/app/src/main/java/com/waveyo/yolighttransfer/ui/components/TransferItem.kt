package com.waveyo.yolighttransfer.ui.components

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.FolderOpen
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import android.util.Log

/**
 * 传输项组件 - 现代化UI设计，支持传输控制
 */
@Composable
fun TransferItem(
    name: String,
    progressText: String,
    status: String,
    progress: Float = 0f,
    filePath: String? = null,
    transferStatus: String = "",
    onPause: (() -> Unit)? = null,
    onResume: (() -> Unit)? = null,
    onCancel: (() -> Unit)? = null,
    onRetry: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(16.dp)
    ) {
        // 文件信息和状态图标
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                // 文件图标
                Icon(
                    imageVector = Icons.Default.Description,
                    contentDescription = "文件",
                    modifier = Modifier.size(24.dp),
                    tint = MaterialTheme.colorScheme.primary
                )
                Spacer(Modifier.size(12.dp))
                Column {
                    Text(
                        text = name,
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.Medium,
                        maxLines = 1
                    )
                    Text(
                        text = progressText,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
            
            // 状态指示器
            when {
                status.contains("已完成") -> Icon(
                    imageVector = Icons.Default.CheckCircle,
                    contentDescription = "已完成",
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(20.dp)
                )
                status.contains("失败") -> Icon(
                    imageVector = Icons.Default.Error,
                    contentDescription = "失败",
                    tint = MaterialTheme.colorScheme.error,
                    modifier = Modifier.size(20.dp)
                )
                status.contains("暂停") -> Icon(
                    imageVector = Icons.Default.Pause,
                    contentDescription = "暂停",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(20.dp)
                )
                else -> CircularProgressIndicator(
                    progress = { progress },
                    modifier = Modifier.size(20.dp),
                    strokeWidth = 2.dp
                )
            }
        }
        
        Spacer(Modifier.height(12.dp))
        
        // 线性进度条
        LinearProgressIndicator(
            progress = { progress },
            modifier = Modifier
                .fillMaxWidth()
                .height(4.dp),
            color = when {
                status.contains("失败") -> MaterialTheme.colorScheme.error
                status.contains("已完成") -> MaterialTheme.colorScheme.primary
                else -> MaterialTheme.colorScheme.primary
            },
            trackColor = MaterialTheme.colorScheme.surfaceVariant
        )
        
        Spacer(Modifier.height(8.dp))
        
        // 状态文本
        Text(
            text = status,
            style = MaterialTheme.typography.bodySmall,
            color = when {
                status.contains("失败") -> MaterialTheme.colorScheme.error
                status.contains("已完成") -> MaterialTheme.colorScheme.primary
                else -> MaterialTheme.colorScheme.onSurfaceVariant
            }
        )
        
        // 传输控制按钮
        if (onPause != null || onResume != null || onCancel != null || onRetry != null) {
            Spacer(Modifier.height(12.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                // 左侧：暂停/继续按钮
                when {
                    transferStatus == "TRANSFERRING" && onPause != null -> {
                        OutlinedButton(
                            onClick = {
                                Log.d("TransferItem", "点击暂停按钮: $name")
                                onPause()
                            },
                            modifier = Modifier.weight(1f)
                        ) {
                            Icon(
                                imageVector = Icons.Default.Pause,
                                contentDescription = "暂停",
                                modifier = Modifier.size(16.dp)
                            )
                            Spacer(Modifier.size(8.dp))
                            Text("暂停")
                        }
                    }
                    transferStatus == "PAUSED" && onResume != null -> {
                        OutlinedButton(
                            onClick = {
                                Log.d("TransferItem", "点击继续按钮: $name")
                                onResume()
                            },
                            modifier = Modifier.weight(1f)
                        ) {
                            Icon(
                                imageVector = Icons.Default.PlayArrow,
                                contentDescription = "继续",
                                modifier = Modifier.size(16.dp)
                            )
                            Spacer(Modifier.size(8.dp))
                            Text("继续")
                        }
                    }
                    else -> {
                        Spacer(Modifier.weight(1f))
                    }
                }
                
                Spacer(Modifier.size(8.dp))
                
                // 中间：重试按钮（仅失败状态显示）
                if (transferStatus == "FAILED" && onRetry != null) {
                    OutlinedButton(
                        onClick = onRetry,
                        modifier = Modifier.weight(1f)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Refresh,
                            contentDescription = "重试",
                            modifier = Modifier.size(16.dp)
                        )
                        Spacer(Modifier.size(8.dp))
                        Text("重试")
                    }
                } else {
                    Spacer(Modifier.weight(1f))
                }
                
                Spacer(Modifier.size(8.dp))
                
                // 右侧：停止按钮
                if (onCancel != null && 
                    (transferStatus == "TRANSFERRING" || transferStatus == "PAUSED" || transferStatus == "PENDING")) {
                    OutlinedButton(
                        onClick = onCancel,
                        modifier = Modifier.weight(1f)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Stop,
                            contentDescription = "停止",
                            modifier = Modifier.size(16.dp)
                        )
                        Spacer(Modifier.size(8.dp))
                        Text("停止")
                    }
                } else {
                    Spacer(Modifier.weight(1f))
                }
            }
        }
        
        // 为已完成的任务添加"打开文件位置"按钮
        if (status.contains("已完成") && filePath != null) {
            Spacer(Modifier.height(8.dp))
            Button(
                onClick = {
                    openFileLocation(context, filePath)
                },
                modifier = Modifier.fillMaxWidth()
            ) {
                Icon(
                    imageVector = Icons.Default.FolderOpen,
                    contentDescription = "打开文件位置",
                    modifier = Modifier.size(16.dp)
                )
                Spacer(Modifier.size(8.dp))
                Text("打开文件位置")
            }
        }
        
        Spacer(Modifier.height(8.dp))
        HorizontalDivider(
            thickness = 1.dp,
            color = MaterialTheme.colorScheme.surfaceVariant
        )
    }
}

/**
 * 打开文件位置
 */
private fun openFileLocation(context: Context, filePath: String) {
    try {
        // 尝试使用文件管理器打开文件所在位置
        val intent = Intent(Intent.ACTION_VIEW)
        val uri = Uri.parse("file://$filePath")
        intent.setDataAndType(uri, "*/*")
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    } catch (e: Exception) {
        // 如果无法打开文件位置，尝试打开下载文件夹
        openDownloadsFolder(context)
    }
}

/**
 * 打开下载文件夹
 */
private fun openDownloadsFolder(context: Context) {
    try {
        val intent = Intent(Intent.ACTION_VIEW)
        val uri = Uri.parse("content://downloads/public_downloads")
        intent.setDataAndType(uri, "resource/folder")
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    } catch (e: Exception) {
        // 如果无法打开下载文件夹，使用默认文件管理器
        val intent = Intent(Intent.ACTION_VIEW)
        intent.type = "*/*"
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }
}
