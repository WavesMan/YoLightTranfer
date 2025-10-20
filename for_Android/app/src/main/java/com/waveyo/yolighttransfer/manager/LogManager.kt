package com.waveyo.yolighttransfer.manager

import android.content.Context
import android.util.Log
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.ConcurrentLinkedQueue

/**
 * 统一日志管理器
 * 提供生产化的日志记录和导出功能
 */
class LogManager(private val context: Context) {
    
    companion object {
        private const val TAG = "LogManager"
        private const val MAX_LOG_ENTRIES = 1000 // 最大日志条目数
        private const val LOG_FILE_NAME = "yolighttransfer_logs.txt"
        
        // 日志级别
        const val LEVEL_VERBOSE = 0
        const val LEVEL_DEBUG = 1
        const val LEVEL_INFO = 2
        const val LEVEL_WARN = 3
        const val LEVEL_ERROR = 4
    }
    
    private val logQueue = ConcurrentLinkedQueue<LogEntry>()
    private val dateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.getDefault())
    private var isEnabled = true // 可以通过注释这行来禁用日志
    
    /**
     * 日志条目
     */
    data class LogEntry(
        val timestamp: Long,
        val level: Int,
        val tag: String,
        val message: String,
        val threadName: String = Thread.currentThread().name
    )
    
    /**
     * 记录Verbose级别日志
     */
    fun v(tag: String, message: String) {
        if (!isEnabled) return
        addLogEntry(LEVEL_VERBOSE, tag, message)
        Log.v(tag, message)
    }
    
    /**
     * 记录Debug级别日志
     */
    fun d(tag: String, message: String) {
        if (!isEnabled) return
        addLogEntry(LEVEL_DEBUG, tag, message)
        Log.d(tag, message)
    }
    
    /**
     * 记录Info级别日志
     */
    fun i(tag: String, message: String) {
        if (!isEnabled) return
        addLogEntry(LEVEL_INFO, tag, message)
        Log.i(tag, message)
    }
    
    /**
     * 记录Warn级别日志
     */
    fun w(tag: String, message: String) {
        if (!isEnabled) return
        addLogEntry(LEVEL_WARN, tag, message)
        Log.w(tag, message)
    }
    
    /**
     * 记录Error级别日志
     */
    fun e(tag: String, message: String) {
        if (!isEnabled) return
        addLogEntry(LEVEL_ERROR, tag, message)
        Log.e(tag, message)
    }
    
    /**
     * 记录Error级别日志（带异常）
     */
    fun e(tag: String, message: String, throwable: Throwable) {
        if (!isEnabled) return
        val fullMessage = "$message\n${throwable.stackTraceToString()}"
        addLogEntry(LEVEL_ERROR, tag, fullMessage)
        Log.e(tag, message, throwable)
    }
    
    /**
     * 添加日志条目到队列
     */
    private fun addLogEntry(level: Int, tag: String, message: String) {
        val entry = LogEntry(
            timestamp = System.currentTimeMillis(),
            level = level,
            tag = tag,
            message = message
        )
        
        logQueue.add(entry)
        
        // 限制队列大小
        while (logQueue.size > MAX_LOG_ENTRIES) {
            logQueue.poll()
        }
    }
    
    /**
     * 获取日志级别名称
     */
    private fun getLevelName(level: Int): String {
        return when (level) {
            LEVEL_VERBOSE -> "VERBOSE"
            LEVEL_DEBUG -> "DEBUG"
            LEVEL_INFO -> "INFO"
            LEVEL_WARN -> "WARN"
            LEVEL_ERROR -> "ERROR"
            else -> "UNKNOWN"
        }
    }
    
    /**
     * 导出日志到文件
     */
    fun exportLogs(): File? {
        if (!isEnabled) return null
        
        return try {
            val logFile = File(context.filesDir, LOG_FILE_NAME)
            FileOutputStream(logFile).use { outputStream ->
                // 写入日志头
                val header = """
                    |YoLightTransfer 日志文件
                    |导出时间: ${dateFormat.format(Date())}
                    |设备信息: ${getDeviceInfo()}
                    |========================================
                    |
                """.trimMargin()
                outputStream.write(header.toByteArray())
                
                // 写入所有日志条目
                logQueue.forEach { entry ->
                    val logLine = formatLogEntry(entry) + "\n"
                    outputStream.write(logLine.toByteArray())
                }
                
                // 写入日志尾
                val footer = """
                    |
                    |========================================
                    |日志总数: ${logQueue.size}
                    |导出完成
                """.trimMargin()
                outputStream.write(footer.toByteArray())
            }
            
            Log.i(TAG, "日志导出完成: ${logFile.absolutePath}")
            logFile
        } catch (e: Exception) {
            Log.e(TAG, "导出日志失败", e)
            null
        }
    }
    
    /**
     * 格式化日志条目
     */
    private fun formatLogEntry(entry: LogEntry): String {
        val time = dateFormat.format(Date(entry.timestamp))
        val level = getLevelName(entry.level)
        return "[$time] [$level] [${entry.threadName}] [${entry.tag}] ${entry.message}"
    }
    
    /**
     * 获取设备信息
     */
    private fun getDeviceInfo(): String {
        return try {
            val packageInfo = context.packageManager.getPackageInfo(context.packageName, 0)
            "Android ${android.os.Build.VERSION.RELEASE} | App v${packageInfo.versionName}"
        } catch (e: Exception) {
            "Unknown Device"
        }
    }
    
    /**
     * 清除所有日志
     */
    fun clearLogs() {
        logQueue.clear()
        Log.i(TAG, "日志已清除")
    }
    
    /**
     * 获取当前日志数量
     */
    fun getLogCount(): Int {
        return logQueue.size
    }
    
    /**
     * 获取日志统计信息
     */
    fun getLogStats(): String {
        val stats = mutableMapOf<Int, Int>()
        logQueue.forEach { entry ->
            stats[entry.level] = stats.getOrDefault(entry.level, 0) + 1
        }
        
        return """
            日志统计:
            - 总条目数: ${getLogCount()}
            - VERBOSE: ${stats[LEVEL_VERBOSE] ?: 0}
            - DEBUG: ${stats[LEVEL_DEBUG] ?: 0}
            - INFO: ${stats[LEVEL_INFO] ?: 0}
            - WARN: ${stats[LEVEL_WARN] ?: 0}
            - ERROR: ${stats[LEVEL_ERROR] ?: 0}
        """.trimIndent()
    }
    
    /**
     * 启用/禁用日志记录
     */
    fun setEnabled(enabled: Boolean) {
        isEnabled = enabled
        Log.i(TAG, "日志记录已${if (enabled) "启用" else "禁用"}")
    }
    
    /**
     * 检查日志是否启用
     */
    fun isLoggingEnabled(): Boolean {
        return isEnabled
    }
}
