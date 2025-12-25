package com.example.flutter_client

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.renderer.FlutterRenderer
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import android.util.Log
// AdbConnectionManager is in the same package, no import needed

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.flutter_client/adb"
    private val EVENT_CHANNEL = "com.example.flutter_client/adb/discovery"
    
    private var mdnsHelper: AdbMdnsHelper? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAdbKeyPair" -> {
                    CoroutineScope(Dispatchers.IO).launch {
                        try {
                            val manager = AdbConnectionManager.getInstance(applicationContext)
                            val privKey = manager.privateKey
                            val cert = manager.certificate
                            
                            val resultMap = mapOf(
                                "privateKey" to privKey.encoded,
                                "certificate" to cert.encoded
                            )
                            
                            withContext(Dispatchers.Main) {
                                result.success(resultMap)
                            }
                        } catch (e: Exception) {
                             withContext(Dispatchers.Main) {
                                result.error("KEY_ERROR", "Failed to retrieve ADB keys: ${e.message}", null)
                            }
                        }
                    }
                }
                "pair" -> {
                    val host = call.argument<String>("host")
                    val port = call.argument<Int>("port")
                    val code = call.argument<String>("code")
                    
                    if (host != null && port != null && code != null) {
                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                val manager = AdbConnectionManager.getInstance(applicationContext)
                                manager.pair(host, port, code)
                                withContext(Dispatchers.Main) {
                                    result.success(true)
                                }
                            } catch (e: Exception) {
                                withContext(Dispatchers.Main) {
                                    result.error("PAIRING_FAILED", e.message, null)
                                }
                            }
                        }
                    } else {
                        result.error("INVALID_ARGS", "Host, port, and code are required", null)
                    }
                }
                "startDiscovery" -> {
                    mdnsHelper?.startDiscovery()
                    result.success(null)
                }
                "stopDiscovery" -> {
                    mdnsHelper?.stopDiscovery()
                    result.success(null)
                }
                "testConnection" -> {
                    val host = call.argument<String>("host")
                    val port = call.argument<Int>("port")
                    if (host != null && port != null) {
                         CoroutineScope(Dispatchers.IO).launch {
                            try {
                                val manager = AdbConnectionManager.getInstance(applicationContext)
                                // Try to connect using the Native Library
                                manager.connect(host, port)
                                
                                // Try to open a stream to verify auth
                                val stream = manager.openStream("shell:echo success")
                                val meta = stream.openInputStream().read()
                                stream.close()
                                
                                withContext(Dispatchers.Main) {
                                    result.success(true)
                                }
                            } catch (e: Exception) {
                                withContext(Dispatchers.Main) {
                                    result.error("CONNECTION_FAILED", e.message, null)
                                }
                            }
                        }
                    } else {
                        result.error("INVALID_ARGS", "Host and port required", null)
                    }
                }
                "connect" -> {
                    val host = call.argument<String>("host")
                    val port = call.argument<Int>("port")
                    if (host != null && port != null) {
                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                val manager = AdbConnectionManager.getInstance(applicationContext)
                                manager.connect(host, port)
                                withContext(Dispatchers.Main) { result.success(true) }
                            } catch (e: Exception) {
                                withContext(Dispatchers.Main) { result.error("CONNECT_FAILED", e.message, null) }
                            }
                        }
                    } else {
                        result.error("INVALID_ARGS", "Host/Port required", null)
                    }
                }
                "disconnect" -> {
                    CoroutineScope(Dispatchers.IO).launch {
                        try {
                            val manager = AdbConnectionManager.getInstance(applicationContext)
                            manager.close()
                            withContext(Dispatchers.Main) { result.success(true) }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) { result.error("DISCONNECT_FAILED", e.message, null) }
                        }
                    }
                }
                "execute" -> {
                    val command = call.argument<String>("command")
                    if (command != null) {
                        CoroutineScope(Dispatchers.IO).launch {
                           try {
                               val manager = AdbConnectionManager.getInstance(applicationContext)
                               val stream = manager.openStream("shell:$command")
                               val output = StringBuilder()
                               // Standard reading loop
                               val inputStream = stream.openInputStream()
                               val buffer = ByteArray(4096)
                               var bytesRead: Int
                               // Simple blocking read until EOF
                               while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                                   if (bytesRead > 0) {
                                       output.append(String(buffer, 0, bytesRead))
                                   }
                               }
                               stream.close()
                               withContext(Dispatchers.Main) { result.success(output.toString()) }
                           } catch (e: Exception) {
                               withContext(Dispatchers.Main) { result.error("EXEC_FAILED", e.message, null) }
                           }
                        }
                    } else {
                        result.error("INVALID_ARGS", "Command required", null)
                    }
                }
                "pushFile" -> {
                    val path = call.argument<String>("path")
                    val data = call.argument<ByteArray>("data")
                    if (path != null && data != null) {
                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                val manager = AdbConnectionManager.getInstance(applicationContext)
                                android.util.Log.i("MainActivity", "Pushing file to $path (${data.size} bytes)...")
                                
                                // SOLUTION: Use base64 encoding and single shell command to avoid connection reuse issues
                                // This eliminates the need for a second stream which was causing "Stream closed" errors
                                val base64Data = android.util.Base64.encodeToString(data, android.util.Base64.NO_WRAP)
                                
                                // Single compound command: decode base64 and write file with permissions in one go
                                val command = "echo '$base64Data' | base64 -d > $path && chmod 777 $path && echo 'SUCCESS'"
                                
                                android.util.Log.d("MainActivity", "Using single compound shell command...")
                                val stream = manager.openStream("shell:$command")
                                try {
                                    val inputStream = stream.openInputStream()
                                    val output = StringBuilder()
                                    val buffer = ByteArray(1024)
                                    var bytesRead: Int
                                    
                                    // Read response to ensure command completes
                                    while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                                        if (bytesRead > 0) {
                                            output.append(String(buffer, 0, bytesRead))
                                        }
                                    }
                                    
                                    val response = output.toString().trim()
                                    android.util.Log.d("MainActivity", "Command response: $response")
                                    
                                    if (!response.contains("SUCCESS")) {
                                        throw Exception("Push command did not return SUCCESS. Response: $response")
                                    }
                                } finally {
                                    stream.close()
                                }
                                
                                android.util.Log.i("MainActivity", "File push completed successfully: $path")
                                withContext(Dispatchers.Main) { result.success(true) }
                            } catch (e: Exception) {
                                android.util.Log.e("MainActivity", "Push failed for $path: ${e.message}", e)
                                withContext(Dispatchers.Main) { 
                                    result.error("PUSH_FAILED", "Failed to push $path: ${e.message}", e.toString()) 
                                }
                            }
                        }
                    } else {
                        result.error("INVALID_ARGS", "Path and data required", null)
                    }
                }
            } // end when
        } // end setMethodCallHandler

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    mdnsHelper = AdbMdnsHelper(applicationContext) { deviceMap ->
                        runOnUiThread {
                             events?.success(deviceMap)
                        }
                    }
                    mdnsHelper?.startDiscovery()
                }

                override fun onCancel(arguments: Any?) {
                    mdnsHelper?.stopDiscovery()
                    mdnsHelper = null
                }
            }
        )
        // Video Decoder Channel
        val decoderChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.seuapp/decoder")
        val videoDecoder = VideoDecoder(applicationContext, flutterEngine.renderer)
        decoderChannel.setMethodCallHandler(videoDecoder)
    }

    override fun onDestroy() {
        super.onDestroy()
        mdnsHelper?.stopDiscovery()
    }
}
