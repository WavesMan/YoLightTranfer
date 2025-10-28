package com.waveyo.yolighttransfer_flutter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import android.util.Log

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.yolighttransfer/hotspot"
    private lateinit var hotspotManager: HotspotManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 初始化热点管理器
        hotspotManager = HotspotManager(this)
        
        // 设置 MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            handleMethodCall(call, result)
        }
        
        Log.d("MainActivity", "热点管理 MethodChannel 已初始化")
    }

    /**
     * 处理方法调用
     */
    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        Log.d("MainActivity", "收到方法调用: ${call.method}")
        
        try {
            when (call.method) {
                "startHotspot" -> {
                    val ssid = call.argument<String>("ssid") ?: ""
                    val password = call.argument<String>("password") ?: ""
                    
                    if (ssid.isEmpty() || password.isEmpty()) {
                        result.error("INVALID_PARAMS", "SSID 或密码不能为空", null)
                        return
                    }
                    
                    // 检查 Android 版本兼容性
                    if (android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.O) {
                        result.error("UNSUPPORTED_VERSION", "Android 8.0 以下版本不支持创建自定义热点", null)
                        return
                    }
                    
                    val success = hotspotManager.startHotspot(ssid, password)
                    result.success(success)
                }
                
                "stopHotspot" -> {
                    val success = hotspotManager.stopHotspot()
                    result.success(success)
                }
                
                "connectToWifi" -> {
                    val ssid = call.argument<String>("ssid") ?: ""
                    val password = call.argument<String>("password") ?: ""
                    val encryptionType = call.argument<String>("encryptionType") ?: "WPA2"
                    
                    if (ssid.isEmpty() || password.isEmpty()) {
                        result.error("INVALID_PARAMS", "SSID 或密码不能为空", null)
                        return
                    }
                    
                    hotspotManager.connectToWifi(ssid, password, encryptionType, result)
                }
                
                "disconnectWifi" -> {
                    val success = hotspotManager.disconnectWifi()
                    result.success(success)
                }
                
                "isHotspotSupported" -> {
                    val supported = hotspotManager.isHotspotSupported()
                    result.success(supported)
                }
                
                "isHotspotRunning" -> {
                    val running = hotspotManager.isHotspotRunning()
                    result.success(running)
                }
                
                "getCurrentConnection" -> {
                    val connectionInfo = hotspotManager.getCurrentConnection()
                    result.success(connectionInfo)
                }
                
                "getActualHotspotInfo" -> {
                    val actualInfo = hotspotManager.getActualHotspotInfo()
                    result.success(actualInfo)
                }
                
                else -> {
                    result.notImplemented()
                }
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "处理方法调用失败: ${call.method}, 错误: ${e.message}")
            result.error("METHOD_ERROR", "方法调用失败: ${e.message}", null)
        }
    }
}
