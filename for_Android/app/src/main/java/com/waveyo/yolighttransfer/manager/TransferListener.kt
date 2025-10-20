package com.waveyo.yolighttransfer.manager

import com.waveyo.yolighttransfer.model.FileTransferInfo

/**
 * 传输监听器接口
 * 标准化传输监听接口，支持多种传输协议的扩展
 */
interface TransferListener {
    
    /**
     * 传输进度更新
     * @param fileName 文件名
     * @param transferredBytes 已传输字节数
     * @param fileSize 文件总大小
     */
    fun onProgressUpdated(fileName: String, transferredBytes: Long, fileSize: Long)
    
    /**
     * 传输完成
     * @param fileName 文件名
     */
    fun onTransferCompleted(fileName: String)
    
    /**
     * 传输失败
     * @param fileName 文件名
     * @param errorMessage 错误信息
     */
    fun onTransferFailed(fileName: String, errorMessage: String)
    
    
    /**
     * 传输取消
     * @param fileName 文件名
     */
    fun onTransferCancelled(fileName: String)
    
    /**
     * 传输开始
     * @param transferInfo 传输信息
     */
    fun onTransferStarted(transferInfo: FileTransferInfo)
}

/**
 * 抽象传输监听器基类
 * 提供默认实现，方便子类选择性重写方法
 */
abstract class AbstractTransferListener : TransferListener {
    override fun onProgressUpdated(fileName: String, transferredBytes: Long, fileSize: Long) {}
    override fun onTransferCompleted(fileName: String) {}
    override fun onTransferFailed(fileName: String, errorMessage: String) {}
    override fun onTransferCancelled(fileName: String) {}
    override fun onTransferStarted(transferInfo: FileTransferInfo) {}
}

/**
 * 进度管理器传输监听器
 * 将传输事件转发给进度管理器
 */
class ProgressManagerTransferListener(
    private val progressManager: ProgressManager
) : AbstractTransferListener() {
    
    override fun onProgressUpdated(fileName: String, transferredBytes: Long, fileSize: Long) {
        progressManager.updateProgress(fileName, transferredBytes, fileSize)
    }
    
    override fun onTransferCompleted(fileName: String) {
        progressManager.markTransferCompleted(fileName)
    }
    
    override fun onTransferFailed(fileName: String, errorMessage: String) {
        progressManager.markTransferFailed(fileName, errorMessage)
    }
    
    
    override fun onTransferCancelled(fileName: String) {
        progressManager.markTransferCancelled(fileName)
    }
    
    override fun onTransferStarted(transferInfo: FileTransferInfo) {
        progressManager.registerTransfer(transferInfo)
    }
}

/**
 * 传输队列管理器传输监听器
 * 将传输事件转发给传输队列管理器
 */
class TransferQueueManagerListener(
    private val transferQueueManager: TransferQueueManager
) : AbstractTransferListener() {
    
    override fun onProgressUpdated(fileName: String, transferredBytes: Long, fileSize: Long) {
        transferQueueManager.updateTransferProgress(fileName, transferredBytes, fileSize)
    }
    
    override fun onTransferCompleted(fileName: String) {
        transferQueueManager.markTransferCompleted(fileName)
    }
    
    override fun onTransferFailed(fileName: String, errorMessage: String) {
        transferQueueManager.markTransferFailed(fileName, errorMessage)
    }
    
    
    override fun onTransferCancelled(fileName: String) {
        transferQueueManager.cancelTransfer(fileName)
    }
    
    override fun onTransferStarted(transferInfo: FileTransferInfo) {
        // 传输队列管理器已经有传输开始管理
    }
}

/**
 * 组合传输监听器
 * 将事件转发给多个监听器
 */
class CompositeTransferListener : TransferListener {
    
    private val listeners = mutableListOf<TransferListener>()
    
    fun addListener(listener: TransferListener) {
        listeners.add(listener)
    }
    
    fun removeListener(listener: TransferListener) {
        listeners.remove(listener)
    }
    
    override fun onProgressUpdated(fileName: String, transferredBytes: Long, fileSize: Long) {
        listeners.forEach { it.onProgressUpdated(fileName, transferredBytes, fileSize) }
    }
    
    override fun onTransferCompleted(fileName: String) {
        listeners.forEach { it.onTransferCompleted(fileName) }
    }
    
    override fun onTransferFailed(fileName: String, errorMessage: String) {
        listeners.forEach { it.onTransferFailed(fileName, errorMessage) }
    }
    
    
    override fun onTransferCancelled(fileName: String) {
        listeners.forEach { it.onTransferCancelled(fileName) }
    }
    
    override fun onTransferStarted(transferInfo: FileTransferInfo) {
        listeners.forEach { it.onTransferStarted(transferInfo) }
    }
}
