package com.waveyo.yolighttransfer.manager

import android.content.Context
import android.util.Log
import com.waveyo.yolighttransfer.model.DeviceInfo
import kotlinx.coroutines.*
import java.util.*
import java.util.concurrent.ConcurrentHashMap

/**
 * 设备管理器
 * 负责维护在线设备列表和设备状态管理
 */
class DeviceManager(private val context: Context) {
    
    companion object {
        private const val TAG = "DeviceManager"
        private const val CLEANUP_INTERVAL = 5000L // 5秒清理一次离线设备
    }
    
    // 使用ConcurrentHashMap存储设备信息，key为设备ID
    private val devices = ConcurrentHashMap<String, DeviceInfo>()
    
    // 设备状态变化回调
    var onDeviceAdded: ((DeviceInfo) -> Unit)? = null
    var onDeviceUpdated: ((DeviceInfo) -> Unit)? = null
    var onDeviceRemoved: ((DeviceInfo) -> Unit)? = null
    
    private var cleanupJob: Job? = null
    private var isRunning = false
    
    /**
     * 启动设备管理器
     */
    fun start() {
        if (isRunning) return
        
        isRunning = true
        startCleanupTask()
        Log.d(TAG, "设备管理器已启动")
    }
    
    /**
     * 停止设备管理器
     */
    fun stop() {
        isRunning = false
        cleanupJob?.cancel()
        cleanupJob = null
        devices.clear()
        Log.d(TAG, "设备管理器已停止")
    }
    
    /**
     * 添加或更新设备信息
     */
    fun addOrUpdateDevice(deviceInfo: DeviceInfo) {
        val existingDevice = devices[deviceInfo.deviceId]
        
        if (existingDevice == null) {
            // 新设备
            devices[deviceInfo.deviceId] = deviceInfo
            onDeviceAdded?.invoke(deviceInfo)
            Log.d(TAG, "添加新设备: ${deviceInfo.deviceName} (${deviceInfo.ipAddress})")
        } else {
            // 更新现有设备
            val updatedDevice = existingDevice.copy(
                deviceName = deviceInfo.deviceName,
                deviceOS = deviceInfo.deviceOS,
                tcpPort = deviceInfo.tcpPort,
                timestamp = deviceInfo.timestamp,
                ipAddress = deviceInfo.ipAddress,
                isOnline = true
            )
            devices[deviceInfo.deviceId] = updatedDevice
            onDeviceUpdated?.invoke(updatedDevice)
            Log.d(TAG, "更新设备: ${deviceInfo.deviceName} (${deviceInfo.ipAddress})")
        }
    }
    
    /**
     * 移除设备
     */
    fun removeDevice(deviceId: String) {
        val device = devices[deviceId]
        if (device != null) {
            devices.remove(deviceId)
            onDeviceRemoved?.invoke(device)
            Log.d(TAG, "移除设备: ${device.deviceName} (${device.ipAddress})")
        }
    }
    
    /**
     * 获取在线设备列表（按最近活跃时间排序）
     */
    fun getOnlineDevices(): List<DeviceInfo> {
        return devices.values
            .filter { it.isDeviceOnline() }
            .sortedByDescending { it.timestamp }
    }
    
    /**
     * 获取所有设备列表（包括离线设备）
     */
    fun getAllDevices(): List<DeviceInfo> {
        return devices.values.toList()
    }
    
    /**
     * 根据设备ID获取设备信息
     */
    fun getDeviceById(deviceId: String): DeviceInfo? {
        return devices[deviceId]
    }
    
    /**
     * 根据IP地址获取设备信息
     */
    fun getDeviceByIp(ipAddress: String): DeviceInfo? {
        return devices.values.find { it.ipAddress == ipAddress }
    }
    
    /**
     * 检查设备是否在线
     */
    fun isDeviceOnline(deviceId: String): Boolean {
        return devices[deviceId]?.isDeviceOnline() ?: false
    }
    
    /**
     * 获取设备数量统计
     */
    fun getDeviceStats(): DeviceStats {
        val allDevices = getAllDevices()
        val onlineDevices = getOnlineDevices()
        
        return DeviceStats(
            totalDevices = allDevices.size,
            onlineDevices = onlineDevices.size,
            offlineDevices = allDevices.size - onlineDevices.size
        )
    }
    
    /**
     * 清理离线设备
     */
    private fun cleanupOfflineDevices() {
        val offlineDevices = devices.values.filter { !it.isDeviceOnline() }
        
        offlineDevices.forEach { device ->
            devices.remove(device.deviceId)
            onDeviceRemoved?.invoke(device)
            Log.d(TAG, "清理离线设备: ${device.deviceName} (${device.ipAddress})")
        }
    }
    
    /**
     * 启动清理任务
     */
    private fun startCleanupTask() {
        cleanupJob = CoroutineScope(Dispatchers.IO).launch {
            while (isRunning) {
                try {
                    cleanupOfflineDevices()
                    delay(CLEANUP_INTERVAL)
                } catch (e: Exception) {
                    if (isRunning) {
                        Log.e(TAG, "清理任务失败: ${e.message}")
                        delay(1000) // 出错后等待1秒重试
                    }
                }
            }
        }
    }
    
    /**
     * 获取设备列表的字符串表示（用于调试）
     */
    fun getDevicesDebugInfo(): String {
        val onlineDevices = getOnlineDevices()
        val allDevices = getAllDevices()
        
        return """
            设备统计:
            - 总设备数: ${allDevices.size}
            - 在线设备: ${onlineDevices.size}
            - 离线设备: ${allDevices.size - onlineDevices.size}
            
            在线设备列表:
            ${onlineDevices.joinToString("\n") { 
                "- ${it.deviceName} (${it.deviceOS}) - ${it.ipAddress}:${it.tcpPort} - ${formatTimestamp(it.timestamp)}"
            }}
        """.trimIndent()
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
     * 清理资源
     */
    fun cleanup() {
        stop()
        devices.clear()
    }
}

/**
 * 设备统计信息
 */
data class DeviceStats(
    val totalDevices: Int,
    val onlineDevices: Int,
    val offlineDevices: Int
)
