package com.waveyo.yolighttransfer.network

import android.content.Context
import android.os.Environment
import android.util.Log
import com.waveyo.yolighttransfer.manager.TransferListener
import com.waveyo.yolighttransfer.model.DeviceInfo
import com.waveyo.yolighttransfer.model.FileTransferInfo
import com.waveyo.yolighttransfer.model.TransferStatus
import kotlinx.coroutines.suspendCancellableCoroutine
import java.io.*
import java.net.Socket
import java.util.concurrent.ConcurrentHashMap
import kotlin.coroutines.resume

/**
 * 文件接收器 - 专门处理文件接收逻辑
 */
class FileReceiver(
    private val context: Context,
    private val activeTransfers: ConcurrentHashMap<String, FileTransferInfo>,
    private val transferListener: TransferListener?,
    private val onFileReceiveRequest: ((String, String, Long, (Boolean) -> Unit) -> Unit)?
) {
    
    companion object {
        private const val TAG = "FileReceiver"
        private const val BUFFER_SIZE = 8192 // 8KB缓冲区
    }
    
    /**
     * 处理文件传输连接
     */
    suspend fun handleFileTransfer(clientSocket: Socket) {
        var inputStream: DataInputStream? = null
        var outputStream: DataOutputStream? = null
        
        try {
            inputStream = DataInputStream(clientSocket.getInputStream())
            outputStream = DataOutputStream(clientSocket.getOutputStream())
            
            // 读取文件传输请求
            val fileName = inputStream.readUTF()
            val fileSize = inputStream.readLong()
            val totalChunks = inputStream.readInt()
            val resumeOffset = inputStream.readLong()
            
            Log.d(TAG, "收到文件传输请求: $fileName, 大小: $fileSize, 来自: ${clientSocket.inetAddress.hostAddress}")
            
            // 获取发送方设备名称
            val senderDeviceName = getSenderDeviceName(clientSocket.inetAddress.hostAddress ?: "unknown")
            
            // 创建文件传输信息
            val transferInfo = FileTransferInfo(
                fileName = fileName,
                fileSize = fileSize,
                filePath = getOutputFilePath(fileName),
                targetDevice = DeviceInfo(deviceName = senderDeviceName, ipAddress = clientSocket.inetAddress.hostAddress ?: ""),
                transferredBytes = resumeOffset,
                status = TransferStatus.PENDING_RECEIVE
            )
            
            activeTransfers[fileName] = transferInfo
            
            // 立即通知UI显示接收请求
            Log.d(TAG, "通知UI显示接收请求: $fileName, 状态: ${transferInfo.status}")
            transferListener?.onTransferStarted(transferInfo)
            
            // 等待用户确认
            val userAccepted = waitForUserConfirmation(senderDeviceName, fileName, fileSize)
            
            if (userAccepted) {
                // 用户接受，确认接收准备就绪
                outputStream.writeBoolean(true)
                outputStream.flush()
                
                transferInfo.status = TransferStatus.TRANSFERRING
                Log.d(TAG, "用户接受接收请求，更新状态为TRANSFERRING: $fileName")
                
                // 接收文件数据
                receiveFileData(inputStream, outputStream, transferInfo, resumeOffset)
                
                // 传输完成
                transferInfo.status = TransferStatus.COMPLETED
                
                // 验证文件是否存在
                val receivedFile = File(transferInfo.filePath)
                if (receivedFile.exists()) {
                    Log.d(TAG, "文件接收完成: $fileName, 文件大小: ${receivedFile.length()} bytes")
                    Log.d(TAG, "文件实际保存位置: ${receivedFile.absolutePath}")
                } else {
                    Log.e(TAG, "文件接收完成但文件不存在: $fileName")
                }
                
                transferListener?.onTransferCompleted(fileName)
                Log.d(TAG, "文件接收完成: $fileName")
            } else {
                // 用户拒绝，发送拒绝信号
                outputStream.writeBoolean(false)
                outputStream.flush()
                Log.d(TAG, "用户拒绝接收文件: $fileName")
                
                transferInfo.status = TransferStatus.REJECTED
                transferListener?.onTransferFailed(fileName, "用户拒绝接收")
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "处理文件传输失败: ${e.message}")
            // 通知传输失败
            val fileName = try {
                inputStream?.readUTF() ?: "unknown"
            } catch (ex: Exception) {
                "unknown"
            }
            
            val transferInfo = activeTransfers[fileName]
            if (transferInfo != null) {
                transferInfo.status = TransferStatus.FAILED
                transferInfo.errorMessage = e.message
                transferListener?.onTransferFailed(fileName, e.message ?: "未知错误")
            }
        } finally {
            try {
                inputStream?.close()
                outputStream?.close()
                clientSocket.close()
            } catch (e: Exception) {
                Log.e(TAG, "关闭文件传输连接失败: ${e.message}")
            }
        }
    }
    
    /**
     * 接收文件数据
     */
    private suspend fun receiveFileData(
        inputStream: DataInputStream,
        outputStream: DataOutputStream,
        transferInfo: FileTransferInfo,
        startOffset: Long
    ) {
        var outputStreamFile: FileOutputStream? = null
        
        try {
            // 打开文件输出流，支持断点续传
            val file = File(transferInfo.filePath)
            if (startOffset > 0 && file.exists()) {
                // 续传模式
                outputStreamFile = FileOutputStream(file, true)
            } else {
                // 新文件模式
                outputStreamFile = FileOutputStream(file)
            }
            
            val buffer = ByteArray(BUFFER_SIZE)
            var bytesReceived = startOffset
            
            while (bytesReceived < transferInfo.fileSize) {
                // 读取分片信息
                val chunkIndex = inputStream.readInt()
                val chunkSize = inputStream.readInt()
                val chunkOffset = inputStream.readLong()
                
                // 读取分片数据
                var remaining = chunkSize
                while (remaining > 0) {
                    val readSize = minOf(remaining, buffer.size)
                    val bytesRead = inputStream.read(buffer, 0, readSize)
                    if (bytesRead == -1) break
                    
                    outputStreamFile.write(buffer, 0, bytesRead)
                    remaining -= bytesRead
                    bytesReceived += bytesRead
                    
                    // 更新传输进度
                    transferInfo.updateProgress(bytesReceived)
                    transferListener?.onProgressUpdated(transferInfo.fileName, bytesReceived, transferInfo.fileSize)
                    
                    // 发送确认信号
                    outputStream.writeBoolean(true)
                    outputStream.flush()
                }
                
                Log.d(TAG, "接收分片 $chunkIndex, 大小: $chunkSize, 总进度: $bytesReceived/${transferInfo.fileSize}")
            }
            
        } catch (e: Exception) {
            throw e
        } finally {
            try {
                outputStreamFile?.close()
            } catch (e: Exception) {
                Log.e(TAG, "关闭文件输出流失败: ${e.message}")
            }
        }
    }
    
    /**
     * 获取输出文件路径
     */
    private fun getOutputFilePath(fileName: String): String {
        // 在公共下载目录创建YoLightTransfer文件夹
        val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        val appDir = File(downloadsDir, "YoLightTransfer")
        
        // 确保目录存在
        if (!appDir.exists()) {
            appDir.mkdirs()
        }
        
        val filePath = File(appDir, fileName).absolutePath
        Log.d(TAG, "文件保存路径: $filePath")
        Log.d(TAG, "目录是否存在: ${appDir.exists()}, 可写: ${appDir.canWrite()}")
        
        return filePath
    }
    
    /**
     * 获取发送方设备名称
     */
    private fun getSenderDeviceName(ipAddress: String): String {
        // 在实际实现中，这里应该从设备管理器获取设备名称
        // 暂时返回IP地址作为设备名称
        return "设备 ($ipAddress)"
    }
    
    /**
     * 等待用户确认
     */
    private suspend fun waitForUserConfirmation(
        senderDeviceName: String,
        fileName: String,
        fileSize: Long
    ): Boolean {
        return if (onFileReceiveRequest != null) {
            // 使用回调机制等待用户确认
            suspendCancellableCoroutine { continuation ->
                onFileReceiveRequest?.invoke(senderDeviceName, fileName, fileSize) { accepted ->
                    continuation.resume(accepted)
                }
            }
        } else {
            // 如果没有设置回调，默认接受
            true
        }
    }
}
