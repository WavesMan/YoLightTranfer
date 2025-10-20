package com.waveyo.yolighttransfer.manager

import android.content.Context
import android.content.SharedPreferences
import android.util.Log

/**
 * 配置管理器
 * 负责应用配置的持久化存储和读取
 */
class ConfigManager(private val context: Context) {
    
    companion object {
        private const val TAG = "ConfigManager"
        private const val PREFS_NAME = "YoLightTransferConfig"
        private const val KEY_DEVICE_NAME = "device_name"
        private const val KEY_DEVICE_ID = "device_id"
        private const val KEY_TCP_PORT = "tcp_port"
        private const val KEY_CHUNK_SIZE = "chunk_size"
        private const val KEY_TIMEOUT = "timeout"
        private const val KEY_AUTO_RECEIVE = "auto_receive"
        private const val KEY_BROADCAST_PORT = "broadcast_port"
        private const val KEY_DISCOVERY_INTERVAL = "discovery_interval"
        
        // 默认值
        private const val DEFAULT_DEVICE_NAME = "Android Device"
        private const val DEFAULT_TCP_PORT = 7431
        private const val DEFAULT_CHUNK_SIZE = "1MB"
        private const val DEFAULT_TIMEOUT = "30秒"
        private const val DEFAULT_AUTO_RECEIVE = "启用"
        private const val DEFAULT_BROADCAST_PORT = 7431
        private const val DEFAULT_DISCOVERY_INTERVAL = "5秒"
    }
    
    private val sharedPreferences: SharedPreferences by lazy {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }
    
    /**
     * 保存设备名称
     */
    fun saveDeviceName(deviceName: String) {
        sharedPreferences.edit()
            .putString(KEY_DEVICE_NAME, deviceName)
            .apply()
        Log.d(TAG, "设备名称已保存: $deviceName")
    }
    
    /**
     * 获取设备名称
     */
    fun getDeviceName(): String {
        return sharedPreferences.getString(KEY_DEVICE_NAME, DEFAULT_DEVICE_NAME) ?: DEFAULT_DEVICE_NAME
    }
    
    /**
     * 保存设备ID
     */
    fun saveDeviceId(deviceId: String) {
        sharedPreferences.edit()
            .putString(KEY_DEVICE_ID, deviceId)
            .apply()
        Log.d(TAG, "设备ID已保存: $deviceId")
    }
    
    /**
     * 获取设备ID，如果没有则返回null
     */
    fun getDeviceId(): String? {
        return sharedPreferences.getString(KEY_DEVICE_ID, null)
    }
    
    /**
     * 保存TCP端口
     */
    fun saveTcpPort(port: Int) {
        sharedPreferences.edit()
            .putInt(KEY_TCP_PORT, port)
            .apply()
        Log.d(TAG, "TCP端口已保存: $port")
    }
    
    /**
     * 获取TCP端口
     */
    fun getTcpPort(): Int {
        return sharedPreferences.getInt(KEY_TCP_PORT, DEFAULT_TCP_PORT)
    }
    
    /**
     * 保存分片大小
     */
    fun saveChunkSize(chunkSize: String) {
        sharedPreferences.edit()
            .putString(KEY_CHUNK_SIZE, chunkSize)
            .apply()
        Log.d(TAG, "分片大小已保存: $chunkSize")
    }
    
    /**
     * 获取分片大小
     */
    fun getChunkSize(): String {
        return sharedPreferences.getString(KEY_CHUNK_SIZE, DEFAULT_CHUNK_SIZE) ?: DEFAULT_CHUNK_SIZE
    }
    
    /**
     * 保存超时时间
     */
    fun saveTimeout(timeout: String) {
        sharedPreferences.edit()
            .putString(KEY_TIMEOUT, timeout)
            .apply()
        Log.d(TAG, "超时时间已保存: $timeout")
    }
    
    /**
     * 获取超时时间
     */
    fun getTimeout(): String {
        return sharedPreferences.getString(KEY_TIMEOUT, DEFAULT_TIMEOUT) ?: DEFAULT_TIMEOUT
    }
    
    /**
     * 保存自动接收设置
     */
    fun saveAutoReceive(autoReceive: String) {
        sharedPreferences.edit()
            .putString(KEY_AUTO_RECEIVE, autoReceive)
            .apply()
        Log.d(TAG, "自动接收设置已保存: $autoReceive")
    }
    
    /**
     * 获取自动接收设置
     */
    fun getAutoReceive(): String {
        return sharedPreferences.getString(KEY_AUTO_RECEIVE, DEFAULT_AUTO_RECEIVE) ?: DEFAULT_AUTO_RECEIVE
    }
    
    /**
     * 保存广播端口
     */
    fun saveBroadcastPort(port: Int) {
        sharedPreferences.edit()
            .putInt(KEY_BROADCAST_PORT, port)
            .apply()
        Log.d(TAG, "广播端口已保存: $port")
    }
    
    /**
     * 获取广播端口
     */
    fun getBroadcastPort(): Int {
        return sharedPreferences.getInt(KEY_BROADCAST_PORT, DEFAULT_BROADCAST_PORT)
    }
    
    /**
     * 保存发现间隔
     */
    fun saveDiscoveryInterval(interval: String) {
        sharedPreferences.edit()
            .putString(KEY_DISCOVERY_INTERVAL, interval)
            .apply()
        Log.d(TAG, "发现间隔已保存: $interval")
    }
    
    /**
     * 获取发现间隔
     */
    fun getDiscoveryInterval(): String {
        return sharedPreferences.getString(KEY_DISCOVERY_INTERVAL, DEFAULT_DISCOVERY_INTERVAL) ?: DEFAULT_DISCOVERY_INTERVAL
    }
    
    /**
     * 清除所有配置
     */
    fun clearAll() {
        sharedPreferences.edit().clear().apply()
        Log.d(TAG, "所有配置已清除")
    }
    
    /**
     * 获取所有配置的调试信息
     */
    fun getDebugInfo(): String {
        return """
            配置信息:
            - 设备名称: ${getDeviceName()}
            - TCP端口: ${getTcpPort()}
            - 分片大小: ${getChunkSize()}
            - 超时时间: ${getTimeout()}
            - 自动接收: ${getAutoReceive()}
            - 广播端口: ${getBroadcastPort()}
            - 发现间隔: ${getDiscoveryInterval()}
        """.trimIndent()
    }
}
