package com.waveyo.yolighttransfer_flutter.hotspot

import android.content.Context
import android.net.wifi.WifiManager
import android.util.Log

/**
 * 增强热点管理器
 * 整合分层服务架构，提供统一的热点管理接口
 */
class EnhancedHotspotManager(private val context: Context) {
    private val TAG = "EnhancedHotspotManager"
    private val wifiManager: WifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
    private val hotspotService = HotspotServiceFactory.createHotspotService(context)
    private val stateReceiver = HotspotStateReceiver(context)

    /**
     * 热点状态监听器
     */
    interface HotspotStateListener {
        fun onHotspotStarted(ssid: String?, password: String?)
        fun onHotspotStopped()
        fun onHotspotError(error: String)
        fun onHotspotStateChanged(isRunning: Boolean)
    }

    private var listener: HotspotStateListener? = null

    /**
     * 设置热点状态监听器
     */
    fun setHotspotStateListener(listener: HotspotStateListener) {
        this.listener = listener
        
        stateReceiver.setHotspotStateListener(object : HotspotStateReceiver.HotspotStateListener {
            override fun onHotspotStarted(ssid: String?, password: String?) {
                Log.d(TAG, "热点启动回调: SSID=$ssid")
                listener.onHotspotStarted(ssid, password)
                listener.onHotspotStateChanged(true)
            }

            override fun onHotspotStopped() {
                Log.d(TAG, "热点停止回调")
                listener.onHotspotStopped()
                listener.onHotspotStateChanged(false)
            }

            override fun onHotspotError(error: String) {
                Log.e(TAG, "热点错误回调: $error")
                listener.onHotspotError(error)
            }
        })
    }

    /**
     * 启动热点管理
     */
    fun startHotspotManagement() {
        Log.d(TAG, "启动热点管理")
        stateReceiver.register()
    }

    /**
     * 停止热点管理
     */
    fun stopHotspotManagement() {
        Log.d(TAG, "停止热点管理")
        stateReceiver.unregister()
    }

    /**
     * 创建热点 - 分层关闭逻辑
     */
    fun createHotspot(ssid: String, password: String): HotspotResult {
        Log.d(TAG, "创建热点: SSID=$ssid, 密码长度=${password.length}")
        
        return try {
            // 验证参数
            if (ssid.isBlank() || password.isBlank()) {
                return HotspotResult.Error("SSID 和密码不能为空")
            }

            if (password.length < 8) {
                return HotspotResult.Error("密码长度至少需要8位")
            }

            // 检查热点支持
            if (!isHotspotSupported()) {
                return HotspotResult.Error("设备不支持热点功能")
            }

            // 检查当前热点状态
            if (isHotspotRunning()) {
                Log.d(TAG, "热点正在运行，先停止当前热点")
                val stopResult = stopHotspot()
                if (!stopResult) {
                    return HotspotResult.Error("无法停止当前运行的热点")
                }
                // 等待热点完全停止
                Thread.sleep(1000)
            }

            // 使用分层服务创建热点
            val success = hotspotService.startHotspot(ssid, password)
            
            if (success) {
                Log.d(TAG, "✅ 热点创建成功 - 使用 ${hotspotService.getPlatformName()}")
                HotspotResult.Success("热点创建成功")
            } else {
                Log.e(TAG, "❌ 热点创建失败 - 使用 ${hotspotService.getPlatformName()}")
                HotspotResult.Error("热点创建失败")
            }
        } catch (e: Exception) {
            Log.e(TAG, "创建热点异常: ${e.message}")
            HotspotResult.Error("创建热点异常: ${e.message}")
        }
    }

    /**
     * 停止热点 - 分层关闭逻辑
     */
    fun stopHotspot(): Boolean {
        Log.d(TAG, "停止热点 - 分层关闭逻辑")
        
        return try {
            // 使用分层服务停止热点
            val success = hotspotService.stopHotspot()
            
            if (success) {
                Log.d(TAG, "✅ 热点停止成功 - 使用 ${hotspotService.getPlatformName()}")
                // 清理热点信息
                HotspotInfoStorage.clearHotspotInfo(context)
            } else {
                Log.e(TAG, "❌ 热点停止失败 - 使用 ${hotspotService.getPlatformName()}")
            }
            
            success
        } catch (e: Exception) {
            Log.e(TAG, "停止热点异常: ${e.message}")
            false
        }
    }

    /**
     * 强制停止热点 - 使用多种方法确保热点被关闭
     */
    fun forceStopHotspot(): Boolean {
        Log.d(TAG, "强制停止热点")
        
        return try {
            var success = false
            
            // 方法1：使用分层服务停止
            Log.d(TAG, "方法1：使用分层服务停止热点")
            success = hotspotService.stopHotspot()
            
            if (!success) {
                // 方法2：使用 WiFi 管理器断开连接
                Log.d(TAG, "方法2：使用 WiFi 管理器断开连接")
                try {
                    wifiManager.disconnect()
                    success = true
                } catch (e: Exception) {
                    Log.e(TAG, "WiFi 断开连接失败: ${e.message}")
                }
            }
            
            // 清理热点信息
            HotspotInfoStorage.clearHotspotInfo(context)
            
            if (success) {
                Log.d(TAG, "✅ 强制停止热点成功")
            } else {
                Log.e(TAG, "❌ 强制停止热点失败")
            }
            
            success
        } catch (e: Exception) {
            Log.e(TAG, "强制停止热点异常: ${e.message}")
            false
        }
    }

    /**
     * 检查设备是否支持热点
     */
    fun isHotspotSupported(): Boolean {
        return hotspotService.isHotspotSupported()
    }

    /**
     * 检查热点是否正在运行
     */
    fun isHotspotRunning(): Boolean {
        return hotspotService.isHotspotRunning()
    }

    /**
     * 获取平台信息
     */
    fun getPlatformInfo(): String {
        return hotspotService.getPlatformName()
    }

    /**
     * 获取实际热点信息
     */
    fun getActualHotspotInfo(): Pair<String, String>? {
        return HotspotInfoStorage.getHotspotInfo(context)
    }

    /**
     * 清理资源
     */
    fun dispose() {
        Log.d(TAG, "清理增强热点管理器资源")
        stateReceiver.dispose()
        listener = null
    }
}

/**
 * 热点操作结果密封类
 */
sealed class HotspotResult {
    data class Success(val message: String) : HotspotResult()
    data class Error(val message: String) : HotspotResult()
    
    val isSuccess: Boolean
        get() = this is Success
    
    val isError: Boolean
        get() = this is Error
}
