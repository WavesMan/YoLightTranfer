package com.waveyo.yolighttransfer.network

import android.content.Context
import android.net.wifi.WifiManager
import android.util.Log
import com.google.gson.Gson
import com.waveyo.yolighttransfer.manager.AppManager
import com.waveyo.yolighttransfer.manager.LogManager
import com.waveyo.yolighttransfer.model.DeviceInfo
import kotlinx.coroutines.*
import java.io.IOException
import java.net.*

/**
 * 设备发现管理器
 * 负责UDP广播的发送和监听
 */
class DeviceDiscoveryManager(private val context: Context, private val appManager: AppManager) {
    
    companion object {
        private const val TAG = "DeviceDiscoveryManager"
        private const val BROADCAST_PORT = 7431
        private const val HEARTBEAT_INTERVAL = 5000L // 5秒发送一次心跳
        private const val LISTENER_TIMEOUT = 10000L // 10秒监听超时
    }
    
    private val gson = Gson()
    private val logManager = LogManager(context)
    private var broadcastJob: Job? = null
    private var listenerJob: Job? = null
    private var isBroadcasting = false
    private var isListening = false
    
    // 设备发现回调
    var onDeviceDiscovered: ((DeviceInfo) -> Unit)? = null
    var onDeviceTimeout: ((DeviceInfo) -> Unit)? = null
    
    // 当前设备信息
    private val currentDevice: DeviceInfo
        get() = appManager.currentDevice
    
    /**
     * 初始化设备发现管理器
     */
    fun initialize() {
        // 设备发现管理器现在通过构造函数接收已初始化的AppManager
        // 不需要再次初始化AppManager
        Log.d(TAG, "设备发现管理器已初始化")
    }
    
    /**
     * 启动UDP广播（发送心跳包）
     */
    fun startBroadcast() {
        if (isBroadcasting) return
        
        isBroadcasting = true
        broadcastJob = CoroutineScope(Dispatchers.IO).launch {
            try {
                val wifiManager = context.getSystemService(Context.WIFI_SERVICE) as WifiManager
                val multicastLock = wifiManager.createMulticastLock("YoLightTransfer")
                multicastLock.setReferenceCounted(true)
                multicastLock.acquire()
                
                val socket = DatagramSocket().apply {
                    broadcast = true
                    reuseAddress = true
                }
                
                while (isBroadcasting) {
                    try {
                        // 获取所有局域网广播地址
                        val broadcastAddresses = getBroadcastAddresses()
                        
                        // 向每个广播地址发送心跳包
                        broadcastAddresses.forEach { broadcastAddress ->
                            val heartbeatJson = currentDevice.toHeartbeatJson()
                            val data = heartbeatJson.toByteArray(Charsets.UTF_8)
                            val packet = DatagramPacket(
                                data, data.size, 
                                broadcastAddress, BROADCAST_PORT
                            )
                            
                            socket.send(packet)
                            logManager.d(TAG, "发送心跳包到: ${broadcastAddress.hostAddress}")
                        }
                        
                        delay(HEARTBEAT_INTERVAL)
                    } catch (e: Exception) {
                        logManager.e(TAG, "发送心跳包失败: ${e.message}")
                        delay(1000) // 出错后等待1秒重试
                    }
                }
                
                socket.close()
                multicastLock.release()
            } catch (e: Exception) {
                Log.e(TAG, "启动广播失败: ${e.message}")
                isBroadcasting = false
            }
        }
    }
    
    /**
     * 停止UDP广播
     */
    fun stopBroadcast() {
        isBroadcasting = false
        broadcastJob?.cancel()
        broadcastJob = null
    }
    
