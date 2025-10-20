package com.waveyo.yolighttransfer.manager

import android.content.Context
import android.net.Uri
import android.util.Log
import com.waveyo.yolighttransfer.model.FileTransferInfo
import com.waveyo.yolighttransfer.model.TransferStatus
import com.waveyo.yolighttransfer.network.TCPClient
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * 传输执行器
 * 负责执行实际的传输任务，连接传输队列管理器和TCPClient
 */
class TransferExecutor(
    private val context: Context,
    private val transferQueueManager: TransferQueueManager
) {
    
    companion object {
        private const val TAG = "TransferExecutor"
    }
    
    private val activeClients = mutableMapOf<String, TCPClient>()
    
    /**
     * 执行传输任务
     */
    fun executeTransfer(transferInfo: FileTransferInfo) {
        Log.d(TAG, "开始执行传输任务: ${transferInfo.fileName}")
        
        CoroutineScope(Dispatchers.IO).launch {
            try {
                // 创建TCP客户端
                val tcpClient = TCPClient(context)
                activeClients[transferInfo.fileName] = tcpClient
                
                // 设置传输回调
                tcpClient.onTransferProgress = { progressInfo ->
                    transferQueueManager.updateTransferProgress(
                        transferInfo.fileName,
                        progressInfo.transferredBytes,
                        progressInfo.fileSize
                    )
                }
                
                tcpClient.onTransferCompleted = { completedInfo ->
                    transferQueueManager.markTransferCompleted(transferInfo.fileName)
                    activeClients.remove(transferInfo.fileName)
                }
                
                tcpClient.onTransferFailed = { failedInfo, error ->
                    transferQueueManager.markTransferFailed(transferInfo.fileName, error)
                    activeClients.remove(transferInfo.fileName)
                }
                
                // 执行实际的文件传输
                val fileUri = Uri.parse(transferInfo.filePath)
                tcpClient.sendFile(fileUri, transferInfo.targetDevice)
                
            } catch (e: Exception) {
                Log.e(TAG, "传输执行失败: ${transferInfo.fileName}, 错误: ${e.message}")
                transferQueueManager.markTransferFailed(transferInfo.fileName, e.message ?: "未知错误")
                activeClients.remove(transferInfo.fileName)
            }
        }
    }
    
    /**
     * 暂停传输任务
     */
    fun pauseTransfer(fileName: String): Boolean {
        val client = activeClients[fileName]
        return if (client != null) {
            client.pauseTransfer(fileName)
        } else {
            Log.w(TAG, "找不到活跃的传输客户端: $fileName")
            false
        }
    }
    
    /**
     * 继续传输任务
     */
    fun resumeTransfer(fileName: String): Boolean {
        val client = activeClients[fileName]
        val transferInfo = transferQueueManager.getTransfer(fileName)
        return if (client != null && transferInfo != null) {
            val fileUri = Uri.parse(transferInfo.filePath)
            client.resumeTransfer(fileName, fileUri, transferInfo.targetDevice)
        } else {
            Log.w(TAG, "找不到活跃的传输客户端或传输信息: $fileName")
            false
        }
    }
    
    /**
     * 取消传输任务
     */
    fun cancelTransfer(fileName: String): Boolean {
        val client = activeClients[fileName]
        return if (client != null) {
            client.cancelTransfer(fileName)
            activeClients.remove(fileName)
            Log.d(TAG, "取消传输任务: $fileName")
            true
        } else {
            Log.w(TAG, "找不到活跃的传输客户端: $fileName")
            false
        }
    }
    
    /**
     * 重试传输任务
     */
    fun retryTransfer(transferInfo: FileTransferInfo): Boolean {
        Log.d(TAG, "重试传输任务: ${transferInfo.fileName}")
        
        // 先取消当前传输（如果有）
        cancelTransfer(transferInfo.fileName)
        
        // 重新执行传输
        executeTransfer(transferInfo)
        return true
    }
    
    /**
     * 清理资源
     */
    fun cleanup() {
        // 取消所有活跃传输
        activeClients.keys.forEach { fileName ->
            cancelTransfer(fileName)
        }
        activeClients.clear()
        Log.d(TAG, "传输执行器已清理")
    }
}
