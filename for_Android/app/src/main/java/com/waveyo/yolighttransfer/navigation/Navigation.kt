package com.waveyo.yolighttransfer.navigation

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.BugReport
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.foundation.layout.padding
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.waveyo.yolighttransfer.manager.AppManager
import com.waveyo.yolighttransfer.ui.screens.HomeScreen
import com.waveyo.yolighttransfer.ui.screens.ProfileScreen
import com.waveyo.yolighttransfer.ui.screens.SettingsScreen

/**
 * 应用目的地枚举
 */
enum class AppDestinations(
    val label: String,
    val icon: ImageVector,
) {
    HOME("设备发现", Icons.Default.Home),
    SETTINGS("设置", Icons.Default.Settings),
    PROFILE("我的", Icons.Default.AccountCircle),
}

/**
 * 主应用组件
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun YoLightTransferApp(appManager: AppManager) {
    var currentDestination by rememberSaveable { mutableStateOf(AppDestinations.HOME) }

    Scaffold(
        bottomBar = {
            NavigationBar {
                AppDestinations.entries.forEach { destination ->
                    NavigationBarItem(
                        icon = { androidx.compose.material3.Icon(destination.icon, contentDescription = destination.label) },
                        label = { Text(destination.label) },
                        selected = currentDestination == destination,
                        onClick = { currentDestination = destination }
                    )
                }
            }
        }
    ) { innerPadding ->
        // 根据目的地显示对应屏幕
        when (currentDestination) {
            AppDestinations.HOME -> HomeScreen(
                modifier = Modifier.padding(innerPadding),
                appManager = appManager
            )
            AppDestinations.SETTINGS -> SettingsScreen(
                modifier = Modifier.padding(innerPadding),
                appManager = appManager
            )
            AppDestinations.PROFILE -> ProfileScreen(
                modifier = Modifier.padding(innerPadding),
                appManager = appManager
            )
        }
    }
}
