package com.waveyo.yolighttransfer.network

import android.util.Log
import kotlinx.coroutines.*
import java.io.DataInputStream
import java.io.DataOutputStream
import java.net.ServerSocket
import java.net.Socket

/**
 * 控制服务器 - 专门处理控制帧连接
 */
class ControlServer(
    private val controlFrameHandler: ControlFrameHandler
) {
    
    companion object {
        private const val TAG = "ControlServer"
    }
    
    private var controlServerSocket: ServerSocket? = null
    private var controlServerJob: Job? = null
    private var isRunning = false
    
    /**
     * 启动控制服务器
     */
    fun startControlServer(port: Int) {
        if (isRunning) return
        
        isRunning = true
        controlServerJob = CoroutineScope(Dispatchers.IO).launch {
            try {
                controlServerSocket = ServerSocket(port).apply {
                    reuseAddress = true
                    soTimeout = 0 // 无限等待
                }
                
                Log.d(TAG, "TCP控制服务器启动，监听端口: $port")
                
                while (isRunning) {
                    try {
                        val clientSocket = controlServerSocket?.accept()
                        if (clientSocket != null) {
                            // 为每个控制连接启动独立的协程处理
                            launch {
                                handleControlConnection(clientSocket)
                            }
                        }
                    } catch (e: Exception) {
                        if (isRunning) {
                            Log.e(TAG, "处理控制连接失败: ${e.message}")
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "启动TCP控制服务器失败: ${e.message}")
            } finally {
                controlServerSocket?.close()
                controlServerSocket = null
            }
        }
    }
    
    /**
     * 停止控制服务器
     */
    fun stopControlServer() {
        isRunning = false
        controlServerJob?.cancel()
        controlServerJob = null
        
        try {
            controlServerSocket?.close()
        } catch (e: Exception) {
            Log.e(TAG, "关闭控制服务器socket失败: ${e.message}")
        }
        controlServerSocket = null
    }
    
    /**
     * 处理控制连接
     */
    private suspend fun handleControlConnection(clientSocket: Socket) {
        var inputStream: DataInputStream? = null
        var outputStream: DataOutputStream? = null
        
        try {
            inputStream = DataInputStream(clientSocket.getInputStream())
            outputStream = DataOutputStream(clientSocket.getOutputStream())
            
            // 读取控制帧
            val controlMessage = inputStream.readUTF()
            if (controlMessage.trim().startsWith("{")) {
                try {
                    val frame = ControlFrame.fromJson(controlMessage)
                    controlFrameHandler.handleControlFrame(frame, outputStream, clientSocket.inetAddress.hostAddress ?: "unknown")
                    Log.d(TAG, "处理控制帧成功: ${frame.op} 来自: ${clientSocket.inetAddress.hostAddress}")
                } catch (je: Exception) {
                    Log.e(TAG, "解析控制帧失败: ${je.message}")
                }
            } else {
                Log.w(TAG, "无效的控制帧格式: $controlMessage")
            }
        } catch (e: Exception) {
            Log.e(TAG, "处理控制连接失败: ${e.message}")
        } finally {
            try {
                inputStream?.close()
                outputStream?.close()
                clientSocket.close()
            } catch (e: Exception) {
                Log.e(TAG, "关闭控制连接失败: ${e.message}")
            }
        }
    }
    
    /**
     * 检查控制服务器是否在运行
     */
    fun isRunning(): Boolean = isRunning
}
