package com.waveyo.yolighttransfer.network

import org.json.JSONObject

/**
 * 传输控制帧（JSON 明文）
 * 用于在 TCP 上传递控制消息：PAUSE/RESUME/CANCEL/PING/PONG/ACK/PROGRESS/ERROR
 * 符合跨平台TCP传输控制协议技术文档
 */
data class ControlFrame(
    val op: String,
    val transferId: String = "",
    val extra: Any? = null,
    val protocolVersion: String = "1.0"
) {
    fun toJson(): String = JSONObject()
        .put("op", op)
        .put("transferId", transferId)
        .putOpt("extra", extra)
        .put("protocolVersion", protocolVersion)
        .toString()

    companion object {
        fun fromJson(json: String): ControlFrame {
            val obj = JSONObject(json)
            return ControlFrame(
                op = obj.getString("op"),
                transferId = obj.optString("transferId", ""),
                extra = if (obj.has("extra")) obj.opt("extra") else null,
                protocolVersion = obj.optString("protocolVersion", "1.0")
            )
        }
        
        // 便捷方法创建标准控制帧
        fun createPing(transferId: String = ""): ControlFrame = ControlFrame("PING", transferId)
        fun createPong(transferId: String = ""): ControlFrame = ControlFrame("PONG", transferId)
        fun createAck(transferId: String, originalOp: String): ControlFrame = 
            ControlFrame("ACK", transferId, originalOp)
        fun createPause(transferId: String, progress: Long? = null): ControlFrame = 
            ControlFrame("PAUSE", transferId, progress)
        fun createResume(transferId: String, progress: Long? = null): ControlFrame = 
            ControlFrame("RESUME", transferId, progress)
        fun createCancel(transferId: String, reason: String? = null): ControlFrame = 
            ControlFrame("CANCEL", transferId, reason)
        fun createProgress(transferId: String, transferred: Long, total: Long): ControlFrame = 
            ControlFrame("PROGRESS", transferId, mapOf("transferred" to transferred, "total" to total))
        fun createError(transferId: String, errorMessage: String, errorCode: String? = null): ControlFrame = 
            ControlFrame("ERROR", transferId, mapOf("message" to errorMessage, "code" to errorCode))
    }
}
