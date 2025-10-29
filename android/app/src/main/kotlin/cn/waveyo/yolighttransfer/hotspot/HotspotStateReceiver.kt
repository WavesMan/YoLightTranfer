package cn.waveyo.yolighttransfer.hotspot

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.wifi.WifiManager
import android.os.Build
import android.util.Log

/**
 * WiFi AP 相关常量定义
 * 这些常量在 Android 10+ 中已被废弃或移除，需要手动定义
 */
object WiFiAPConstants {
    // WiFi AP 状态变化广播
    const val WIFI_AP_STATE_CHANGED_ACTION = "android.net.wifi.WIFI_AP_STATE_CHANGED"
    const val ACTION_WIFI_AP_STATE_CHANGED = "android.net.wifi.action.WIFI_AP_STATE_CHANGED"
    
    // WiFi AP 状态
    const val EXTRA_WIFI_AP_STATE = "wifi_state"
    const val EXTRA_PREVIOUS_WIFI_AP_STATE = "previous_wifi_state"
    
    // WiFi AP 状态值
    const val WIFI_AP_STATE_DISABLED = 11
    const val WIFI_AP_STATE_DISABLING = 10
    const val WIFI_AP_STATE_ENABLED = 13
    const val WIFI_AP_STATE_ENABLING = 12
    const val WIFI_AP_STATE_FAILED = 14
}

/**
 * 热点状态广播接收器
 * 监听热点状态变化
 */
class HotspotStateReceiver(private val context: Context) {
    private val TAG = "HotspotStateReceiver"
    private var receiver: BroadcastReceiver? = null
    private var isRegistered = false

    /**
     * 热点状态变化监听器接口
     */
    interface HotspotStateListener {
        fun onHotspotStarted(ssid: String?, password: String?)
        fun onHotspotStopped()
        fun onHotspotError(error: String)
    }

    private var listener: HotspotStateListener? = null

    /**
     * 设置热点状态监听器
     */
    fun setHotspotStateListener(listener: HotspotStateListener) {
        this.listener = listener
    }

    /**
     * 注册广播接收器
     */
    fun register() {
        if (isRegistered) {
            Log.d(TAG, "广播接收器已经注册")
            return
        }

        try {
            receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    handleHotspotStateChange(intent)
                }
            }

