package com.waveyo.yolighttransfer.network

import android.content.Context
import android.net.Uri
import android.util.Log
import com.waveyo.yolighttransfer.manager.TransferListener
import com.waveyo.yolighttransfer.model.DeviceInfo
import com.waveyo.yolighttransfer.model.FileTransferInfo
import kotlinx.coroutines.*
import java.io.*
import java.net.Socket
import java.util.concurrent.ConcurrentHashMap

/**
 * TCP客户端 - 发送文件
 * 使用新的传输监听器架构，移除内部进度回调
 */
class TCPClient(private val context: Context) {
    
    companion object {
        private const val TAG = "TCPClient"
        private const val CONNECTION_TIMEOUT = 10000 // 10秒连接超时
        private const val CHUNK_SIZE = 1024 * 1024 // 1MB分片大小
        private const val BUFFER_SIZE = 8192 // 8KB缓冲区
        private const val MAX_RETRY_COUNT = 3 // 最大重连次数
        private const val RETRY_DELAY_MS = 2000L // 重连延迟（毫秒）
        private const val PROGRESS_UPDATE_INTERVAL = 1024 * 1024 // 每1MB更新一次进度
        private const val HEARTBEAT_INTERVAL_MS = 5000L // 心跳间隔（5秒，符合协议建议）
        private const val CONTROL_FRAME_RETRY_COUNT = 3 // 控制帧重试次数
        private const val CONTROL_FRAME_RETRY_DELAY_MS = 1000L // 控制帧重试延迟
    }
    
    // 传输监听器
    var transferListener: TransferListener? = null
    
    // 正在进行的传输任务
    private val activeTransfers = ConcurrentHashMap<String, FileTransferInfo>()
    private val activeJobs = ConcurrentHashMap<String, Job>()
    private val heartbeatJobs = ConcurrentHashMap<String, Job>()
    private val transferScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    /**
     * 发送文件到目标设备（带重连机制）
     */
    fun sendFile(
        fileUri: Uri,
        targetDevice: DeviceInfo,
        resumeOffset: Long = 0
    ) {
        transferScope.launch {
            try {
                // 解析文件信息
                val fileInfo = getFileInfo(fileUri) ?: return@launch
                
                // 创建传输信息
                val transferInfo = FileTransferInfo(
                    fileName = fileInfo.first,
                    fileSize = fileInfo.second,
                    filePath = fileUri.toString(),
                    targetDevice = targetDevice,
                    transferredBytes = resumeOffset,
                    status = com.waveyo.yolighttransfer.model.TransferStatus.TRANSFERRING
                )
                
                activeTransfers[fileInfo.first] = transferInfo
                activeJobs[fileInfo.first] = this.coroutineContext.job

                // 启动心跳
                startHeartbeat(transferInfo)
                
                // 带重连机制的文件传输
                sendFileWithRetry(fileUri, targetDevice, transferInfo, resumeOffset)
                
            } catch (e: Exception) {
                handleTransferException(e, fileUri, "发送文件失败")
            }
        }
    }
    
