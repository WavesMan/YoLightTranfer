package com.waveyo.yolighttransfer.network

import android.content.Context
import android.net.Uri
import android.util.Log
import com.waveyo.yolighttransfer.model.DeviceInfo
import com.waveyo.yolighttransfer.model.FileTransferInfo
import kotlinx.coroutines.*
import java.io.*
import java.net.Socket
import java.util.concurrent.ConcurrentHashMap

/**
 * TCP客户端 - 发送文件
 */
class TCPClient(private val context: Context) {
    
    companion object {
        private const val TAG = "TCPClient"
        private const val CONNECTION_TIMEOUT = 10000 // 10秒连接超时
        private const val CHUNK_SIZE = 1024 * 1024 // 1MB分片大小
        private const val BUFFER_SIZE = 8192 // 8KB缓冲区
    }
    
    // 传输进度回调
    var onTransferProgress: ((FileTransferInfo) -> Unit)? = null
    var onTransferCompleted: ((FileTransferInfo) -> Unit)? = null
    var onTransferFailed: ((FileTransferInfo, String) -> Unit)? = null
    
    // 正在进行的传输任务
    private val activeTransfers = ConcurrentHashMap<String, FileTransferInfo>()
    private val activeJobs = ConcurrentHashMap<String, Job>()
    private val transferScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    /**
     * 发送文件到目标设备
     */
    fun sendFile(
        fileUri: Uri,
        targetDevice: DeviceInfo,
        resumeOffset: Long = 0
    ) {
        transferScope.launch {
            var socket: Socket? = null
            var inputStream: DataInputStream? = null
            var outputStream: DataOutputStream? = null
            var fileInputStream: DataInputStream? = null
            
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
                
                // 建立TCP连接
                socket = Socket().apply {
                    soTimeout = CONNECTION_TIMEOUT
                }
                socket.connect(java.net.InetSocketAddress(targetDevice.ipAddress, targetDevice.tcpPort), CONNECTION_TIMEOUT)
                
                inputStream = DataInputStream(socket.getInputStream())
                outputStream = DataOutputStream(socket.getOutputStream())
                
                // 发送文件传输头信息
                outputStream.writeUTF(fileInfo.first)
                outputStream.writeLong(fileInfo.second)
                outputStream.writeInt(calculateTotalChunks(fileInfo.second))
                outputStream.writeLong(resumeOffset)
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
                if (resumeOffset > 0) {
                    fileInputStream.skip(resumeOffset)
                }
                
                // 发送文件数据
                sendFileData(fileInputStream, outputStream, inputStream, transferInfo, resumeOffset)
                
                // 传输完成
                transferInfo.status = com.waveyo.yolighttransfer.model.TransferStatus.COMPLETED
                onTransferCompleted?.invoke(transferInfo)
                Log.d(TAG, "文件发送完成: ${fileInfo.first}")
                
            } catch (e: Exception) {
                // 检查是否是暂停导致的取消
                if (e is CancellationException && e.message == "用户暂停传输") {
                    Log.d(TAG, "传输任务被暂停: ${e.message}")
                    // 暂停状态已经在pauseTransfer方法中设置，这里不需要额外处理
                } else {
                    Log.e(TAG, "发送文件失败: ${e.message}")
                    
                    // 通知传输失败
                    val fileName = try {
                        fileUri.lastPathSegment ?: "unknown"
                    } catch (ex: Exception) {
                        "unknown"
                    }
                    
                    val transferInfo = activeTransfers[fileName]
                    if (transferInfo != null) {
                        transferInfo.status = com.waveyo.yolighttransfer.model.TransferStatus.FAILED
                        transferInfo.errorMessage = e.message
                        onTransferFailed?.invoke(transferInfo, e.message ?: "未知错误")
                    }
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
                
                // 清理任务
                val fileName = try {
                    fileUri.lastPathSegment ?: "unknown"
                } catch (ex: Exception) {
                    "unknown"
                }
                activeJobs.remove(fileName)
                activeTransfers.remove(fileName)
            }
        }
    }
    
    /**
     * 发送文件数据
     */
    private suspend fun sendFileData(
        fileInputStream: DataInputStream,
        outputStream: DataOutputStream,
        inputStream: DataInputStream,
        transferInfo: FileTransferInfo,
        startOffset: Long
    ) {
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
            while (remainingInChunk > 0) {
                val readSize = minOf(remainingInChunk, buffer.size)
                val bytesRead = fileInputStream.read(buffer, 0, readSize)
                if (bytesRead == -1) break
                
                outputStream.write(buffer, 0, bytesRead)
                remainingInChunk -= bytesRead
                bytesSent += bytesRead
                
                // 更新传输进度
                transferInfo.updateProgress(bytesSent)
                onTransferProgress?.invoke(transferInfo)
                
                // 等待服务器确认
                val ack = inputStream.readBoolean()
                if (!ack) {
                    throw IOException("服务器确认失败")
                }
            }
            
            Log.d(TAG, "发送分片 $chunkIndex, 大小: $currentChunkSize, 总进度: $bytesSent/${transferInfo.fileSize}")
            chunkIndex++
            
            // 小延迟避免过快发送
            delay(10)
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
     * 暂停传输
     */
    fun pauseTransfer(fileName: String): Boolean {
        val job = activeJobs[fileName]
        val transferInfo = activeTransfers[fileName]
        
        return if (job != null && transferInfo != null && transferInfo.status == com.waveyo.yolighttransfer.model.TransferStatus.TRANSFERRING) {
            // 暂停传输 - 取消当前任务但保留传输进度
            job.cancel("用户暂停传输")
            transferInfo.status = com.waveyo.yolighttransfer.model.TransferStatus.PAUSED
            Log.d(TAG, "暂停传输任务: $fileName")
            true
        } else {
            Log.w(TAG, "找不到活跃的传输任务: $fileName")
            false
        }
    }
    
    /**
     * 继续传输任务
     */
    fun resumeTransfer(fileName: String, fileUri: Uri, targetDevice: DeviceInfo): Boolean {
        val transferInfo = activeTransfers[fileName]
        return if (transferInfo != null && transferInfo.status == com.waveyo.yolighttransfer.model.TransferStatus.PAUSED) {
            // 从暂停位置继续传输
            sendFile(fileUri, targetDevice, transferInfo.transferredBytes)
            transferInfo.status = com.waveyo.yolighttransfer.model.TransferStatus.TRANSFERRING
            Log.d(TAG, "继续传输任务: $fileName")
            true
        } else {
            Log.w(TAG, "无法继续传输任务: $fileName")
            false
        }
    }
    
    /**
     * 取消传输
     */
    fun cancelTransfer(fileName: String): Boolean {
        val job = activeJobs[fileName]
        val transferInfo = activeTransfers[fileName]
        
        return if (job != null && transferInfo != null) {
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
