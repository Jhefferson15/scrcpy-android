package com.example.flutter_client

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
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
        }
        } // Close setMethodCallHandler

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
    }
}
