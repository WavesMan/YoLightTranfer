package com.waveyo.yolighttransfer.model

import android.os.Parcelable
import kotlinx.parcelize.Parcelize

/**
 * 文件传输信息
 */
@Parcelize
data class FileTransferInfo(
    val fileName: String,
    val fileSize: Long,
    val filePath: String,
    val targetDevice: DeviceInfo,
    var transferredBytes: Long = 0,
    var status: TransferStatus = TransferStatus.PENDING,
    var progress: Float = 0f,
    var errorMessage: String? = null,
    val startTime: Long = System.currentTimeMillis(),
    var estimatedTimeRemaining: Long = 0
) : Parcelable {
    
    /**
     * 更新传输进度
     */
    fun updateProgress(bytesTransferred: Long) {
        transferredBytes = bytesTransferred
        progress = if (fileSize > 0) {
            (bytesTransferred.toFloat() / fileSize.toFloat()).coerceIn(0f, 1f)
        } else {
            0f
        }
        
        // 计算预估剩余时间
        val elapsedTime = System.currentTimeMillis() - startTime
        if (progress > 0 && elapsedTime > 0) {
            val totalEstimatedTime = (elapsedTime / progress).toLong()
            estimatedTimeRemaining = (totalEstimatedTime - elapsedTime).coerceAtLeast(0)
        }
    }
    
    /**
     * 获取传输速度（KB/s）
     */
    fun getTransferSpeed(): Float {
        val elapsedTime = (System.currentTimeMillis() - startTime) / 1000f
        return if (elapsedTime > 0) {
            (transferredBytes / 1024f) / elapsedTime
        } else {
            0f
        }
    }
}

/**
 * 传输状态枚举
 */
enum class TransferStatus {
    PENDING,          // 等待中
    PENDING_RECEIVE,  // 等待接收确认
    TRANSFERRING,     // 传输中
    PAUSED,           // 已暂停
    COMPLETED,        // 已完成
    FAILED,           // 失败
    CANCELLED,        // 已取消
    REJECTED          // 已拒绝
}

/**
 * 传输分片信息
 */
data class FileChunk(
    val fileName: String,
    val chunkIndex: Int,
    val totalChunks: Int,
    val chunkData: ByteArray,
    val offset: Long,
    val chunkSize: Int
) {
    
    companion object {
        const val CHUNK_SIZE = 1024 * 1024 // 1MB分片大小
    }
    
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false
        
        other as FileChunk
        
        if (fileName != other.fileName) return false
        if (chunkIndex != other.chunkIndex) return false
        if (totalChunks != other.totalChunks) return false
        if (offset != other.offset) return false
        if (chunkSize != other.chunkSize) return false
        if (!chunkData.contentEquals(other.chunkData)) return false
        
        return true
    }
    
    override fun hashCode(): Int {
        var result = fileName.hashCode()
        result = 31 * result + chunkIndex
        result = 31 * result + totalChunks
        result = 31 * result + chunkData.contentHashCode()
        result = 31 * result + offset.hashCode()
        result = 31 * result + chunkSize
        return result
    }
}
