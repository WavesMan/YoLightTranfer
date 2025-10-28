package com.waveyo.yolighttransfer_flutter

import android.annotation.SuppressLint
import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.MethodChannel

class HotspotManager(private val context: Context) {
    private val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
    private val connectivityManager = context.applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

    // 保存热点预留对象，用于停止热点
    private var hotspotReservation: WifiManager.LocalOnlyHotspotReservation? = null

    companion object {
        private const val TAG = "HotspotManager"
    }

    /**
     * 创建热点 - 简化实现，仅支持LocalOnlyHotspot
     * 注意：无法自定义SSID和密码，系统会自动生成
     */
    @SuppressLint("MissingPermission")
    fun startHotspot(ssid: String, password: String): Boolean {
        return try {
            Log.d(TAG, "开始创建热点: SSID=$ssid, 密码长度=${password.length}")

            // 检查Android版本
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                Log.e(TAG, "不支持Android 8.0以下版本")
                return false
            }

            // 检查WiFi是否启用
            if (!wifiManager.isWifiEnabled) {
                Log.d(TAG, "WiFi未启用，正在启用WiFi...")
                wifiManager.isWifiEnabled = true
                Thread.sleep(1000)
            }

            Log.w(TAG, "LocalOnlyHotspot无法自定义SSID和密码，将使用系统生成的配置")

            // 创建热点
            @Suppress("DEPRECATION")
            wifiManager.startLocalOnlyHotspot(object : WifiManager.LocalOnlyHotspotCallback() {
                override fun onStarted(reservation: WifiManager.LocalOnlyHotspotReservation) {
                    Log.d(TAG, "✅ 热点启动成功")
                    val config = reservation.softApConfiguration
                    val actualSsid = config?.ssid
                    val actualPassword = config?.passphrase
                    Log.d(TAG, "系统生成的热点SSID: $actualSsid")
                    Log.d(TAG, "系统生成的热点密码: $actualPassword")
                    hotspotReservation = reservation
                }

                override fun onStopped() {
                    Log.d(TAG, "热点已停止")
                    hotspotReservation = null
                }

                override fun onFailed(reason: Int) {
                    Log.e(TAG, "❌ 热点启动失败，原因代码: $reason")
                    when (reason) {
                        WifiManager.LocalOnlyHotspotCallback.ERROR_GENERIC -> Log.e(TAG, "原因: 通用错误")
                        WifiManager.LocalOnlyHotspotCallback.ERROR_INCOMPATIBLE_MODE -> Log.e(TAG, "原因: 不兼容的模式")
                        WifiManager.LocalOnlyHotspotCallback.ERROR_TETHERING_DISALLOWED -> Log.e(TAG, "原因: 不允许共享网络")
                        WifiManager.LocalOnlyHotspotCallback.ERROR_NO_CHANNEL -> Log.e(TAG, "原因: 没有可用信道")
                    }
                    hotspotReservation = null
                }
            }, null)

            Log.d(TAG, "热点创建请求已发送")
            true
        } catch (e: Exception) {
            Log.e(TAG, "创建热点失败: ${e.message}", e)
            e.printStackTrace()
            false
        }
    }

    /**
     * 停止热点
     */
    fun stopHotspot(): Boolean {
        return try {
            Log.d(TAG, "停止热点...")
            
            if (hotspotReservation != null) {
                hotspotReservation?.close()
                hotspotReservation = null
                Log.d(TAG, "✅ 热点已停止")
                true
            } else {
                Log.d(TAG, "没有活跃的热点")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "停止热点失败: ${e.message}", e)
            false
        }
    }

    /**
     * 检查热点是否支持
     */
    fun isHotspotSupported(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                Log.d(TAG, "热点不支持: Android版本低于8.0")
                return false
            }
            val supported = wifiManager.isWifiEnabled
            Log.d(TAG, "热点支持: $supported")
            supported
        } catch (e: Exception) {
            Log.e(TAG, "检查热点支持失败: ${e.message}", e)
            false
        }
    }

    /**
     * 检查热点是否运行
     */
    @SuppressLint("MissingPermission")
    fun isHotspotRunning(): Boolean {
        return try {
            val running = hotspotReservation != null
            Log.d(TAG, "热点运行状态: $running")
            running
        } catch (e: Exception) {
            Log.e(TAG, "检查热点运行状态失败: ${e.message}", e)
            false
        }
    }

    /**
     * 获取实际热点信息
     */
    @SuppressLint("MissingPermission")
    fun getActualHotspotInfo(): Map<String, Any?>? {
        return try {
            if (hotspotReservation == null) {
                Log.d(TAG, "没有活跃的热点")
                return null
            }

            val config = hotspotReservation?.softApConfiguration
            if (config != null) {
                val info = mutableMapOf<String, Any?>()
                info["ssid"] = config.ssid
                info["password"] = config.passphrase
                info["securityType"] = config.securityType
                
                Log.d(TAG, "热点信息: $info")
                info
            } else {
                Log.d(TAG, "无法获取热点配置")
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "获取热点信息失败: ${e.message}", e)
            null
        }
    }

    /**
     * 连接到WiFi网络 - 仅支持Android 10+
     */
    @SuppressLint("MissingPermission")
    fun connectToWifi(ssid: String, password: String, encryptionType: String, result: MethodChannel.Result) {
        try {
            Log.d(TAG, "开始连接WiFi: SSID=$ssid, 加密类型=$encryptionType")

            // 检查Android版本
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                Log.e(TAG, "不支持Android 10以下版本")
                result.error("UNSUPPORTED_VERSION", "仅支持Android 10及以上版本", null)
                return
            }

            // 检查WiFi是否启用
            if (!wifiManager.isWifiEnabled) {
                Log.w(TAG, "⚠️ WiFi未启用，无法连接热点")
                Log.w(TAG, "请用户手动开启WiFi后再尝试连接")
                result.error("WIFI_DISABLED", "WiFi未启用，请先开启WiFi", mapOf(
                    "ssid" to ssid,
                    "action" to "enable_wifi"
                ))
                return
            }

            // 检查WiFi状态是否稳定
            if (!isWifiStable()) {
                Log.w(TAG, "⚠️ WiFi状态不稳定，等待WiFi稳定")
                Thread.sleep(2000)
                
                // 再次检查WiFi状态
                if (!wifiManager.isWifiEnabled) {
                    Log.e(TAG, "❌ WiFi仍然未启用")
                    result.error("WIFI_DISABLED", "WiFi未启用，请先开启WiFi", mapOf(
                        "ssid" to ssid,
                        "action" to "enable_wifi"
                    ))
                    return
                }
            }

            Log.d(TAG, "✅ WiFi已启用，开始连接...")
            connectWithNetworkSpecifier(ssid, password, encryptionType, result)
        } catch (e: Exception) {
            Log.e(TAG, "连接WiFi时发生异常: ${e.message}", e)
            result.error("CONNECTION_FAILED", "连接失败: ${e.message}", null)
        }
    }

    /**
     * 使用WifiNetworkSpecifier连接WiFi (Android 10+)
     */
    @SuppressLint("MissingPermission")
    private fun connectWithNetworkSpecifier(ssid: String, password: String, encryptionType: String, result: MethodChannel.Result) {
        // 添加状态标志来防止重复响应
        var resultSent = false
        
        try {
            Log.d(TAG, "使用WifiNetworkSpecifier连接WiFi")
            Log.d(TAG, "SSID: $ssid")
            Log.d(TAG, "加密类型: $encryptionType")

            // 构建网络规范
            val specifierBuilder = WifiNetworkSpecifier.Builder()
                .setSsid(ssid)

            // 根据加密类型设置密码
            when (encryptionType.uppercase()) {
                "WPA", "WPA2", "WPA3" -> {
                    Log.d(TAG, "使用WPA2密码")
                    specifierBuilder.setWpa2Passphrase(password)
                }
                "NONE", "OPEN" -> {
                    Log.d(TAG, "开放网络，不需要密码")
                }
                else -> {
                    Log.d(TAG, "未知加密类型，默认使用WPA2")
                    specifierBuilder.setWpa2Passphrase(password)
                }
            }

            val specifier = specifierBuilder.build()
            Log.d(TAG, "网络规范构建成功")

            // 构建网络请求
            val networkRequest = NetworkRequest.Builder()
                .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                .setNetworkSpecifier(specifier)
                .build()

            Log.d(TAG, "网络请求构建成功，准备请求连接")

            // 注册网络回调
            val networkCallback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    Log.d(TAG, "✅ WiFi连接成功: $ssid")
                    try {
                        connectivityManager.bindProcessToNetwork(network)
                        Log.d(TAG, "进程已绑定到网络")
                        if (!resultSent) {
                            result.success(true)
                            resultSent = true
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "绑定网络失败: ${e.message}", e)
                        if (!resultSent) {
                            result.error("BIND_FAILED", "绑定网络失败: ${e.message}", null)
                            resultSent = true
                        }
                    }
                }

                override fun onUnavailable() {
                    Log.e(TAG, "❌ WiFi连接不可用: $ssid")
                    if (!resultSent) {
                        result.error("CONNECTION_FAILED", "WiFi连接不可用", null)
                        resultSent = true
                    }
                }

                override fun onLost(network: Network) {
                    Log.e(TAG, "❌ WiFi连接丢失: $ssid")
                    // 注意：这里不发送错误，因为连接可能已经成功返回过结果
                    // 网络丢失是正常现象，不应该导致应用崩溃
                    Log.w(TAG, "网络连接丢失，但可能已经成功连接过，不发送错误响应")
                }
            }

            // 请求网络连接
            Log.d(TAG, "发送网络连接请求...")
            connectivityManager.requestNetwork(networkRequest, networkCallback)
            Log.d(TAG, "网络连接请求已发送，等待回调...")

        } catch (e: Exception) {
            Log.e(TAG, "WiFi连接失败: ${e.message}", e)
            e.printStackTrace()
            if (!resultSent) {
                result.error("CONNECTION_FAILED", "WiFi连接失败: ${e.message}", null)
                resultSent = true
            }
        }
    }

    /**
     * 获取当前连接的WiFi信息
     * 增强状态检测逻辑，确保只在真正连接时返回有效信息
     */
    @SuppressLint("MissingPermission")
    fun getCurrentWifiInfo(): Map<String, Any?> {
        return try {
            // 检查WiFi是否启用
            if (!wifiManager.isWifiEnabled) {
                Log.d(TAG, "WiFi未启用，返回空连接信息")
                return mapOf(
                    "ssid" to null,
                    "bssid" to null,
                    "ipAddress" to null,
                    "signalStrength" to null
                )
            }

            val connectionInfo = wifiManager.connectionInfo
            val ssid = connectionInfo.ssid?.removeSurrounding("\"")
            val signalStrength = connectionInfo.rssi
            
            Log.d(TAG, "当前连接SSID: $ssid")
            Log.d(TAG, "信号强度: $signalStrength dBm")
            Log.d(TAG, "网络ID: ${connectionInfo.networkId}")
            
            // 检查是否真正连接到WiFi网络
            val isConnected = connectionInfo.networkId != -1
            
            // 验证SSID的有效性
            val isValidSsid = ssid != null && 
                             ssid.isNotEmpty() && 
                             ssid != "<unknown ssid>" && 
                             !ssid.contains("unknown", ignoreCase = true) &&
                             !ssid.contains("null", ignoreCase = true)
            
            // 验证信号强度的有效性
            // 正常WiFi信号范围：-30dBm (强) 到 -90dBm (弱)
            // -127dBm 表示没有信号或未连接
            val isValidSignal = signalStrength > -127 && signalStrength < 0
            
            Log.d(TAG, "WiFi连接状态: $isConnected")
            Log.d(TAG, "SSID有效性: $isValidSsid")
            Log.d(TAG, "信号强度有效性: $isValidSignal")
            
            // 只有在真正连接且信息有效时才返回连接信息
            if (isConnected && isValidSsid && isValidSignal) {
                Log.d(TAG, "✅ 检测到有效的WiFi连接: $ssid, 信号强度: $signalStrength dBm")
                return mapOf(
                    "ssid" to ssid,
                    "bssid" to connectionInfo.bssid,
                    "ipAddress" to connectionInfo.ipAddress,
                    "signalStrength" to signalStrength
                )
            } else {
                Log.d(TAG, "⚠️ 未检测到有效的WiFi连接")
                return mapOf(
                    "ssid" to null,
                    "bssid" to null,
                    "ipAddress" to null,
                    "signalStrength" to null
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "获取WiFi信息失败: ${e.message}", e)
            mapOf(
                "ssid" to null,
                "bssid" to null,
                "ipAddress" to null,
                "signalStrength" to null
            )
        }
    }


    /**
     * 获取当前连接信息 (兼容方法)
     */
    fun getCurrentConnection(): Map<String, Any?> {
        return getCurrentWifiInfo()
    }

    /**
     * 检查WiFi状态是否稳定
     */
    @SuppressLint("MissingPermission")
    private fun isWifiStable(): Boolean {
        return try {
            // 检查WiFi是否启用
            if (!wifiManager.isWifiEnabled) {
                Log.d(TAG, "WiFi未启用")
                return false
            }

            // 检查WiFi扫描状态
            val scanResults = wifiManager.scanResults
            Log.d(TAG, "WiFi扫描结果数量: ${scanResults.size}")

            // 检查当前连接状态
            val connectionInfo = wifiManager.connectionInfo
            val isConnected = connectionInfo.networkId != -1
            Log.d(TAG, "WiFi连接状态: $isConnected")

            // 如果WiFi已启用且有扫描结果，认为状态稳定
            val isStable = scanResults.isNotEmpty() || isConnected
            Log.d(TAG, "WiFi状态稳定: $isStable")
            
            isStable
        } catch (e: Exception) {
            Log.e(TAG, "检查WiFi状态失败: ${e.message}", e)
            false
        }
    }

    /**
     * 检查WiFi是否启用
     */
    @SuppressLint("MissingPermission")
    fun isWifiEnabled(): Boolean {
        return try {
            val enabled = wifiManager.isWifiEnabled
            Log.d(TAG, "WiFi启用状态: $enabled")
            enabled
        } catch (e: Exception) {
            Log.e(TAG, "检查WiFi启用状态失败: ${e.message}", e)
            false
        }
    }

    /**
     * 启用WiFi
     */
    @SuppressLint("MissingPermission")
    fun enableWifi(): Boolean {
        return try {
            if (!wifiManager.isWifiEnabled) {
                Log.d(TAG, "启用WiFi...")
                wifiManager.isWifiEnabled = true
                Thread.sleep(2000) // 等待WiFi启用
                Log.d(TAG, "WiFi启用请求已发送")
                true
            } else {
                Log.d(TAG, "WiFi已启用")
                true
            }
        } catch (e: Exception) {
            Log.e(TAG, "启用WiFi失败: ${e.message}", e)
            false
        }
    }

    /**
     * 关闭WiFi - 彻底断开所有连接
     */
    @SuppressLint("MissingPermission")
    fun disableWifi(): Boolean {
        return try {
            if (wifiManager.isWifiEnabled) {
                Log.d(TAG, "关闭WiFi...")
                wifiManager.isWifiEnabled = false
                Thread.sleep(1000) // 等待WiFi关闭
                Log.d(TAG, "WiFi关闭请求已发送")
                true
            } else {
                Log.d(TAG, "WiFi已关闭")
                true
            }
        } catch (e: Exception) {
            Log.e(TAG, "关闭WiFi失败: ${e.message}", e)
            false
        }
    }
}
