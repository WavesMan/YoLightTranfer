package com.waveyo.yolighttransfer_flutter.hotspot

import android.content.Context
import android.os.Build
import android.util.Log

/**
 * 热点服务工厂
 * 根据 Android 版本创建对应的热点服务
 */
object HotspotServiceFactory {
    private const val TAG = "HotspotServiceFactory"

    /**
     * 根据 Android 版本创建对应的热点服务
     */
    fun createHotspotService(context: Context): HotspotService {
        return when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU -> {
                Log.d(TAG, "创建 Android 13+ TetheringManager 热点服务")
                TetheringHotspotService(context)
            }
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O -> {
                Log.d(TAG, "创建 Android 8.0-12 LocalOnlyHotspot 热点服务")
                LocalOnlyHotspotService(context)
            }
            else -> {
                Log.d(TAG, "创建 Android 7.0- 传统热点服务")
                LegacyHotspotService(context)
            }
        }
    }

    /**
     * 获取当前平台名称
     */
    fun getPlatformName(context: Context): String {
        return createHotspotService(context).getPlatformName()
    }

    /**
     * 检查当前平台是否支持热点
     */
    fun isHotspotSupported(context: Context): Boolean {
        return createHotspotService(context).isHotspotSupported()
    }
}
