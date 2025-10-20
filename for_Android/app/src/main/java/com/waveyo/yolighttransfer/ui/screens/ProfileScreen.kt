package com.waveyo.yolighttransfer.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.waveyo.yolighttransfer.manager.AppManager
import com.waveyo.yolighttransfer.ui.components.SectionCard

/**
 * 个人资料屏幕
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfileScreen(
    modifier: Modifier = Modifier,
    appManager: AppManager
) {
    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = { TopAppBar(title = { Text("我的") }) }
    ) { inner ->
        LazyColumn(
            modifier = Modifier
                .padding(inner)
                .fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item {
                SectionCard(title = "用户信息") {
                    Text("👤 未登录")
                    Spacer(Modifier.height(8.dp))
                    Button(onClick = { /* TODO 登录 */ }) { Text("立即登录") }
                }
            }
            
            item {
                SectionCard(title = "应用信息") {
                    Text("版本: v1.0.0")
                    Spacer(Modifier.height(8.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Button(onClick = { /* TODO 检查更新 */ }) { Text("检查更新") }
                        Button(onClick = { /* TODO 关于 */ }) { Text("关于软件") }
                    }
                }
            }
            
            // item {
            //     SectionCard(title = "数据统计") {
            //         Text("总传输: 128文件 (2.5 GB)")
            //         Text("成功: 125  失败: 3")
            //     }
            // }
            
            item {
                SectionCard(title = "日志管理") {
                    var logStats by rememberSaveable { mutableStateOf("") }
                    
                    // 加载日志统计
                    LaunchedEffect(Unit) {
                        logStats = appManager.getLogStats()
                    }
                    
                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        // 显示日志统计
                        if (logStats.isNotEmpty()) {
                            Text(
                                text = logStats,
                                style = androidx.compose.material3.MaterialTheme.typography.bodyMedium
                            )
                        }
                        
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Button(
                                onClick = {
                                    // 快速导出日志
                                    val logFile = appManager.exportLogs()
                                    if (logFile != null) {
                                        // 这里可以添加分享逻辑
                                        // 在实际应用中，这里会启动分享意图
                                    }
                                },
                                modifier = Modifier.weight(1f)
                            ) {
                                Text("导出日志")
                            }
                            
                            Button(
                                onClick = {
                                    appManager.clearLogs()
                                    logStats = appManager.getLogStats()
                                },
                                modifier = Modifier.weight(1f)
                            ) {
                                Text("清除日志")
                            }
                        }
                        
                        // 开发调试按钮 - 注释掉下面这行可以禁用
                        Button(
                            onClick = {
                                // 快速调试功能
                                val debugInfo = appManager.getDebugInfo()
                                // 这里可以显示调试信息或记录到日志
                            },
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text("开发调试")
                        }
                    }
                }
            }
            
            item { Spacer(Modifier.height(16.dp)) }
        }
    }
}
