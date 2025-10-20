package com.waveyo.yolighttransfer.manager

import android.util.Log
import com.waveyo.yolighttransfer.model.FileTransferInfo
import com.waveyo.yolighttransfer.model.TransferStatus
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * 进度管理器
 * 单一事实源：所有传输任务及其进度统一由此管理，并以不可变列表流式暴露
 */
class ProgressManager {

    companion object {
        private const val TAG = "ProgressManager"
    }

    // 只暴露不可变的任务和进度列表
    private val _allTransfers = MutableStateFlow<List<FileTransferInfo>>(emptyList())
    val allTransfers: StateFlow<List<FileTransferInfo>> = _allTransfers.asStateFlow()

    // 进度监听器列表（可选，用于与旧代码兼容的事件回调）
    private val progressListeners = mutableListOf<ProgressListener>()

    /**
     * 注册/更新传输任务（按文件名去重）
     */
    fun registerTransfer(transferInfo: FileTransferInfo) {
        synchronized(this) {
            val list = _allTransfers.value
            val exists = list.any { it.fileName == transferInfo.fileName }
            _allTransfers.value = if (exists) {
                list.map { if (it.fileName == transferInfo.fileName) transferInfo.copy() else it }
            } else {
                list + transferInfo.copy()
            }
            Log.d(TAG, "注册/更新传输任务: ${transferInfo.fileName}, 状态: ${transferInfo.status}")
            // 事件回调给监听器（传递新的副本）
            progressListeners.forEach { it.onTransferRegistered(transferInfo.copy()) }
        }
    }

    /**
     * 更新传输进度（重建列表与对象，确保不可变）
     */
    fun updateProgress(fileName: String, transferredBytes: Long, fileSize: Long) {
        synchronized(this) {
            var updatedInfo: FileTransferInfo? = null
            _allTransfers.value = _allTransfers.value.map { current ->
                if (current.fileName == fileName) {
                    val progress = if (fileSize == 0L) 0f else (transferredBytes / fileSize.toFloat()).coerceIn(0f, 1f)
                    val newStatus = when (current.status) {
                        TransferStatus.PAUSED, TransferStatus.CANCELLED, TransferStatus.COMPLETED, TransferStatus.FAILED -> current.status
                        else -> TransferStatus.TRANSFERRING
                    }
                    val copy = current.copy(
                        transferredBytes = transferredBytes,
                        progress = progress,
                        status = newStatus
                    )
                    updatedInfo = copy
                    copy
                } else current
            }
            updatedInfo?.let { info ->
                Log.d(TAG, "更新传输进度: $fileName, 进度: ${info.transferredBytes}/$fileSize (${(info.progress * 100).toInt()}%)")
                progressListeners.forEach { it.onProgressUpdated(info) }
            } ?: Log.w(TAG, "找不到传输任务: $fileName")
        }
    }

    /** 标记传输完成 */
    fun markTransferCompleted(fileName: String) {
        synchronized(this) {
            var completed: FileTransferInfo? = null
            _allTransfers.value = _allTransfers.value.map { current ->
                if (current.fileName == fileName) {
                    val copy = current.copy(
                        status = TransferStatus.COMPLETED,
                        transferredBytes = current.fileSize,
                        progress = if (current.fileSize == 0L) 0f else 1f,
                        errorMessage = null
                    )
                    completed = copy
                    copy
                } else current
            }
            completed?.let {
                Log.d(TAG, "标记传输完成: $fileName")
                progressListeners.forEach { l -> l.onTransferCompleted(it) }
            }
        }
    }

    /** 标记传输失败 */
    fun markTransferFailed(fileName: String, errorMessage: String) {
        synchronized(this) {
            var failed: FileTransferInfo? = null
            _allTransfers.value = _allTransfers.value.map { current ->
                if (current.fileName == fileName) {
                    val copy = current.copy(status = TransferStatus.FAILED, errorMessage = errorMessage)
                    failed = copy
                    copy
                } else current
            }
            failed?.let {
                Log.e(TAG, "标记传输失败: $fileName, 错误: $errorMessage")
                progressListeners.forEach { l -> l.onTransferFailed(it, errorMessage) }
            }
        }
    }

    /** 标记传输暂停 */
    fun markTransferPaused(fileName: String) {
        synchronized(this) {
            var paused: FileTransferInfo? = null
            _allTransfers.value = _allTransfers.value.map { current ->
                if (current.fileName == fileName) {
                    val copy = current.copy(status = TransferStatus.PAUSED)
                    paused = copy
                    copy
                } else current
            }
            paused?.let {
                Log.d(TAG, "标记传输暂停: $fileName")
                progressListeners.forEach { l -> l.onTransferPaused(it) }
            }
        }
    }

    /** 标记传输取消 */
    fun markTransferCancelled(fileName: String) {
        synchronized(this) {
            var cancelled: FileTransferInfo? = null
            _allTransfers.value = _allTransfers.value.map { current ->
                if (current.fileName == fileName) {
                    val copy = current.copy(status = TransferStatus.CANCELLED)
                    cancelled = copy
                    copy
                } else current
            }
            cancelled?.let {
                Log.d(TAG, "标记传输取消: $fileName")
                progressListeners.forEach { l -> l.onTransferCancelled(it) }
            }
        }
    }

    /** 获取传输任务 */
    fun getTransfer(fileName: String): FileTransferInfo? = _allTransfers.value.find { it.fileName == fileName }

    /** 获取所有传输任务 */
    fun getAllTransfers(): List<FileTransferInfo> = _allTransfers.value

    /** 获取活跃传输任务 */
    fun getActiveTransfers(): List<FileTransferInfo> = _allTransfers.value.filter {
        it.status == TransferStatus.TRANSFERRING || it.status == TransferStatus.PENDING || it.status == TransferStatus.PENDING_RECEIVE
    }

    /** 移除传输任务 */
    fun removeTransfer(fileName: String) {
        synchronized(this) {
            val toRemove = _allTransfers.value.find { it.fileName == fileName }
            if (toRemove != null) {
                _allTransfers.value = _allTransfers.value.filterNot { it.fileName == fileName }
                Log.d(TAG, "移除传输任务: $fileName")
                progressListeners.forEach { it.onTransferRemoved(toRemove) }
            }
        }
    }

    /** 清空所有传输任务 */
    fun clearAllTransfers() {
        synchronized(this) {
            val old = _allTransfers.value
            _allTransfers.value = emptyList()
            Log.d(TAG, "清空所有传输任务")
            old.forEach { transferInfo ->
                progressListeners.forEach { it.onTransferRemoved(transferInfo) }
            }
        }
    }

    /** 监听器维护 */
    fun addProgressListener(listener: ProgressListener) { progressListeners.add(listener) }
    fun removeProgressListener(listener: ProgressListener) { progressListeners.remove(listener) }

    /** 资源清理 */
    fun cleanup() {
        progressListeners.clear()
        _allTransfers.value = emptyList()
    }
}

/**
 * 进度监听器接口
 */
interface ProgressListener {
    fun onTransferRegistered(transferInfo: FileTransferInfo)
    fun onProgressUpdated(transferInfo: FileTransferInfo)
    fun onTransferCompleted(transferInfo: FileTransferInfo)
    fun onTransferFailed(transferInfo: FileTransferInfo, errorMessage: String)
    fun onTransferPaused(transferInfo: FileTransferInfo)
    fun onTransferCancelled(transferInfo: FileTransferInfo)
    fun onTransferRemoved(transferInfo: FileTransferInfo)
}
