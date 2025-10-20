package com.waveyo.yolighttransfer.network

import android.util.Log
import com.waveyo.yolighttransfer.manager.TransferListener
import com.waveyo.yolighttransfer.model.FileTransferInfo
import com.waveyo.yolighttransfer.model.TransferStatus
import java.io.DataOutputStream
import java.util.concurrent.ConcurrentHashMap

/**
 * 控制帧处理器 - 专门处理TCP控制协议帧
 */
class ControlFrameHandler(
    private val activeTransfers: ConcurrentHashMap<String, FileTransferInfo>,
    private val transferListener: TransferListener?
) {
    
    companion object {
        private const val TAG = "ControlFrameHandler"
    }
    
    /**
     * 处理控制帧
     */
    fun handleControlFrame(frame: ControlFrame, outputStream: DataOutputStream, senderIp: String) {
        try {
            when (frame.op.uppercase()) {
                "PING" -> handlePing(frame, outputStream, senderIp)
                "PAUSE" -> handlePause(frame, outputStream, senderIp)
                "RESUME" -> handleResume(frame, outputStream, senderIp)
                "CANCEL" -> handleCancel(frame, outputStream, senderIp)
                "PROGRESS" -> handleProgress(frame, outputStream, senderIp)
                "ERROR" -> handleError(frame, outputStream, senderIp)
                else -> handleUnknown(frame, outputStream, senderIp)
            }
        } catch (e: Exception) {
            Log.e(TAG, "处理控制帧失败: ${e.message}")
            try {
                // 发送错误响应
                val error = ControlFrame.createError(
                    frame.transferId, 
                    "处理控制帧失败: ${e.message}",
                    "PROCESS_ERROR"
                )
                outputStream.writeUTF(error.toJson())
                outputStream.flush()
            } catch (sendEx: Exception) {
                Log.e(TAG, "发送错误响应失败: ${sendEx.message}")
            }
        }
    }
    
    /**
     * 处理心跳请求
     */
    private fun handlePing(frame: ControlFrame, outputStream: DataOutputStream, senderIp: String) {
        val pong = ControlFrame.createPong(frame.transferId)
        outputStream.writeUTF(pong.toJson())
        outputStream.flush()
        Log.d(TAG, "回复PONG心跳: ${frame.transferId} 来自: $senderIp")
    }
    
    /**
     * 处理暂停请求
     */
    private fun handlePause(frame: ControlFrame, outputStream: DataOutputStream, senderIp: String) {
        val fileName = frame.transferId
        val transferInfo = activeTransfers[fileName]
        if (transferInfo != null) {
            transferInfo.status = TransferStatus.PAUSED
            // 如果 extra 携带进度，更新之
            if (frame.extra is Number) {
                transferInfo.transferredBytes = (frame.extra as Number).toLong()
            }
            transferListener?.onTransferPaused(fileName)
            Log.d(TAG, "收到对端暂停指令: $fileName 来自: $senderIp, 进度: ${transferInfo.transferredBytes}/${transferInfo.fileSize}")
        } else {
            Log.w(TAG, "收到暂停但未找到对应传输: $fileName")
        }
        val ack = ControlFrame.createAck(frame.transferId, "PAUSE")
        outputStream.writeUTF(ack.toJson())
        outputStream.flush()
    }
    
    /**
     * 处理恢复请求
     */
    private fun handleResume(frame: ControlFrame, outputStream: DataOutputStream, senderIp: String) {
        val fileName = frame.transferId
        val transferInfo = activeTransfers[fileName]
        if (transferInfo != null) {
            transferInfo.status = TransferStatus.TRANSFERRING
            // 如果 extra 携带进度，更新之
            if (frame.extra is Number) {
                transferInfo.transferredBytes = (frame.extra as Number).toLong()
            }
            Log.d(TAG, "收到对端恢复指令: $fileName 来自: $senderIp, 进度: ${transferInfo.transferredBytes}/${transferInfo.fileSize}")
            // 这里不主动拉流，等待对端重新发起数据连接
        } else {
            Log.w(TAG, "收到恢复但未找到对应传输: $fileName")
        }
        val ack = ControlFrame.createAck(frame.transferId, "RESUME")
        outputStream.writeUTF(ack.toJson())
        outputStream.flush()
    }
    
    /**
     * 处理取消请求
     */
    private fun handleCancel(frame: ControlFrame, outputStream: DataOutputStream, senderIp: String) {
        val fileName = frame.transferId
        val transferInfo = activeTransfers[fileName]
        if (transferInfo != null) {
            transferInfo.status = TransferStatus.CANCELLED
            transferListener?.onTransferCancelled(fileName)
            activeTransfers.remove(fileName)
            Log.d(TAG, "收到对端取消指令: $fileName 来自: $senderIp, 原因: ${frame.extra}")
        } else {
            Log.w(TAG, "收到取消但未找到对应传输: $fileName")
        }
        val ack = ControlFrame.createAck(frame.transferId, "CANCEL")
        outputStream.writeUTF(ack.toJson())
        outputStream.flush()
    }
    
    /**
     * 处理进度报告
     */
    private fun handleProgress(frame: ControlFrame, outputStream: DataOutputStream, senderIp: String) {
        val fileName = frame.transferId
        val transferInfo = activeTransfers[fileName]
        if (transferInfo != null && frame.extra is Map<*, *>) {
            val extraMap = frame.extra as Map<*, *>
            val transferred = (extraMap["transferred"] as? Number)?.toLong() ?: transferInfo.transferredBytes
            val total = (extraMap["total"] as? Number)?.toLong() ?: transferInfo.fileSize
            
            transferInfo.transferredBytes = transferred
            transferListener?.onProgressUpdated(fileName, transferred, total)
            Log.d(TAG, "收到对端进度报告: $fileName 进度: $transferred/$total 来自: $senderIp")
        }
        val ack = ControlFrame.createAck(frame.transferId, "PROGRESS")
        outputStream.writeUTF(ack.toJson())
        outputStream.flush()
    }
    
    /**
     * 处理错误报告
     */
    private fun handleError(frame: ControlFrame, outputStream: DataOutputStream, senderIp: String) {
        val fileName = frame.transferId
        val transferInfo = activeTransfers[fileName]
        val errorMessage = if (frame.extra is Map<*, *>) {
            val extraMap = frame.extra as Map<*, *>
            "${extraMap["message"]} (${extraMap["code"]})"
        } else {
            frame.extra?.toString() ?: "未知错误"
        }
        
        if (transferInfo != null) {
            transferInfo.status = TransferStatus.FAILED
            transferInfo.errorMessage = errorMessage
            transferListener?.onTransferFailed(fileName, errorMessage)
            activeTransfers.remove(fileName)
            Log.e(TAG, "收到对端错误报告: $fileName 错误: $errorMessage 来自: $senderIp")
        } else {
            Log.w(TAG, "收到错误但未找到对应传输: $fileName, 错误: $errorMessage")
        }
        val ack = ControlFrame.createAck(frame.transferId, "ERROR")
        outputStream.writeUTF(ack.toJson())
        outputStream.flush()
    }
    
    /**
     * 处理未知操作
     */
    private fun handleUnknown(frame: ControlFrame, outputStream: DataOutputStream, senderIp: String) {
        Log.w(TAG, "未知控制操作: ${frame.op}")
        val ack = ControlFrame.createAck(frame.transferId, frame.op)
        outputStream.writeUTF(ack.toJson())
        outputStream.flush()
    }
}
