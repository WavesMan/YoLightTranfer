package com.waveyo.yolighttransfer.ui.screens

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.waveyo.yolighttransfer.manager.AppManager
import com.waveyo.yolighttransfer.ui.components.SectionCard
import java.io.File

/**
 * 日志管理屏幕
 * 提供日志导出、统计和配置功能
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LogScreen(
    modifier: Modifier = Modifier,
    appManager: AppManager
) {
    val context = LocalContext.current
    
    // 状态管理
    var logStats by rememberSaveable { mutableStateOf("") }
    var isLoggingEnabled by rememberSaveable { mutableStateOf(appManager.isLoggingEnabled()) }
    var exportStatus by rememberSaveable { mutableStateOf("") }
    
    // 文件分享启动器
    val shareLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.StartActivityForResult()
    ) { result ->
        // 处理分享结果
        exportStatus = if (result.resultCode == android.app.Activity.RESULT_OK) {
            "日志分享成功"
        } else {
            "日志分享取消"
        }
    }
    
    // 加载日志统计信息
    LaunchedEffect(Unit) {
        logStats = appManager.getLogStats()
    }
    
    // 监听日志启用状态变化
    LaunchedEffect(isLoggingEnabled) {
        appManager.setLoggingEnabled(isLoggingEnabled)
    }
    
    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            TopAppBar(title = { Text("日志管理", fontWeight = FontWeight.Bold) })
        }
    ) { inner ->
        LazyColumn(
            modifier = Modifier
                .padding(inner)
                .fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item {
                // 日志统计信息
                SectionCard(title = "日志统计") {
                    if (logStats.isNotEmpty()) {
                        Text(
                            text = logStats,
                            style = MaterialTheme.typography.bodyMedium
                        )
                    } else {
                        Text("正在加载日志统计...")
                    }
                }
            }
            
            item {
                // 日志配置
                SectionCard(title = "日志配置") {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "启用日志记录",
                            style = MaterialTheme.typography.bodyLarge
                        )
                        Switch(
                            checked = isLoggingEnabled,
                            onCheckedChange = { isLoggingEnabled = it }
                        )
                    }
                    
                    Spacer(Modifier.height(16.dp))
                    
                    Text(
                        text = "注意：禁用日志记录将停止收集新的日志，但不会清除现有日志。",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
            
            item {
                // 日志操作
                SectionCard(title = "日志操作") {
                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        // 导出日志按钮
                        Button(
                            onClick = {
                                exportStatus = "正在导出日志..."
                                val logFile = appManager.exportLogs()
                                if (logFile != null && logFile.exists()) {
                                    // 创建分享意图
                                    val shareIntent = Intent().apply {
                                        action = Intent.ACTION_SEND
                                        type = "text/plain"
                                        putExtra(Intent.EXTRA_SUBJECT, "YoLightTransfer 日志文件")
                                        putExtra(Intent.EXTRA_TEXT, "YoLightTransfer 应用日志文件")
                                        // 使用 FileProvider 获取 URI
                                        val uri = androidx.core.content.FileProvider.getUriForFile(
                                            context,
                                            "${context.packageName}.provider",
                                            logFile
                                        )
                                        putExtra(Intent.EXTRA_STREAM, uri)
                                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    }
                                    
                                    shareLauncher.launch(
                                        Intent.createChooser(shareIntent, "分享日志文件")
                                    )
                                    exportStatus = "日志导出完成，请选择分享方式"
                                } else {
                                    exportStatus = "日志导出失败"
                                }
                            },
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text("导出日志文件")
                        }
                        
                        // 清除日志按钮
                        Button(
                            onClick = {
                                appManager.clearLogs()
                                logStats = appManager.getLogStats()
                                exportStatus = "日志已清除"
                            },
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text("清除所有日志")
                        }
                        
                        // 刷新统计按钮
                        Button(
                            onClick = {
                                logStats = appManager.getLogStats()
                                exportStatus = "统计已刷新"
                            },
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text("刷新统计")
                        }
                    }
                }
            }
            
            if (exportStatus.isNotEmpty()) {
                item {
                    // 导出状态显示
                    Card(
                        modifier = Modifier
                            .padding(horizontal = 16.dp)
                            .fillMaxWidth(),
                        colors = CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.surfaceVariant
                        )
                    ) {
                        Text(
                            text = exportStatus,
                            modifier = Modifier.padding(16.dp),
                            style = MaterialTheme.typography.bodyMedium
                        )
                    }
                }
            }
            
            item {
                // 使用说明
                SectionCard(title = "使用说明") {
                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Text(
                            text = "• 日志记录会收集应用的运行状态、错误信息和调试信息",
                            style = MaterialTheme.typography.bodyMedium
                        )
                        Text(
                            text = "• 导出日志后可以通过邮件、微信等方式分享给开发人员",
                            style = MaterialTheme.typography.bodyMedium
                        )
                        Text(
                            text = "• 生产环境中建议禁用日志记录以提升性能",
                            style = MaterialTheme.typography.bodyMedium
                        )
                        Text(
                            text = "• 清除日志会删除所有已收集的日志记录",
                            style = MaterialTheme.typography.bodyMedium
                        )
                    }
                }
            }
            
            item { Spacer(Modifier.height(16.dp)) }
        }
    }
}

/**
 * 开发调试用的快速日志导出组件
 * 注释掉下面的代码可以禁用此功能
 */
@Composable
fun QuickLogExport(
    appManager: AppManager,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    var showQuickExport by rememberSaveable { mutableStateOf(false) }
    
    // 只有在开发模式下才显示快速导出
    if (showQuickExport) {
        Card(
            modifier = modifier
                .fillMaxWidth()
                .padding(8.dp),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.primaryContainer
            )
        ) {
            Column(
                modifier = Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(
                    text = "快速日志导出 (开发模式)",
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.Bold
                )
                
                Button(
                    onClick = {
                        val logFile = appManager.exportLogs()
                        if (logFile != null) {
                            // 快速分享
                            val shareIntent = Intent().apply {
                                action = Intent.ACTION_SEND
                                type = "text/plain"
                                putExtra(Intent.EXTRA_SUBJECT, "YoLightTransfer 调试日志")
                                // 使用 FileProvider 获取 URI
                                val uri = androidx.core.content.FileProvider.getUriForFile(
                                    context,
                                    "${context.packageName}.provider",
                                    logFile
                                )
                                putExtra(Intent.EXTRA_STREAM, uri)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            context.startActivity(
                                Intent.createChooser(shareIntent, "分享调试日志")
                            )
                        }
                    }
                ) {
                    Text("快速导出日志")
                }
                
                Button(
                    onClick = { showQuickExport = false }
                ) {
                    Text("隐藏")
                }
            }
        }
    } else {
        // 注释掉下面这行可以完全禁用快速导出功能
        Button(
            onClick = { showQuickExport = true },
            modifier = modifier.padding(8.dp)
        ) {
            Text("开发调试")
        }
    }
}