            val filter = IntentFilter().apply {
                // WiFi 状态变化
                addAction(WifiManager.WIFI_STATE_CHANGED_ACTION)
                
                // 网络连接状态变化
                addAction(ConnectivityManager.CONNECTIVITY_ACTION)
                
                // 热点状态变化 - 使用手动定义的常量
                if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P) {
                    // Android 9.0 及以下版本使用系统常量
                    try {
                        addAction(WiFiAPConstants.WIFI_AP_STATE_CHANGED_ACTION)
                    } catch (e: Exception) {
                        Log.w(TAG, "WIFI_AP_STATE_CHANGED_ACTION 不可用: ${e.message}")
                    }
                } else {
                    // Android 10+ 使用手动定义的常量
                    addAction(WiFiAPConstants.WIFI_AP_STATE_CHANGED_ACTION)
                    addAction(WiFiAPConstants.ACTION_WIFI_AP_STATE_CHANGED)
                }
            }

            context.registerReceiver(receiver, filter)
            isRegistered = true
            Log.d(TAG, "✅ 热点状态广播接收器注册成功")
        } catch (e: Exception) {
            Log.e(TAG, "❌ 注册热点状态广播接收器失败: ${e.message}")
        }
    }

    /**
     * 注销广播接收器
     */
    fun unregister() {
        if (!isRegistered || receiver == null) {
            Log.d(TAG, "广播接收器未注册或已注销")
            return
        }

        try {
            context.unregisterReceiver(receiver)
            receiver = null
            isRegistered = false
            Log.d(TAG, "✅ 热点状态广播接收器注销成功")
        } catch (e: Exception) {
            Log.e(TAG, "❌ 注销热点状态广播接收器失败: ${e.message}")
        }
    }

    /**
     * 处理热点状态变化
     */
    private fun handleHotspotStateChange(intent: Intent) {
        val action = intent.action ?: return

        Log.d(TAG, "收到广播: $action")

        when (action) {
            WiFiAPConstants.WIFI_AP_STATE_CHANGED_ACTION,
            WiFiAPConstants.ACTION_WIFI_AP_STATE_CHANGED -> {
                handleWifiApStateChange(intent)
            }
            WifiManager.WIFI_STATE_CHANGED_ACTION -> {
                handleWifiStateChange(intent)
            }
            ConnectivityManager.CONNECTIVITY_ACTION -> {
                handleConnectivityChange(intent)
            }
        }
    }

    /**
     * 处理 WiFi AP 状态变化
     */
    private fun handleWifiApStateChange(intent: Intent) {
        try {
            val state = intent.getIntExtra(
                WiFiAPConstants.EXTRA_WIFI_AP_STATE, 
                WiFiAPConstants.WIFI_AP_STATE_DISABLED
            )
            val previousState = intent.getIntExtra(
                WiFiAPConstants.EXTRA_PREVIOUS_WIFI_AP_STATE,
                WiFiAPConstants.WIFI_AP_STATE_DISABLED
            )

            Log.d(TAG, "WiFi AP 状态变化: 前状态=$previousState, 当前状态=$state")

            when (state) {
                WiFiAPConstants.WIFI_AP_STATE_ENABLED -> {
                    Log.d(TAG, "✅ 热点已启用")
                    // 获取热点信息
                    val hotspotInfo = HotspotInfoStorage.getHotspotInfo(context)
                    if (hotspotInfo != null) {
                        listener?.onHotspotStarted(hotspotInfo.first, hotspotInfo.second)
                    } else {
                        listener?.onHotspotStarted(null, null)
                    }
                }
                WiFiAPConstants.WIFI_AP_STATE_DISABLED -> {
                    Log.d(TAG, "❌ 热点已禁用")
                    listener?.onHotspotStopped()
                    HotspotInfoStorage.clearHotspotInfo(context)
                }
                WiFiAPConstants.WIFI_AP_STATE_ENABLING -> {
                    Log.d(TAG, "⏳ 热点正在启用中...")
                }
                WiFiAPConstants.WIFI_AP_STATE_DISABLING -> {
                    Log.d(TAG, "⏳ 热点正在禁用中...")
                }
                WiFiAPConstants.WIFI_AP_STATE_FAILED -> {
                    Log.e(TAG, "❌ 热点启用失败")
                    listener?.onHotspotError("热点启用失败")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "处理 WiFi AP 状态变化异常: ${e.message}")
        }
    }

    /**
     * 处理 WiFi 状态变化
     */
    private fun handleWifiStateChange(intent: Intent) {
        try {
            val state = intent.getIntExtra(
                WifiManager.EXTRA_WIFI_STATE, 
                WifiManager.WIFI_STATE_UNKNOWN
            )

            Log.d(TAG, "WiFi 状态变化: $state")

            when (state) {
                WifiManager.WIFI_STATE_ENABLED -> {
                    Log.d(TAG, "✅ WiFi 已启用")
                }
                WifiManager.WIFI_STATE_DISABLED -> {
                    Log.d(TAG, "❌ WiFi 已禁用")
                }
                WifiManager.WIFI_STATE_ENABLING -> {
                    Log.d(TAG, "⏳ WiFi 正在启用中...")
                }
                WifiManager.WIFI_STATE_DISABLING -> {
                    Log.d(TAG, "⏳ WiFi 正在禁用中...")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "处理 WiFi 状态变化异常: ${e.message}")
        }
    }

    /**
     * 处理网络连接状态变化
     */
    private fun handleConnectivityChange(intent: Intent) {
        try {
            Log.d(TAG, "网络连接状态变化")
            // 这里可以添加网络连接状态变化的处理逻辑
        } catch (e: Exception) {
            Log.e(TAG, "处理网络连接状态变化异常: ${e.message}")
        }
    }

    /**
     * 检查是否正在监听
     */
    fun isListening(): Boolean {
        return isRegistered
    }

    /**
     * 清理资源
     */
    fun dispose() {
        unregister()
        listener = null
        Log.d(TAG, "热点状态接收器已清理")
    }
}
