package com.waveyo.yolighttransfer.manager

import android.content.Context
import android.provider.Settings
import android.util.Log
import com.waveyo.yolighttransfer.model.DeviceInfo
import kotlinx.coroutines.*
import java.security.MessageDigest
import java.util.UUID

/**
 * 应用管理器
 * 负责管理应用级别的数据和状态
 */
class AppManager(private val context: Context) {
    
    companion object {
        private const val TAG = "AppManager"
    }
    
    private val configManager = ConfigManager(context)
    private val deviceManager = DeviceManager(context)
    private val logManager = LogManager(context)
    private val transferQueueManager = TransferQueueManager()
    private val progressManager = ProgressManager()
    private val transferExecutor = TransferExecutor(context, transferQueueManager)
    private lateinit var deviceDiscoveryManager: com.waveyo.yolighttransfer.network.DeviceDiscoveryManager
    private val tcpServer = com.waveyo.yolighttransfer.network.TCPServer(context)
    
    // 当前设备信息
    var currentDevice: DeviceInfo = DeviceInfo(
        deviceName = configManager.getDeviceName(),
        tcpPort = configManager.getTcpPort()
    )
        private set
    
    // 回调函数
    var onDeviceListUpdated: (() -> Unit)? = null
    var onTransferProgress: ((com.waveyo.yolighttransfer.model.FileTransferInfo) -> Unit)? = null
    var onTransferCompleted: ((com.waveyo.yolighttransfer.model.FileTransferInfo) -> Unit)? = null
    var onTransferFailed: ((com.waveyo.yolighttransfer.model.FileTransferInfo, String) -> Unit)? = null
    var onFileReceiveRequest: ((String, String, Long, (Boolean) -> Unit) -> Unit)? = null
    
    /**
     * 初始化应用
     */
    fun initialize() {
        Log.d(TAG, "应用初始化开始")
        
        // 初始化设备ID
        initializeDeviceId()
        
        // 更新设备名称
        currentDevice.deviceName = configManager.getDeviceName()
        
        // 启动网络服务
        startNetworkServices()
        
        Log.d(TAG, "应用初始化完成: ${currentDevice.deviceName}, ID: ${currentDevice.deviceId}")
    }
    
