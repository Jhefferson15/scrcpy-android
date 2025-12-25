package com.example.flutter_client

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.io.File
import java.io.FileOutputStream

class DebugReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "DebugReceiver"
        const val ACTION_DEBUG = "com.example.flutter_client.DEBUG_ACTION"
        const val CMD_CONNECT = "CONNECT"
        const val CMD_EXEC = "EXEC"
        const val CMD_PUSH_TEST = "PUSH_TEST"
        const val CMD_PAIR = "PAIR"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_DEBUG) return

        val cmd = intent.getStringExtra("CMD")
        log("Received command: $cmd")

        val pendingResult = goAsync()

        CoroutineScope(Dispatchers.IO).launch {
            try {
                handleCommand(context, intent)
                log("Command $cmd succeeded")
            } catch (e: Exception) {
                log("Command $cmd failed: ${e.message}")
                e.printStackTrace()
            } finally {
                pendingResult.finish()
            }
        }
    }

    private fun log(message: String) {
        Log.i(TAG, message)
        try {
            val file = File("/data/local/tmp/headless_log.txt")
            FileOutputStream(file, true).use {
                it.write("${java.util.Date()}: $message\n".toByteArray())
            }
        } catch (e: Exception) {
            // Ignore file log errors
        }
    }

    private suspend fun handleCommand(context: Context, intent: Intent) {
        val manager = AdbConnectionManager.getInstance(context)
        val cmd = intent.getStringExtra("CMD")

        when (cmd) {
            CMD_PAIR -> {
                val host = intent.getStringExtra("HOST") ?: "192.168.0.24"
                val port = intent.getIntExtra("PORT", 5555)
                val code = intent.getStringExtra("CODE") ?: ""
                log("Pairing with $host:$port code=$code")
                manager.pair(host, port, code)
                log("Pairing successful")
            }

            CMD_CONNECT -> {
                val host = intent.getStringExtra("HOST") ?: "192.168.0.24"
                val port = intent.getIntExtra("PORT", 5555)
                log("Connecting to $host:$port")
                manager.connect(host, port)
                log("Connected successfully")
            }

            CMD_EXEC -> {
                val command = intent.getStringExtra("COMMAND") ?: "ls -l /"
                log("Executing: $command")
                val stream = manager.openStream("shell:$command")
                val output = stream.openInputStream().bufferedReader().use { it.readText() }
                stream.close()
                log("Output: $output")
            }

            CMD_PUSH_TEST -> {
                // Test Push of a dummy file
                log("Starting Push Test")
                
                // 1. Create dummy file
                val cacheDir = context.cacheDir
                val dummyFile = File(cacheDir, "debug_test.txt")
                if (!dummyFile.exists()) {
                    FileOutputStream(dummyFile).use { 
                        it.write("Hello from DebugReceiver!".toByteArray()) 
                    }
                }
                val data = dummyFile.readBytes()
                val remotePath = "/data/local/tmp/debug_test.txt"

                log("Pushing ${data.size} bytes to $remotePath")
                
                // 2. Logic similar to MainActivity but purely native
                // 'exec:dd' method
                val stream = manager.openStream("exec:dd of=$remotePath")
                val outputStream = stream.openOutputStream()
                
                // 4KB Chunks
                val chunkSize = 4 * 1024 
                var offset = 0
                while (offset < data.size) {
                    val remaining = data.size - offset
                    val count = if (remaining > chunkSize) chunkSize else remaining
                    outputStream.write(data, offset, count)
                    outputStream.flush() // Crucial flush
                    offset += count
                }
                stream.close()
                log("Push finished. Verifying...")
                
                // Verify
                val verifyStream = manager.openStream("shell:cat $remotePath")
                val verifyOutput = verifyStream.openInputStream().bufferedReader().use { it.readText() }
                verifyStream.close()
                
                log("Verification content: $verifyOutput")
            }
            
            else -> {
                log("Unknown command: $cmd")
            }
        }
    }
}
