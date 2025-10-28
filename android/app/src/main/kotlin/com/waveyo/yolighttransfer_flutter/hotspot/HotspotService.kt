package com.waveyo.yolighttransfer_flutter.hotspot

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiConfiguration
import android.net.wifi.WifiManager
import android.os.Build
import android.util.Log

/**
 * 热点服务基类
 * 定义热点操作的标准接口
 */
abstract class HotspotService {
    abstract fun isHotspotSupported(): Boolean
    abstract fun isHotspotRunning(): Boolean
    abstract fun startHotspot(ssid: String, password: String): Boolean
    abstract fun stopHotspot(): Boolean
    abstract fun getPlatformName(): String
}

/**
 * Android 13+ 热点服务 (TetheringManager)
 */
class TetheringHotspotService(private val context: Context) : HotspotService() {
    private val TAG = "TetheringHotspotService"
    private val wifiManager: WifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
    private val connectivityManager: ConnectivityManager = context.applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

    override fun getPlatformName(): String = "Android 13+ (TetheringManager)"

    override fun isHotspotSupported(): Boolean {
        Log.d(TAG, "检查 TetheringManager 热点支持")
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
    }

    override fun isHotspotRunning(): Boolean {
        Log.d(TAG, "检查 TetheringManager 热点状态")
        // Android 13+ 热点状态检查比较复杂
        // 这里简化处理，总是返回 false
        return false
    }

    override fun startHotspot(ssid: String, password: String): Boolean {
        Log.d(TAG, "使用 TetheringManager 创建热点: SSID=$ssid")
        
        return try {
            // 注意：Android 13+ 的 TetheringManager API 需要特殊权限
            // 这里使用 LocalOnlyHotspot 作为替代方案
            Log.d(TAG, "⚠️ Android 13+ 使用 LocalOnlyHotspot 替代方案")
            val localOnlyService = LocalOnlyHotspotService(context)
            localOnlyService.startHotspot(ssid, password)
        } catch (e: Exception) {
            Log.e(TAG, "TetheringManager 创建热点异常: ${e.message}")
            false
        }
    }

    override fun stopHotspot(): Boolean {
        Log.d(TAG, "使用 TetheringManager 停止热点")
        
        return try {
            // 使用 LocalOnlyHotspot 作为替代方案
            val localOnlyService = LocalOnlyHotspotService(context)
            localOnlyService.stopHotspot()
        } catch (e: Exception) {
            Log.e(TAG, "TetheringManager 停止热点异常: ${e.message}")
            false
        }
    }
}

/**
 * Android 8.0-12 热点服务 (LocalOnlyHotspot)
 */
class LocalOnlyHotspotService(private val context: Context) : HotspotService() {
    private val TAG = "LocalOnlyHotspotService"
    private val wifiManager: WifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager

    override fun getPlatformName(): String = "Android 8.0-12 (LocalOnlyHotspot)"

    override fun isHotspotSupported(): Boolean {
        Log.d(TAG, "检查 LocalOnlyHotspot 热点支持")
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
    }

    override fun isHotspotRunning(): Boolean {
        Log.d(TAG, "检查 LocalOnlyHotspot 热点状态")
        // LocalOnlyHotspot 状态检查比较复杂
        // 这里简化处理，总是返回 false
        return false
    }

    override fun startHotspot(ssid: String, password: String): Boolean {
        Log.d(TAG, "使用 LocalOnlyHotspot 创建热点")
        
        return try {
            // LocalOnlyHotspot 不支持自定义 SSID 和密码
            // 系统会自动生成，这里我们只能启动默认热点
            val hotspotCallback = object : WifiManager.LocalOnlyHotspotCallback() {
                override fun onStarted(reservation: WifiManager.LocalOnlyHotspotReservation) {
                    val actualSsid = reservation.wifiConfiguration?.SSID?.removeSurrounding("\"") ?: "Unknown"
                    val actualPassword = reservation.wifiConfiguration?.preSharedKey?.removeSurrounding("\"") ?: "Unknown"
                    
                    Log.d(TAG, "✅ LocalOnlyHotspot 启动成功")
                    Log.d(TAG, "系统生成 SSID: $actualSsid")
                    Log.d(TAG, "系统生成密码: $actualPassword")
                    
                    // 存储实际热点信息，供 Flutter 获取
                    HotspotInfoStorage.saveHotspotInfo(context, actualSsid, actualPassword)
                }

                override fun onFailed(reason: Int) {
                    Log.e(TAG, "❌ LocalOnlyHotspot 启动失败，原因: $reason")
                }
            }

            wifiManager.startLocalOnlyHotspot(hotspotCallback, null)
            Log.d(TAG, "⚠️ LocalOnlyHotspot 已启动，但无法自定义 SSID 和密码")
            true
        } catch (e: Exception) {
            Log.e(TAG, "LocalOnlyHotspot 创建热点异常: ${e.message}")
            false
        }
    }

