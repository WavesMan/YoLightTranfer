package com.waveyo.yolighttransfer.manager

import android.util.Log
import com.waveyo.yolighttransfer.model.FileTransferInfo
import com.waveyo.yolighttransfer.model.TransferStatus
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CopyOnWriteArrayList

/**
 * 传输队列管理器
 * 统一管理传输任务队列，支持传输控制功能
 */
class TransferQueueManager {
    
    companion object {
        private const val TAG = "TransferQueueManager"
        private const val MAX_CONCURRENT_TRANSFERS = 3 // 最大并发传输数
    }
    
    // 传输队列
    private val _transferQueue = MutableStateFlow<List<FileTransferInfo>>(emptyList())
    val transferQueue: StateFlow<List<FileTransferInfo>> = _transferQueue.asStateFlow()
    
    // 活跃传输任务
    private val activeTransfers = ConcurrentHashMap<String, FileTransferInfo>()
    
    // 传输队列监听器
    private val queueListeners = CopyOnWriteArrayList<TransferQueueListener>()
    
    // 传输执行器引用
    private var transferExecutor: TransferExecutor? = null
    
    /**
     * 设置传输执行器
     */
    fun setTransferExecutor(executor: TransferExecutor) {
        this.transferExecutor = executor
    }
    
    /**
     * 添加传输任务到队列
     */
    fun addTransfer(transferInfo: FileTransferInfo) {
        synchronized(this) {
            val currentQueue = _transferQueue.value.toMutableList()
            
            // 检查是否已存在相同文件名的传输任务
            val existingTransfer = currentQueue.find { it.fileName == transferInfo.fileName }
            if (existingTransfer != null) {
                Log.w(TAG, "传输任务已存在: ${transferInfo.fileName}")
                return
            }
            
            // 设置初始状态
            transferInfo.status = TransferStatus.PENDING
            
            // 添加到队列
            currentQueue.add(transferInfo)
            _transferQueue.value = currentQueue
            
            Log.d(TAG, "添加传输任务到队列: ${transferInfo.fileName}")
            
            // 通知监听器
            queueListeners.forEach { it.onTransferAdded(transferInfo) }
            
            // 尝试启动传输
            processQueue()
        }
    }
    
    /**
     * 从队列中移除传输任务
     */
    fun removeTransfer(fileName: String) {
        synchronized(this) {
            val currentQueue = _transferQueue.value.toMutableList()
            val transferToRemove = currentQueue.find { it.fileName == fileName }
            
            if (transferToRemove != null) {
                currentQueue.remove(transferToRemove)
                _transferQueue.value = currentQueue
                
                // 从活跃传输中移除
                activeTransfers.remove(fileName)
                
                Log.d(TAG, "从队列中移除传输任务: $fileName")
                
                // 通知监听器
                queueListeners.forEach { it.onTransferRemoved(transferToRemove) }
                
                // 处理队列，启动新的传输
                processQueue()
            }
        }
    }
    
    /**
     * 暂停传输任务
     */
    fun pauseTransfer(fileName: String): Boolean {
        synchronized(this) {
            val transfer = _transferQueue.value.find { it.fileName == fileName }
            if (transfer != null && transfer.status == TransferStatus.TRANSFERRING) {
                transfer.status = TransferStatus.PAUSED
                activeTransfers.remove(fileName)
                
                // 调用传输执行器暂停传输
                transferExecutor?.pauseTransfer(fileName)
                
                Log.d(TAG, "暂停传输任务: $fileName")
                
                // 通知监听器
                queueListeners.forEach { it.onTransferPaused(transfer) }
                
                // 处理队列，启动新的传输
                processQueue()
                return true
            }
            return false
        }
    }
    
    /**
     * 继续传输任务
     */
    fun resumeTransfer(fileName: String): Boolean {
        synchronized(this) {
            val transfer = _transferQueue.value.find { it.fileName == fileName }
            if (transfer != null && transfer.status == TransferStatus.PAUSED) {
                transfer.status = TransferStatus.PENDING
                
                // 调用传输执行器继续传输
                transferExecutor?.resumeTransfer(fileName)
                
                Log.d(TAG, "继续传输任务: $fileName")
                
                // 通知监听器
                queueListeners.forEach { it.onTransferResumed(transfer) }
                
                // 处理队列，启动传输
                processQueue()
                return true
            }
            return false
        }
    }
    
    /**
     * 取消传输任务
     */
    fun cancelTransfer(fileName: String): Boolean {
        synchronized(this) {
            val transfer = _transferQueue.value.find { it.fileName == fileName }
            if (transfer != null) {
                transfer.status = TransferStatus.CANCELLED
                
                // 调用传输执行器取消传输
                transferExecutor?.cancelTransfer(fileName)
                
                Log.d(TAG, "取消传输任务: $fileName")
                
                // 通知监听器
                queueListeners.forEach { it.onTransferCancelled(transfer) }
                
                // 从队列中移除
                removeTransfer(fileName)
                return true
            }
            return false
        }
    }
    
    /**
     * 重试传输任务
     */
    fun retryTransfer(fileName: String): Boolean {
        synchronized(this) {
            val transfer = _transferQueue.value.find { it.fileName == fileName }
            if (transfer != null && transfer.status == TransferStatus.FAILED) {
                transfer.status = TransferStatus.PENDING
                transfer.transferredBytes = 0
                transfer.progress = 0f
                transfer.errorMessage = null
                
                // 调用传输执行器重试传输
                transferExecutor?.retryTransfer(transfer)
                
                Log.d(TAG, "重试传输任务: $fileName")
                
                // 通知监听器
                queueListeners.forEach { it.onTransferRetried(transfer) }
                
                // 处理队列，启动传输
                processQueue()
                return true
            }
            return false
        }
    }
    
