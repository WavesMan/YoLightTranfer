package com.waveyo.yolighttransfer.network

import android.content.Context
import android.util.Log
import com.waveyo.yolighttransfer.manager.TransferListener
import com.waveyo.yolighttransfer.model.FileTransferInfo
import kotlinx.coroutines.*
import java.io.DataInputStream
import java.io.DataOutputStream
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.ConcurrentHashMap

/**
 * TCP服务器 - 接收文件
 * 使用模块化架构，分离控制流和数据流
 */
class TCPServer(private val context: Context) {
    
    companion object {
        private const val TAG = "TCPServer"
        private const val CONTROL_PORT_OFFSET = 1000 // 控制端口偏移量，数据端口+1000
    }
    
    private var dataServerSocket: ServerSocket? = null
    private var dataServerJob: Job? = null
    private var isRunning = false
    
    // 传输监听器
    var transferListener: TransferListener? = null
    
    // 文件接收确认回调
    var onFileReceiveRequest: ((String, String, Long, (Boolean) -> Unit) -> Unit)? = null
    
    // 正在进行的传输任务
    private val activeTransfers = ConcurrentHashMap<String, FileTransferInfo>()
    
    // 模块化组件
    private lateinit var controlFrameHandler: ControlFrameHandler
    private lateinit var fileReceiver: FileReceiver
    private lateinit var controlServer: ControlServer
    
    /**
     * 启动TCP服务器
     */
    fun startServer(port: Int = com.waveyo.yolighttransfer.manager.ConfigManager(context).getTcpPort()) {
        if (isRunning) return
        
        isRunning = true
        
        // 初始化模块化组件
        controlFrameHandler = ControlFrameHandler(activeTransfers, transferListener)
        fileReceiver = FileReceiver(context, activeTransfers, transferListener, onFileReceiveRequest)
        controlServer = ControlServer(controlFrameHandler)
        
        // 启动数据端口监听
        startDataServer(port)
        
        // 启动控制端口监听
        val controlPort = port + CONTROL_PORT_OFFSET
        controlServer.startControlServer(controlPort)
        
        Log.d(TAG, "TCP服务器启动完成 - 数据端口: $port, 控制端口: $controlPort")
    }
    
    /**
     * 启动数据服务器
     */
    private fun startDataServer(port: Int) {
        dataServerJob = CoroutineScope(Dispatchers.IO).launch {
            try {
                dataServerSocket = ServerSocket(port).apply {
                    reuseAddress = true
                    soTimeout = 0 // 无限等待
                }
                
                Log.d(TAG, "TCP数据服务器启动，监听端口: $port")
                
                while (isRunning) {
                    try {
                        val clientSocket = dataServerSocket?.accept()
                        if (clientSocket != null) {
                            // 为每个客户端连接启动独立的协程处理
                            launch {
                                handleDataConnection(clientSocket)
                            }
                        }
                    } catch (e: Exception) {
                        if (isRunning) {
                            Log.e(TAG, "处理数据连接失败: ${e.message}")
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "启动TCP数据服务器失败: ${e.message}")
                isRunning = false
            } finally {
                dataServerSocket?.close()
                dataServerSocket = null
            }
        }
    }
    
    /**
     * 处理数据连接
     */
    private suspend fun handleDataConnection(clientSocket: Socket) {
        var inputStream: DataInputStream? = null
        var outputStream: DataOutputStream? = null
        
        try {
            inputStream = DataInputStream(clientSocket.getInputStream())
            outputStream = DataOutputStream(clientSocket.getOutputStream())
            
            // 检查是否是控制消息（JSON字符串）
            val firstMessage = inputStream.readUTF()
            if (firstMessage.trim().startsWith("{")) {
                try {
                    val frame = ControlFrame.fromJson(firstMessage)
                    controlFrameHandler.handleControlFrame(frame, outputStream, clientSocket.inetAddress.hostAddress ?: "unknown")
                } catch (je: Exception) {
                    Log.e(TAG, "解析控制帧失败: ${je.message}")
                }
                return
            }
            
            // 如果是文件传输请求，交给FileReceiver处理
            fileReceiver.handleFileTransfer(clientSocket)
            
        } catch (e: Exception) {
            Log.e(TAG, "处理数据连接失败: ${e.message}")
        } finally {
            try {
                inputStream?.close()
                outputStream?.close()
                clientSocket.close()
            } catch (e: Exception) {
                Log.e(TAG, "关闭数据连接失败: ${e.message}")
            }
        }
    }
    
    /**
     * 停止TCP服务器
     */
    fun stopServer() {
        isRunning = false
        
        // 停止数据服务器
        dataServerJob?.cancel()
        dataServerJob = null
        
        try {
            dataServerSocket?.close()
        } catch (e: Exception) {
            Log.e(TAG, "关闭数据服务器socket失败: ${e.message}")
        }
        dataServerSocket = null
        
        // 停止控制服务器
        controlServer.stopControlServer()
        
        Log.d(TAG, "TCP服务器已停止")
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
        stopServer()
        activeTransfers.clear()
    }
    
    /**
     * 检查服务器是否在运行
     */
    fun isRunning(): Boolean = isRunning
}