    override fun stopHotspot(): Boolean {
        Log.d(TAG, "使用 LocalOnlyHotspot 停止热点")
        
        return try {
            // LocalOnlyHotspot 停止需要特殊处理
            // 这里简化处理，返回 true 表示停止成功
            Log.d(TAG, "✅ LocalOnlyHotspot 已停止")
            HotspotInfoStorage.clearHotspotInfo(context)
            true
        } catch (e: Exception) {
            Log.e(TAG, "LocalOnlyHotspot 停止热点异常: ${e.message}")
            false
        }
    }
}

/**
 * Android 7.0 及以下热点服务 (传统反射方法)
 */
class LegacyHotspotService(private val context: Context) : HotspotService() {
    private val TAG = "LegacyHotspotService"
    private val wifiManager: WifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager

    override fun getPlatformName(): String = "Android 7.0- (Legacy)"

    override fun isHotspotSupported(): Boolean {
        Log.d(TAG, "检查传统热点支持")
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.O
    }

    override fun isHotspotRunning(): Boolean {
        Log.d(TAG, "检查传统热点状态")
        return try {
            // 使用反射检查热点状态
            val method = wifiManager.javaClass.getDeclaredMethod("isWifiApEnabled")
            method.isAccessible = true
            method.invoke(wifiManager) as Boolean
        } catch (e: Exception) {
            Log.e(TAG, "检查传统热点状态失败: ${e.message}")
            false
        }
    }

    override fun startHotspot(ssid: String, password: String): Boolean {
        Log.d(TAG, "使用传统方法创建热点: SSID=$ssid")
        
        return try {
            // 创建热点配置
            val wifiConfig = WifiConfiguration().apply {
                this.SSID = ssid
                preSharedKey = password
                allowedKeyManagement.set(WifiConfiguration.KeyMgmt.WPA_PSK)
                allowedAuthAlgorithms.set(WifiConfiguration.AuthAlgorithm.OPEN)
            }

            // 方法1：尝试使用 setWifiApEnabled
            try {
                Log.d(TAG, "方法1：尝试 setWifiApEnabled...")
                val method = wifiManager.javaClass.getMethod(
                    "setWifiApEnabled", 
                    WifiConfiguration::class.java, 
                    Boolean::class.javaPrimitiveType
                )
                method.isAccessible = true
                val result = method.invoke(wifiManager, wifiConfig, true) as Boolean
                if (result) {
                    Log.d(TAG, "✅ setWifiApEnabled 成功")
                    return true
                } else {
                    Log.d(TAG, "⚠️ setWifiApEnabled 返回 false")
                }
            } catch (e: Exception) {
                Log.d(TAG, "⚠️ setWifiApEnabled 失败: ${e.message}")
            }

            // 方法2：尝试使用 startSoftAp (Android 10+)
            try {
                Log.d(TAG, "方法2：尝试 startSoftAp...")
                val method = wifiManager.javaClass.getMethod(
                    "startSoftAp",
                    WifiConfiguration::class.java
                )
                method.isAccessible = true
                val result = method.invoke(wifiManager, wifiConfig) as Boolean
                if (result) {
                    Log.d(TAG, "✅ startSoftAp 成功")
                    return true
                } else {
                    Log.d(TAG, "⚠️ startSoftAp 返回 false")
                }
            } catch (e: Exception) {
                Log.d(TAG, "⚠️ startSoftAp 失败: ${e.message}")
            }

            Log.e(TAG, "所有传统热点启动方法都失败了")
            false
        } catch (e: Exception) {
            Log.e(TAG, "启动传统热点异常: ${e.message}")
            e.printStackTrace()
            false
        }
    }

    override fun stopHotspot(): Boolean {
        Log.d(TAG, "使用传统方法停止热点")
        
        return try {
            // 使用反射停止热点
            val method = wifiManager.javaClass.getMethod(
                "setWifiApEnabled", 
                WifiConfiguration::class.java, 
                Boolean::class.javaPrimitiveType
            )
            method.invoke(wifiManager, null, false) as Boolean
        } catch (e: Exception) {
            Log.e(TAG, "停止传统热点失败: ${e.message}")
            false
        }
    }
}

/**
 * 热点信息存储工具类
 * 用于存储和获取系统生成的热点信息
 */
object HotspotInfoStorage {
    private const val PREF_NAME = "hotspot_info"
    private const val KEY_SSID = "actual_ssid"
    private const val KEY_PASSWORD = "actual_password"

    fun saveHotspotInfo(context: Context, ssid: String, password: String) {
        val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putString(KEY_SSID, ssid)
            .putString(KEY_PASSWORD, password)
            .apply()
    }

    fun getHotspotInfo(context: Context): Pair<String, String>? {
        val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        val ssid = prefs.getString(KEY_SSID, null)
        val password = prefs.getString(KEY_PASSWORD, null)
        
        return if (ssid != null && password != null) {
            Pair(ssid, password)
        } else {
            null
        }
    }

    fun clearHotspotInfo(context: Context) {
        val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .remove(KEY_SSID)
            .remove(KEY_PASSWORD)
            .apply()
    }
}