    /**
     * 带重连机制的文件传输
     */
    private suspend fun sendFileWithRetry(
        fileUri: Uri,
        targetDevice: DeviceInfo,
        transferInfo: FileTransferInfo,
        resumeOffset: Long
    ) {
        var retryCount = 0
        var currentOffset = resumeOffset
        
        while (retryCount <= MAX_RETRY_COUNT) {
            var socket: Socket? = null
            var inputStream: DataInputStream? = null
            var outputStream: DataOutputStream? = null
            var fileInputStream: DataInputStream? = null
            
            try {
                Log.d(TAG, "尝试连接目标设备: ${targetDevice.ipAddress}:${targetDevice.tcpPort}, 重试次数: $retryCount")
                
                // 建立TCP连接
                socket = Socket().apply {
                    soTimeout = CONNECTION_TIMEOUT
                }
                socket.connect(java.net.InetSocketAddress(targetDevice.ipAddress, targetDevice.tcpPort), CONNECTION_TIMEOUT)
                
                inputStream = DataInputStream(socket.getInputStream())
                outputStream = DataOutputStream(socket.getOutputStream())
                
                // 发送文件传输头信息
                outputStream.writeUTF(transferInfo.fileName)
                outputStream.writeLong(transferInfo.fileSize)
                outputStream.writeInt(calculateTotalChunks(transferInfo.fileSize))
                outputStream.writeLong(currentOffset)
                outputStream.flush()
                
                // 等待服务器确认
                val serverReady = inputStream.readBoolean()
                if (!serverReady) {
                    throw IOException("服务器未准备好接收文件")
                }
                
                // 打开文件输入流
                val fileInput = context.contentResolver.openInputStream(fileUri)
                    ?: throw IOException("无法打开文件输入流")
                
                fileInputStream = DataInputStream(BufferedInputStream(fileInput))
                
                // 跳过已传输的字节（断点续传）
                if (currentOffset > 0) {
                    fileInputStream.skip(currentOffset)
                }
                
                // 发送文件数据
                currentOffset = sendFileDataWithRetry(fileInputStream, outputStream, inputStream, transferInfo, currentOffset)
                
                // 传输完成
                transferInfo.status = com.waveyo.yolighttransfer.model.TransferStatus.COMPLETED
                transferListener?.onTransferCompleted(transferInfo.fileName)
                Log.d(TAG, "文件发送完成: ${transferInfo.fileName}")
                break
                
            } catch (e: Exception) {
                // 检查是否是网络连接错误
                if (isNetworkError(e) && retryCount < MAX_RETRY_COUNT) {
                    retryCount++
                    Log.w(TAG, "网络连接错误，尝试重连 (${retryCount}/${MAX_RETRY_COUNT}): ${e.message}")
                    
                    // 更新传输进度
                    transferInfo.transferredBytes = currentOffset
                    transferListener?.onProgressUpdated(transferInfo.fileName, currentOffset, transferInfo.fileSize)
                    
                    // 等待一段时间后重试
                    delay(RETRY_DELAY_MS * retryCount) // 指数退避
                } else {
                    // 重试次数用完或其他错误，抛出异常
                    throw e
                }
            } finally {
                try {
                    fileInputStream?.close()
                    outputStream?.close()
                    inputStream?.close()
                    socket?.close()
                } catch (e: Exception) {
                    Log.e(TAG, "关闭连接失败: ${e.message}")
                }
            }
        }
        
        // 清理任务
        heartbeatJobs.remove(transferInfo.fileName)?.cancel()
        activeJobs.remove(transferInfo.fileName)
        activeTransfers.remove(transferInfo.fileName)
    }
    
    /**
     * 发送文件数据（带重连机制）
     */
    private suspend fun sendFileDataWithRetry(
        fileInputStream: DataInputStream,
        outputStream: DataOutputStream,
        inputStream: DataInputStream,
        transferInfo: FileTransferInfo,
        startOffset: Long
    ): Long {
        val buffer = ByteArray(BUFFER_SIZE)
        var bytesSent = startOffset
        var chunkIndex = (startOffset / CHUNK_SIZE).toInt()
        
        while (bytesSent < transferInfo.fileSize) {
            val remainingBytes = transferInfo.fileSize - bytesSent
            val currentChunkSize = minOf(CHUNK_SIZE.toLong(), remainingBytes).toInt()
            
            // 发送分片头信息
            outputStream.writeInt(chunkIndex)
            outputStream.writeInt(currentChunkSize)
            outputStream.writeLong(bytesSent)
            outputStream.flush()
            
                // 发送分片数据
                var remainingInChunk = currentChunkSize
                var lastProgressUpdate = bytesSent
                
                while (remainingInChunk > 0) {
                    val readSize = minOf(remainingInChunk, buffer.size)
                    val bytesRead = fileInputStream.read(buffer, 0, readSize)
                    if (bytesRead == -1) break
                    
                    outputStream.write(buffer, 0, bytesRead)
                    remainingInChunk -= bytesRead
                    bytesSent += bytesRead
                    
                    // 优化进度更新频率：每1MB更新一次
                    if (bytesSent - lastProgressUpdate >= PROGRESS_UPDATE_INTERVAL) {
                        transferInfo.updateProgress(bytesSent)
                        transferListener?.onProgressUpdated(transferInfo.fileName, bytesSent, transferInfo.fileSize)
                        lastProgressUpdate = bytesSent
                    }
                    
                    // 等待服务器确认
                    val ack = inputStream.readBoolean()
                    if (!ack) {
                        throw IOException("服务器确认失败")
                    }
                }
                
                // 确保分片结束时更新进度
                if (bytesSent > lastProgressUpdate) {
                    transferInfo.updateProgress(bytesSent)
                    transferListener?.onProgressUpdated(transferInfo.fileName, bytesSent, transferInfo.fileSize)
                }
            
            Log.d(TAG, "发送分片 $chunkIndex, 大小: $currentChunkSize, 总进度: $bytesSent/${transferInfo.fileSize}")
            chunkIndex++
            
            // 小延迟避免过快发送
            delay(10)
        }
        
        return bytesSent
    }
    
