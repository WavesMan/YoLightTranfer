package com.waveyo.yolighttransfer.model

import android.os.Parcelable
import com.google.gson.annotations.SerializedName
import kotlinx.parcelize.Parcelize
import java.util.UUID

/**
 * 设备信息数据类
 * 对应UDP广播心跳包的数据结构
 */
@Parcelize
data class DeviceInfo(
    @SerializedName("Device_ID")
    var deviceId: String = UUID.randomUUID().toString(),
    
    @SerializedName("Device_OS")
    val deviceOS: String = "Android",
    
    @SerializedName("Device_Name")
    var deviceName: String = "Android Device",
    
    @SerializedName("TCP_Port")
    var tcpPort: Int = 7431,
    
    @SerializedName("Timestamp")
    var timestamp: Long = System.currentTimeMillis(),
    
    // 额外字段，用于内部管理
    val ipAddress: String = "",
    val isOnline: Boolean = true
) : Parcelable {
    
    companion object {
        const val BROADCAST_PORT = 7431
        const val HEARTBEAT_INTERVAL = 5000L // 5秒发送一次心跳
        const val TIMEOUT_THRESHOLD = 10000L // 10秒超时
    }
    
    /**
     * 检查设备是否在线（基于时间戳）
     */
    fun isDeviceOnline(): Boolean {
        return System.currentTimeMillis() - timestamp < TIMEOUT_THRESHOLD
    }
    
    /**
     * 更新活跃时间戳
     */
    fun updateTimestamp() {
        timestamp = System.currentTimeMillis()
    }
    
    /**
     * 生成心跳包JSON字符串
     */
    fun toHeartbeatJson(): String {
        return """
            {
                "Device_ID": "$deviceId",
                "Device_OS": "$deviceOS",
                "Device_Name": "$deviceName",
                "TCP_Port": $tcpPort,
                "Timestamp": $timestamp
            }
        """.trimIndent()
    }
}