    /**
     * 启动网络服务
     */
    private fun startNetworkServices() {
        Log.d(TAG, "启动网络服务...")
        
        // 创建设备发现管理器实例
        deviceDiscoveryManager = com.waveyo.yolighttransfer.network.DeviceDiscoveryManager(context, this)
        
        // 初始化设备发现管理器
        deviceDiscoveryManager.initialize()
        
        // 启动UDP广播（发送心跳包）
        deviceDiscoveryManager.startBroadcast()
        
        // 启动UDP监听器（接收其他设备的心跳包）
        deviceDiscoveryManager.startListener()
        
        // 启动TCP服务器（接收文件传输）
        tcpServer.startServer()
        
        // 设置传输执行器
        transferQueueManager.setTransferExecutor(transferExecutor)
        
        // 设置进度管理器同步
        transferQueueManager.setProgressManager(progressManager)
        
        // 设置设备发现回调
        deviceDiscoveryManager.onDeviceDiscovered = { device ->
            Log.d(TAG, "发现新设备: ${device.deviceName} (${device.ipAddress})")
            // 将发现的设备添加到设备管理器
            deviceManager.addOrUpdateDevice(device)
            // 通知UI更新设备列表
            onDeviceListUpdated?.invoke()
        }
        
            // 设置TCP传输回调
            tcpServer.transferListener = object : com.waveyo.yolighttransfer.manager.TransferListener {
                override fun onProgressUpdated(fileName: String, transferredBytes: Long, fileSize: Long) {
                    Log.d(TAG, "TCPServer传输进度回调: $fileName, 进度: $transferredBytes/$fileSize")
                    
                    // 检查传输是否已经在队列中，如果不在则添加
                    val existingTransfer = transferQueueManager.getTransfer(fileName)
                    if (existingTransfer == null) {
                        // 传输不在队列中，创建新的传输信息并添加到队列
                        val transferInfo = com.waveyo.yolighttransfer.model.FileTransferInfo(
                            fileName = fileName,
                            fileSize = fileSize,
                            filePath = "", // 文件路径将在接收过程中设置
                            targetDevice = DeviceInfo(deviceName = "未知设备", ipAddress = ""),
                            transferredBytes = transferredBytes,
                            status = com.waveyo.yolighttransfer.model.TransferStatus.TRANSFERRING
                        )
                        Log.d(TAG, "添加接收端传输到队列: $fileName")
                        transferQueueManager.addTransfer(transferInfo)
                    } else {
                        // 传输已在队列中，更新进度
                        Log.d(TAG, "更新接收端传输进度: $fileName, 进度: $transferredBytes/$fileSize")
                        transferQueueManager.updateTransferProgress(fileName, transferredBytes, fileSize)
                    }
                    
                    // 直接更新进度管理器以确保UI实时更新
                    progressManager.updateProgress(fileName, transferredBytes, fileSize)
                    
                    // 通知UI更新进度
                    val transferInfo = progressManager.getTransfer(fileName)
                    if (transferInfo != null) {
                        onTransferProgress?.invoke(transferInfo)
                    }
                }
                
                override fun onTransferCompleted(fileName: String) {
                    // 标记传输队列管理器中的传输完成
                    transferQueueManager.markTransferCompleted(fileName)
                    // 标记进度管理器中的传输完成
                    progressManager.markTransferCompleted(fileName)
                    
                    val transferInfo = progressManager.getTransfer(fileName)
                    if (transferInfo != null) {
                        onTransferCompleted?.invoke(transferInfo)
                    }
                }
                
                override fun onTransferFailed(fileName: String, errorMessage: String) {
                    // 标记传输队列管理器中的传输失败
                    transferQueueManager.markTransferFailed(fileName, errorMessage)
                    // 标记进度管理器中的传输失败
                    progressManager.markTransferFailed(fileName, errorMessage)
                    
                    val transferInfo = progressManager.getTransfer(fileName)
                    if (transferInfo != null) {
                        onTransferFailed?.invoke(transferInfo, errorMessage)
                    }
                }
                
                override fun onTransferPaused(fileName: String) {
                    // 传输队列管理器已经有暂停状态管理
                    progressManager.markTransferPaused(fileName)
                }
                
                override fun onTransferCancelled(fileName: String) {
                    // 传输队列管理器已经有取消状态管理
                    progressManager.markTransferCancelled(fileName)
                }
                
                override fun onTransferStarted(transferInfo: com.waveyo.yolighttransfer.model.FileTransferInfo) {
                    // 传输队列管理器已经有传输开始管理
                    progressManager.registerTransfer(transferInfo)
                }
            }
        
        // 设置文件接收请求回调
        tcpServer.onFileReceiveRequest = { senderDeviceName, fileName, fileSize, callback ->
            // 当收到文件传输请求时，创建接收传输信息并添加到队列
            val transferInfo = com.waveyo.yolighttransfer.model.FileTransferInfo(
                fileName = fileName,
                fileSize = fileSize,
                filePath = "", // 文件路径将在接收过程中设置
                targetDevice = DeviceInfo(deviceName = senderDeviceName, ipAddress = ""),
                status = com.waveyo.yolighttransfer.model.TransferStatus.PENDING_RECEIVE
            )
            
            // 添加到传输队列
            transferQueueManager.addTransfer(transferInfo)
            
            // 显示文件接收确认对话框
            showFileReceiveDialog(senderDeviceName, fileName, fileSize, callback)
        }
        
        Log.d(TAG, "网络服务启动完成")
    }
    