    /**
     * 判断是否是网络错误
     */
    private fun isNetworkError(e: Exception): Boolean {
        val message = e.message?.lowercase() ?: ""
        return when {
            e is java.net.ConnectException -> true
            e is java.net.SocketTimeoutException -> true
            e is java.net.SocketException -> true
            "connection reset" in message -> true
            "connection refused" in message -> true
            "network is unreachable" in message -> true
            "timeout" in message -> true
            "socket" in message -> true
            else -> false
        }
    }
    
    /**
     * 处理传输异常
     */
    private fun handleTransferException(e: Exception, fileUri: Uri, context: String) {
        Log.e(TAG, "$context: ${e.message}")
        
        // 通知传输失败
        val fileName = try {
            fileUri.lastPathSegment ?: "unknown"
        } catch (ex: Exception) {
            "unknown"
        }
        
        val transferInfo = activeTransfers[fileName]
        if (transferInfo != null) {
            transferInfo.status = com.waveyo.yolighttransfer.model.TransferStatus.FAILED
            transferInfo.errorMessage = getFriendlyErrorMessage(e)
            transferListener?.onTransferFailed(fileName, transferInfo.errorMessage ?: "未知错误")
        }
        
        // 清理任务
        activeJobs.remove(fileName)
        activeTransfers.remove(fileName)
    }
    
    /**
     * 获取友好的错误信息
     */
    private fun getFriendlyErrorMessage(e: Exception): String {
        val message = e.message?.lowercase() ?: ""
        return when {
            "connection reset" in message -> "网络连接被重置，请检查网络连接"
            "connection refused" in message -> "连接被拒绝，请确保接收端应用正在运行"
            "timeout" in message -> "连接超时，请检查网络连接"
            "network is unreachable" in message -> "网络不可达，请检查网络连接"
            "socket" in message -> "网络连接异常，请重试"
            "file not found" in message -> "文件不存在或无法访问"
            "permission denied" in message -> "没有文件访问权限"
            else -> "传输失败: ${e.message ?: "未知错误"}"
        }
    }
    