    /**
     * 启动UDP监听器
     */
    fun startListener() {
        if (isListening) return
        
        isListening = true
        listenerJob = CoroutineScope(Dispatchers.IO).launch {
            try {
                val socket = DatagramSocket(BROADCAST_PORT).apply {
                    soTimeout = LISTENER_TIMEOUT.toInt()
                    reuseAddress = true
                }
                
                val buffer = ByteArray(1024)
                
                while (isListening) {
                    try {
                        val packet = DatagramPacket(buffer, buffer.size)
                        socket.receive(packet)
                        
                        val message = String(packet.data, 0, packet.length, Charsets.UTF_8)
                        Log.d(TAG, "收到UDP消息: $message from ${packet.address.hostAddress}")
                        
                        // 解析设备信息
                        val deviceInfo = parseDeviceInfo(message, packet.address.hostAddress)
                        
                        // 检查是否是自己的设备ID，如果是则忽略
                        if (deviceInfo.deviceId != currentDevice.deviceId) {
                            onDeviceDiscovered?.invoke(deviceInfo)
                        }
                        
                    } catch (e: SocketTimeoutException) {
                        // 超时正常，继续监听
                        continue
                    } catch (e: Exception) {
                        Log.e(TAG, "监听UDP消息失败: ${e.message}")
                        delay(1000) // 出错后等待1秒重试
                    }
                }
                
                socket.close()
            } catch (e: Exception) {
                Log.e(TAG, "启动监听器失败: ${e.message}")
                isListening = false
            }
        }
    }
    
    /**
     * 停止UDP监听器
     */
    fun stopListener() {
        isListening = false
        listenerJob?.cancel()
        listenerJob = null
    }
    
    /**
     * 获取所有局域网广播地址
     */
    private fun getBroadcastAddresses(): List<InetAddress> {
        val addresses = mutableListOf<InetAddress>()
        
        try {
            val interfaces = NetworkInterface.getNetworkInterfaces()
            while (interfaces.hasMoreElements()) {
                val networkInterface = interfaces.nextElement()
                
                // 跳过回环接口和未启用的接口
                if (networkInterface.isLoopback || !networkInterface.isUp) continue
                
                for (interfaceAddress in networkInterface.interfaceAddresses) {
                    val broadcast = interfaceAddress.broadcast
                    if (broadcast != null) {
                        addresses.add(broadcast)
                    }
                }
            }
        } catch (e: SocketException) {
            Log.e(TAG, "获取广播地址失败: ${e.message}")
        }
        
        // 如果没有找到广播地址，使用默认的广播地址
        if (addresses.isEmpty()) {
            try {
                addresses.add(InetAddress.getByName("255.255.255.255"))
            } catch (e: UnknownHostException) {
                Log.e(TAG, "获取默认广播地址失败: ${e.message}")
            }
        }
        
        return addresses
    }
    
    /**
     * 解析设备信息
     */
    private fun parseDeviceInfo(jsonString: String, ipAddress: String): DeviceInfo {
        return try {
            gson.fromJson(jsonString, DeviceInfo::class.java).copy(
                ipAddress = ipAddress,
                isOnline = true
            ).apply {
                updateTimestamp()
            }
        } catch (e: Exception) {
            Log.e(TAG, "解析设备信息失败: ${e.message}")
            DeviceInfo().copy(ipAddress = ipAddress)
        }
    }
    
    
    /**
     * 获取本地IP地址
     */
    private fun getLocalIpAddress(): String {
        return try {
            val interfaces = NetworkInterface.getNetworkInterfaces()
            while (interfaces.hasMoreElements()) {
                val networkInterface = interfaces.nextElement()
                if (networkInterface.isLoopback || !networkInterface.isUp) continue
                
                for (address in networkInterface.inetAddresses) {
                    if (!address.isLoopbackAddress && address is Inet4Address) {
                        return address.hostAddress
                    }
                }
            }
            "unknown"
        } catch (e: Exception) {
            "unknown"
        }
    }
    
    /**
     * 获取当前设备信息
     */
    fun getCurrentDeviceInfo(): DeviceInfo = currentDevice
    
    /**
     * 更新设备名称
     */
    fun updateDeviceName(newName: String) {
        currentDevice.deviceName = newName
    }
    
    /**
     * 清理资源
     */
    fun cleanup() {
        stopBroadcast()
        stopListener()
    }
}
