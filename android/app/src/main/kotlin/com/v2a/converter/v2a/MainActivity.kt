package com.v2a.converter.v2a

import android.os.Environment
import android.os.StatFs
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : AudioServiceActivity() {
    private val STORAGE_CHANNEL = "com.v2a.converter/storage"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STORAGE_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getStorageStats") {
                try {
                    val pathArg = call.argument<String>("path")
                    val targetPath = if (!pathArg.isNullOrEmpty()) {
                        File(pathArg)
                    } else {
                        Environment.getDataDirectory()
                    }

                    val stat = StatFs(targetPath.path)
                    val blockSize = stat.blockSizeLong
                    val totalBlocks = stat.blockCountLong
                    val availableBlocks = stat.availableBlocksLong

                    val totalBytes = totalBlocks * blockSize
                    val availableBytes = availableBlocks * blockSize
                    val usedBytes = (totalBytes - availableBytes).coerceAtLeast(0L)

                    val response = mapOf(
                        "totalBytes" to totalBytes,
                        "availableBytes" to availableBytes,
                        "usedBytes" to usedBytes
                    )
                    result.success(response)
                } catch (e: Exception) {
                    result.error("STORAGE_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