    /**
     * 获取文件信息
     */
    private fun getFileInfo(fileUri: Uri): Pair<String, Long>? {
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
            Log.e(TAG, "获取文件信息失败: ${e.message}")
            null
        }
    }
    
    /**
     * 计算总分片数
     */
    private fun calculateTotalChunks(fileSize: Long): Int {
        return ((fileSize + CHUNK_SIZE - 1) / CHUNK_SIZE).toInt()
    }
    
    /**
     * 取消传输
     */
    fun cancelTransfer(fileName: String): Boolean {
        val job = activeJobs[fileName]
        val transferInfo = activeTransfers[fileName]
        
        return if (job != null && transferInfo != null) {
            // 先通知对端取消
            transferScope.launch {
                val frame = com.waveyo.yolighttransfer.network.ControlFrame.createCancel(
                    transferInfo.fileName,
                    "用户取消传输"
                )
                sendControlFrameWithRetry(transferInfo.targetDevice, frame, "CANCEL")
            }
            // 取消传输任务
            job.cancel("用户取消传输")
            transferInfo.status = com.waveyo.yolighttransfer.model.TransferStatus.CANCELLED
            activeJobs.remove(fileName)
            activeTransfers.remove(fileName)
            Log.d(TAG, "取消传输任务: $fileName")
            true
        } else {
            Log.w(TAG, "找不到活跃的传输任务: $fileName")
            false
        }
    }
    
    /**
     * 获取正在进行的传输任务
     */
    fun getActiveTransfers(): List<FileTransferInfo> {
        return activeTransfers.values.toList()
    }
    
    /**
     * 发送控制帧（短连接 JSON + UTF）
     */
    private suspend fun sendControlFrame(targetDevice: com.waveyo.yolighttransfer.model.DeviceInfo, frame: com.waveyo.yolighttransfer.network.ControlFrame, waitAck: Boolean = true): Boolean {
        return try {
            withContext(Dispatchers.IO) {
                var socket: Socket? = null
                var inputStream: DataInputStream? = null
                var outputStream: DataOutputStream? = null
                try {
                    socket = Socket().apply { soTimeout = 5000 }
                    socket.connect(java.net.InetSocketAddress(targetDevice.ipAddress, targetDevice.tcpPort), 5000)
                    inputStream = DataInputStream(socket.getInputStream())
                    outputStream = DataOutputStream(socket.getOutputStream())

                    // 发送 JSON 控制帧（UTF 帧）
                    outputStream.writeUTF(frame.toJson())
                    outputStream.flush()

                    if (waitAck) {
                        val resp = inputStream.readUTF()
                        val ack = com.waveyo.yolighttransfer.network.ControlFrame.fromJson(resp)
                        val ok = ack.op.equals("ACK", ignoreCase = true) || ack.op.equals("PONG", ignoreCase = true)
                        if (!ok) Log.w(TAG, "控制帧确认非 ACK/PONG: ${ack.op}")
                        ok
                    } else true
                } finally {
                    try { inputStream?.close() } catch (_: Exception) {}
                    try { outputStream?.close() } catch (_: Exception) {}
                    try { socket?.close() } catch (_: Exception) {}
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "发送控制帧失败: ${e.message}")
            false
        }
    }

    /**
     * 发送控制帧（带重试机制）
     */
    private suspend fun sendControlFrameWithRetry(targetDevice: com.waveyo.yolighttransfer.model.DeviceInfo, frame: com.waveyo.yolighttransfer.network.ControlFrame, operation: String): Boolean {
        var retryCount = 0
        while (retryCount < CONTROL_FRAME_RETRY_COUNT) {
            val success = sendControlFrame(targetDevice, frame, waitAck = true)
            if (success) {
                Log.d(TAG, "$operation 控制帧发送成功: ${frame.transferId}")
                return true
            } else {
                retryCount++
                Log.w(TAG, "$operation 控制帧发送失败，重试 ($retryCount/$CONTROL_FRAME_RETRY_COUNT): ${frame.transferId}")
                if (retryCount < CONTROL_FRAME_RETRY_COUNT) {
                    delay(CONTROL_FRAME_RETRY_DELAY_MS * retryCount)
                }
            }
        }
        Log.e(TAG, "$operation 控制帧发送失败，重试次数用尽: ${frame.transferId}")
        return false
    }

    /** 启动心跳任务（短连接 PING/PONG） */
    private fun startHeartbeat(transferInfo: FileTransferInfo) {
        val fileName = transferInfo.fileName
        if (heartbeatJobs.containsKey(fileName)) return
        val job = transferScope.launch {
            var consecutiveFailures = 0
            while (isActive && activeTransfers.containsKey(fileName)) {
                delay(HEARTBEAT_INTERVAL_MS)
                val ok = try {
                    val ping = com.waveyo.yolighttransfer.network.ControlFrame.createPing(fileName)
                    sendControlFrame(transferInfo.targetDevice, ping, waitAck = true)
                } catch (e: Exception) {
                    Log.w(TAG, "心跳发送失败($fileName): ${e.message}")
                    false
                }
                if (!ok) {
                    consecutiveFailures++
                    Log.w(TAG, "心跳未收到响应($fileName) 次数=$consecutiveFailures")
                    if (consecutiveFailures >= 3) {
                        transferListener?.onTransferFailed(fileName, "对端无响应(PING超时)")
                        break
                    }
                } else {
                    consecutiveFailures = 0
                }
            }
        }
        heartbeatJobs[fileName] = job
    }

    /**
     * 清理资源
     */
    fun cleanup() {
        // 取消所有活跃传输
        activeJobs.values.forEach { job ->
            job.cancel("清理资源")
        }
        activeJobs.clear()
        activeTransfers.clear()
        transferScope.cancel()
    }
}