    /**
     * 初始化设备ID
     */
    private fun initializeDeviceId() {
        // 首先尝试从配置中读取设备ID
        val savedDeviceId = configManager.getDeviceId()
        if (savedDeviceId != null) {
            currentDevice.deviceId = savedDeviceId
            Log.d(TAG, "使用已保存的设备ID: $savedDeviceId")
            return
        }
        
        // 如果没有保存的设备ID，则生成新的稳定设备ID
        val newDeviceId = generateStableDeviceId()
        currentDevice.deviceId = newDeviceId
        configManager.saveDeviceId(newDeviceId)
        Log.d(TAG, "生成新的稳定设备ID: $newDeviceId")
    }
    
    /**
     * 生成稳定的设备ID
     * 基于多个设备特征生成MD5哈希，确保唯一性和稳定性
     */
    fun generateStableDeviceId(): String {
        val deviceInfo = StringBuilder()
        
        try {
            // Android ID (相对稳定的设备标识符)
            val androidId = Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
            deviceInfo.append("android_id:").append(androidId ?: "unknown").append("|")
            
            // 设备序列号
            deviceInfo.append("serial:").append(android.os.Build.SERIAL).append("|")
            
            // 设备型号和制造商
            deviceInfo.append("model:").append(android.os.Build.MODEL).append("|")
            deviceInfo.append("manufacturer:").append(android.os.Build.MANUFACTURER).append("|")
            deviceInfo.append("brand:").append(android.os.Build.BRAND).append("|")
            
            // 硬件信息
            deviceInfo.append("hardware:").append(android.os.Build.HARDWARE).append("|")
            deviceInfo.append("device:").append(android.os.Build.DEVICE).append("|")
            
            // 添加时间戳作为额外熵
            deviceInfo.append("timestamp:").append(System.currentTimeMillis())
            
        } catch (e: Exception) {
            Log.w(TAG, "获取设备信息失败，使用UUID作为备选", e)
            return UUID.randomUUID().toString()
        }
        
        // 生成MD5哈希作为设备ID
        return generateMD5Hash(deviceInfo.toString())
    }
    
    /**
     * 生成MD5哈希
     */
    private fun generateMD5Hash(input: String): String {
        return try {
            val md = MessageDigest.getInstance("MD5")
            val digest = md.digest(input.toByteArray())
            val hexString = StringBuilder()
            for (byte in digest) {
                hexString.append(String.format("%02x", byte))
            }
            hexString.toString()
        } catch (e: Exception) {
            Log.w(TAG, "MD5哈希生成失败，使用UUID作为备选", e)
            UUID.randomUUID().toString()
        }
    }
    
    /**
     * 更新设备名称
     */
    fun updateDeviceName(deviceName: String) {
        configManager.saveDeviceName(deviceName)
        currentDevice.deviceName = deviceName
        Log.d(TAG, "设备名称已更新: $deviceName")
    }
    
    /**
     * 更新设备ID（仅在冲突时使用）
     */
    fun updateDeviceId(newDeviceId: String) {
        currentDevice.deviceId = newDeviceId
        configManager.saveDeviceId(newDeviceId)
        Log.d(TAG, "设备ID已更新: $newDeviceId")
    }
    
    /**
     * 获取设备管理器
     */
    fun getDeviceManager(): DeviceManager {
        return deviceManager
    }
    
    /**
     * 获取配置管理器
     */
    fun getConfigManager(): ConfigManager {
        return configManager
    }
    
    /**
     * 清理资源
     */
    fun cleanup() {
        Log.d(TAG, "开始清理AppManager资源...")
        
        // 停止网络服务
        stopNetworkServices()
        
        // 清理设备管理器
        deviceManager.cleanup()
        
        Log.d(TAG, "AppManager资源已清理")
    }
    
    /**
     * 停止网络服务
     */
    private fun stopNetworkServices() {
        Log.d(TAG, "停止网络服务...")
        
        // 停止UDP广播
        deviceDiscoveryManager.stopBroadcast()
        
        // 停止UDP监听器
        deviceDiscoveryManager.stopListener()
        
        // 停止TCP服务器
        tcpServer.stopServer()
        
        // 清理设备发现管理器
        deviceDiscoveryManager.cleanup()
        
        // 清理TCP服务器
        tcpServer.cleanup()
        
        Log.d(TAG, "网络服务已停止")
    }
    