    /**
     * 更新传输进度
     */
    fun updateTransferProgress(fileName: String, transferredBytes: Long, fileSize: Long) {
        synchronized(this) {
            val transfer = _transferQueue.value.find { it.fileName == fileName }
            if (transfer != null) {
                transfer.updateProgress(transferredBytes)
                
                // 通知监听器
                queueListeners.forEach { it.onTransferProgress(transfer) }
            }
        }
    }
    
    /**
     * 标记传输完成
     */
    fun markTransferCompleted(fileName: String) {
        synchronized(this) {
            val transfer = _transferQueue.value.find { it.fileName == fileName }
            if (transfer != null) {
                transfer.status = TransferStatus.COMPLETED
                transfer.updateProgress(transfer.fileSize)
                
                // 从活跃传输中移除
                activeTransfers.remove(fileName)
                
                Log.d(TAG, "传输任务完成: $fileName")
                
                // 通知监听器
                queueListeners.forEach { it.onTransferCompleted(transfer) }
                
                // 处理队列，启动新的传输
                processQueue()
            }
        }
    }
    
    /**
     * 标记传输失败
     */
    fun markTransferFailed(fileName: String, errorMessage: String) {
        synchronized(this) {
            val transfer = _transferQueue.value.find { it.fileName == fileName }
            if (transfer != null) {
                transfer.status = TransferStatus.FAILED
                transfer.errorMessage = errorMessage
                
                // 从活跃传输中移除
                activeTransfers.remove(fileName)
                
                Log.e(TAG, "传输任务失败: $fileName, 错误: $errorMessage")
                
                // 通知监听器
                queueListeners.forEach { it.onTransferFailed(transfer, errorMessage) }
                
                // 处理队列，启动新的传输
                processQueue()
            }
        }
    }
    
    /**
     * 处理传输队列
     */
    private fun processQueue() {
        synchronized(this) {
            val currentQueue = _transferQueue.value
            
            // 检查当前活跃传输数量
            val currentActiveCount = activeTransfers.size
            
            // 如果活跃传输数量未达到上限，启动新的传输
            if (currentActiveCount < MAX_CONCURRENT_TRANSFERS) {
                val pendingTransfers = currentQueue.filter { 
                    it.status == TransferStatus.PENDING 
                }
                
                // 启动新的传输任务
                pendingTransfers.take(MAX_CONCURRENT_TRANSFERS - currentActiveCount).forEach { transfer ->
                    transfer.status = TransferStatus.TRANSFERRING
                    activeTransfers[transfer.fileName] = transfer
                    
                    Log.d(TAG, "启动传输任务: ${transfer.fileName}")
                    
                    // 通知监听器
                    queueListeners.forEach { it.onTransferStarted(transfer) }
                    
                    // 调用传输执行器执行实际传输
                    transferExecutor?.executeTransfer(transfer)
                }
            }
        }
    }
    
    /**
     * 获取活跃传输列表
     */
    fun getActiveTransfers(): List<FileTransferInfo> {
        return activeTransfers.values.toList()
    }
    
    /**
     * 获取队列中的所有传输任务
     */
    fun getAllTransfers(): List<FileTransferInfo> {
        return _transferQueue.value
    }
    
    /**
     * 根据文件名获取传输任务
     */
    fun getTransfer(fileName: String): FileTransferInfo? {
        return _transferQueue.value.find { it.fileName == fileName }
    }
    
    /**
     * 清空传输队列
     */
    fun clearQueue() {
        synchronized(this) {
            // 取消所有活跃传输
            activeTransfers.values.forEach { transfer ->
                transfer.status = TransferStatus.CANCELLED
                transferExecutor?.cancelTransfer(transfer.fileName)
                queueListeners.forEach { it.onTransferCancelled(transfer) }
            }
            
            // 清空队列
            activeTransfers.clear()
            _transferQueue.value = emptyList()
            
            Log.d(TAG, "清空传输队列")
            
            // 通知监听器
            queueListeners.forEach { it.onQueueCleared() }
        }
    }
    
    /**
     * 添加队列监听器
     */
    fun addQueueListener(listener: TransferQueueListener) {
        queueListeners.add(listener)
    }
    
    /**
     * 移除队列监听器
     */
    fun removeQueueListener(listener: TransferQueueListener) {
        queueListeners.remove(listener)
    }
    
    /**
     * 清理资源
     */
    fun cleanup() {
        queueListeners.clear()
        activeTransfers.clear()
        _transferQueue.value = emptyList()
        transferExecutor = null
    }
}

/**
 * 传输队列监听器接口
 */
interface TransferQueueListener {
    fun onTransferAdded(transferInfo: FileTransferInfo)
    fun onTransferRemoved(transferInfo: FileTransferInfo)
    fun onTransferStarted(transferInfo: FileTransferInfo)
    fun onTransferProgress(transferInfo: FileTransferInfo)
    fun onTransferPaused(transferInfo: FileTransferInfo)
    fun onTransferResumed(transferInfo: FileTransferInfo)
    fun onTransferCancelled(transferInfo: FileTransferInfo)
    fun onTransferRetried(transferInfo: FileTransferInfo)
    fun onTransferCompleted(transferInfo: FileTransferInfo)
    fun onTransferFailed(transferInfo: FileTransferInfo, errorMessage: String)
    fun onQueueCleared()
}