    /**
     * 获取在线设备列表
     */
    fun getOnlineDevices(): List<DeviceInfo> {
        return deviceManager.getOnlineDevices()
    }
    
    /**
     * 获取活跃传输列表
     */
    fun getActiveTransfers(): List<com.waveyo.yolighttransfer.model.FileTransferInfo> {
        return transferQueueManager.getActiveTransfers()
    }
    
    /**
     * 获取所有传输任务（包括等待接收确认的任务）
     */
    fun getAllTransfers(): List<com.waveyo.yolighttransfer.model.FileTransferInfo> {
        return transferQueueManager.getAllTransfers()
    }
    
    /**
     * 获取传输队列管理器
     */
    fun getTransferQueueManager(): TransferQueueManager {
        return transferQueueManager
    }

    /**
     * 获取进度管理器
     */
    fun getProgressManager(): ProgressManager {
        return progressManager
    }
    
    /**
     * 添加传输任务到队列
     */
    fun addTransferToQueue(transferInfo: com.waveyo.yolighttransfer.model.FileTransferInfo) {
        transferQueueManager.addTransfer(transferInfo)
    }
    
    /**
     * 暂停传输任务
     */
    fun pauseTransfer(fileName: String): Boolean {
        return transferQueueManager.pauseTransfer(fileName)
    }
    
    /**
     * 继续传输任务
     */
    fun resumeTransfer(fileName: String): Boolean {
        return transferQueueManager.resumeTransfer(fileName)
    }
    
    /**
     * 取消传输任务
     */
    fun cancelTransfer(fileName: String): Boolean {
        return transferQueueManager.cancelTransfer(fileName)
    }
    
    /**
     * 重试传输任务
     */
    fun retryTransfer(fileName: String): Boolean {
        return transferQueueManager.retryTransfer(fileName)
    }
    
    /**
     * 清空传输队列
     */
    fun clearTransferQueue() {
        transferQueueManager.clearQueue()
    }
    
    /**
     * 获取日志统计信息
     */
    fun getLogStats(): String {
        return logManager.getLogStats()
    }
    
    /**
     * 导出日志
     */
    fun exportLogs(): java.io.File? {
        return logManager.exportLogs()
    }
    
    /**
     * 清除日志
     */
    fun clearLogs() {
        logManager.clearLogs()
    }
    
    /**
     * 检查日志是否启用
     */
    fun isLoggingEnabled(): Boolean {
        return logManager.isLoggingEnabled()
    }
    
    /**
     * 设置日志启用状态
     */
    fun setLoggingEnabled(enabled: Boolean) {
        logManager.setEnabled(enabled)
    }
    
    /**
     * 获取当前设备信息
     */
    fun getCurrentDeviceInfo(): DeviceInfo {
        return currentDevice
    }
    
    /**
     * 获取TCP服务器实例
     */
    fun getTCPServer(): com.waveyo.yolighttransfer.network.TCPServer {
        return tcpServer
    }
    
    /**
     * 获取调试信息
     */
    fun getDebugInfo(): String {
        return """
            应用调试信息:
            - 设备名称: ${currentDevice.deviceName}
            - 设备ID: ${currentDevice.deviceId}
            - 在线设备数: ${getOnlineDevices().size}
            - 日志记录: ${if (isLoggingEnabled()) "启用" else "禁用"}
        """.trimIndent()
    }
    
    /**
     * 显示文件接收确认对话框
     */
    private fun showFileReceiveDialog(
        senderDeviceName: String,
        fileName: String,
        fileSize: Long,
        callback: (Boolean) -> Unit
    ) {
        // 通过回调通知UI显示文件接收对话框
        onFileReceiveRequest?.invoke(senderDeviceName, fileName, fileSize, callback)
    }
}
