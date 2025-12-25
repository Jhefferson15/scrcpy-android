package com.example.flutter_client

import android.media.MediaCodec
import android.media.MediaFormat
import android.view.Surface
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.io.IOException
import java.nio.ByteBuffer
import kotlinx.coroutines.launch
import kotlinx.coroutines.isActive
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.CoroutineScope

class VideoDecoder(private val context: android.content.Context, private val renderer: io.flutter.embedding.engine.renderer.FlutterRenderer) : MethodChannel.MethodCallHandler {
    private var mediaCodec: MediaCodec? = null
    private var surfaceEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var surface: Surface? = null
    private var streamJob: kotlinx.coroutines.Job? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initSurface" -> {
                try {
                    // Get resolution from Dart (which queries the remote device)
                    val width = call.argument<Int>("width") ?: 1920
                    val height = call.argument<Int>("height") ?: 1080
                    
                    android.util.Log.i("VideoDecoder", "Initializing surface with resolution: ${width}x${height}")
                    
                    // 1. Create Flutter Texture
                    surfaceEntry = renderer.createSurfaceTexture()
                    val textureId = surfaceEntry!!.id()
                    val surfaceTexture = surfaceEntry!!.surfaceTexture()
                    
                    // Set buffer size to match remote device resolution
                    surfaceTexture.setDefaultBufferSize(width, height) 

                    // 2. Create Surface
                    surface = Surface(surfaceTexture)

                    // 3. Configure MediaCodec with dynamic resolution
                    val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height)
                    
                    try {
                        mediaCodec = MediaCodec.createDecoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
                        mediaCodec!!.configure(format, surface, null, 0)
                        mediaCodec!!.start()
                        
                        result.success(textureId)
                    } catch (e: IOException) {
                         result.error("CODEC_ERROR", "Failed to create decoder: ${e.message}", null)
                         release()
                    }

                } catch (e: Exception) {
                    result.error("INIT_ERROR", "Failed to initialize surface: ${e.message}", null)
                    release()
                }
            }
            "startSession" -> {
                val command = call.argument<String>("command")
                if (command != null) {
                    startNativeSession(command)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGS", "Command required", null)
                }
            }
            "startTcpSession" -> {
                val host = call.argument<String>("host")
                val port = call.argument<Int>("port")
                if (host != null && port != null) {
                    startTcpSession(host, port)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGS", "Host/Port required", null)
                }
            }
            "stop" -> {
                release()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startNativeSession(command: String) {
        val scope = kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.IO)
        streamJob?.cancel()
        streamJob = scope.launch {
            try {
                val manager = AdbConnectionManager.getInstance(context)
                
                android.util.Log.d("VideoDecoder", "Starting Server: $command")
                
                // 1. Start Server (Keep shell stream open to keep process alive)
                val serverStream = manager.openStream("shell:$command")
                
                // CRITICAL: Server writes to stdout/stderr. If we don't read it, the stream blocks!
                // Start background thread to consume server output
                val serverReaderScope = kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.IO)
                serverReaderScope.launch {
                    try {
                        val serverInput = serverStream.openInputStream()
                        val buffer = ByteArray(1024)
                        var bytesRead: Int
                        while (serverInput.read(buffer).also { bytesRead = it } != -1) {
                            if (bytesRead > 0) {
                                val output = String(buffer, 0, bytesRead)
                                android.util.Log.d("VideoDecoder", "Server Output: $output")
                            }
                        }
                    } catch (e: Exception) {
                        android.util.Log.w("VideoDecoder", "Server stream reader finished: ${e.message}")
                    }
                }
                
                // 2. Wait for server to initialize (longer delay)
                android.util.Log.d("VideoDecoder", "Waiting for server to start...")
                kotlinx.coroutines.delay(1000) // Give server 1 second to start
                
                // 3. Connect to Video Socket (localabstract:scrcpy)
                // Retry mechanism as server takes time to bind socket
                var videoStream: io.github.muntashirakon.adb.AdbStream? = null
                
                for (i in 0..30) { // Try for ~6 seconds
                    try {
                        videoStream = manager.openStream("localabstract:scrcpy")
                        android.util.Log.i("VideoDecoder", "Connected to video socket!")
                        break
                    } catch (e: Exception) {
                        if (i % 5 == 0) android.util.Log.d("VideoDecoder", "Waiting for video socket... (attempt $i/30)")
                        kotlinx.coroutines.delay(200)
                    }
                }

                if (videoStream == null) {
                    android.util.Log.e("VideoDecoder", "Failed to connect to video socket after retries.")
                    serverStream.close()
                    return@launch
                }

                val inputStream = videoStream.openInputStream()
                
                // 4. Read loop from VIDEO stream
                readLoop(inputStream)

                videoStream.close()
                serverStream.close()
            } catch (e: Exception) {
                android.util.Log.e("VideoDecoder", "Stream error", e)
            }
        }
    }

    private fun startTcpSession(host: String, port: Int) {
        val scope = kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.IO)
        streamJob?.cancel()
        streamJob = scope.launch {
            try {
                val socket = java.net.Socket(host, port)
                val inputStream = socket.getInputStream()
                
                readLoop(inputStream)

                socket.close()
            } catch (e: Exception) {
                android.util.Log.e("VideoDecoder", "TCP Stream error", e)
            }
        }
    }

    private fun readLoop(inputStream: java.io.InputStream) {
         val buffer = ByteArray(1024 * 64) // 64KB chunk buffer
         var bytesRead: Int
         
         // Buffer for accumulating incomplete NAL units
         val accumulator = java.io.ByteArrayOutputStream()
         
         while (inputStream.read(buffer).also { bytesRead = it } != -1 && streamJob?.isActive == true) {
             if (bytesRead > 0) {
                 android.util.Log.i("VideoDecoder", "Bytes received: $bytesRead")
                 // 1. Process new data
                 val data = buffer.copyOfRange(0, bytesRead)
                 
                 // 2. Scan for NAL Start Codes (00 00 00 01)
                 // This simple parser assumes we are looking for the NEXT start code to flush the PREVIOUS NAL.
                 // We append data to accumulator, then scan the accumulator.
                 
                 accumulator.write(data)
                 val currentBytes = accumulator.toByteArray()
                 
                 var offset = 0
                 while (offset < currentBytes.size - 3) {
                     // Check for 00 00 00 01
                     if (currentBytes[offset] == 0.toByte() && 
                         currentBytes[offset+1] == 0.toByte() && 
                         currentBytes[offset+2] == 0.toByte() && 
                         currentBytes[offset+3] == 1.toByte()) {
                             
                             // Found Start Code at 'offset'
                             // Everything BEFORE this offset is a NAL (if valid)
                             if (offset > 0) {
                                 // We have a NAL ending at 'offset'
                                 // But wait, we need to handle the case where we are just starting (skipping header)
                                 // If this is the FIRST start code, offset might be > 0 (the header).
                                 // We just discard it? Yes, header is garbage.
                                 
                                 // However, we need to extract from 0 to offset.
                                 // But we need to separate "Garbage/Header" from "Valid Previous NAL".
                                 // If we assume the stream starts with Header, then 0..offset is garbage.
                                 // If we are in the middle of stream, 0..offset is the rest of the previous NAL.
                                 // Since we accumulate, 0..offset IS the NAL we were building.
                                 // Wait, if 0..offset contains NO start code, it's just payload.
                                 
                                 // Strategy:
                                 // We find start code index.
                                 // If we have data accumulated, we flush 0..index as a NAL.
                                 // Then we shift the accumulator.
                                 
                                 val nalUnit = currentBytes.copyOfRange(0, offset)
                                 // Only feed if it looks like a NAL (e.g. typical size) or just feed it.
                                 // If it's the header (64 bytes), decoder might reject or ignore.
                                 // BUT, strict NAL parsing usually implies the NAL *starts* with 00 00 00 01.
                                 // The accumulator typically holds the *start code* too?
                                 // Let's adopt strategy: Accumulator holds [00 00 00 01 ... PAYLOAD ...]
                                 // When we find NEXT 00 00 00 01, we flush everything before it.
                                 
                                 feedToDecoder(nalUnit, nalUnit.size)
                             }
                             
                             // Now, remove the processed data (0..offset) from accumulator
                             // Actually, we need to rebuild accumulator from offset..end
                             // But wait, the loop continues scanning 'currentBytes'
                             // We should update 'currentBytes' logic or just track "lastStartCodeIndex".
                             // Easier: Just slice and feed, then reset.
                             
                             // Refined approach:
                             // We don't modify accumulator in loop. We find split points.
                     }
                     offset++
                 }
                 
                 // This NAL parser logic inside readLoop is complex and error prone.
                 // Moving to a dedicated simple NAL spliter method is safer.
                 processStreamData(data)
             }
         }
    }
    
    // Internal buffer for NAL processing
    private var pendingData = java.io.ByteArrayOutputStream()
    private var foundFirstStartCode = false

    private fun processStreamData(data: ByteArray) {
        // Append new data
        pendingData.write(data)
        val allData = pendingData.toByteArray()
        
        var scanIndex = 0
        // We want to find start codes.
        // If we haven't found FIRST start code yet, we scan for it and discard everything before (Header).
        
        if (!foundFirstStartCode) {
            val start = findStartCode(allData, 0)
            if (start != -1) {
                // Found first start code!
                // Discard 0..start (Header)
                foundFirstStartCode = true
                scanIndex = start
                
                // Now rewrite pendingData to start from here
                // But we can just continue processing from 'start'
            } else {
                // No start code yet, keep accumulating (or discard if too big?)
                // If header is 64 bytes, 1KB is enough.
                if (allData.size > 100000) {
                     pendingData.reset() // Safety reset
                }
                return
            }
        }
        
        // We have found first start code at least once.
        // scanIndex is where we believe a NAL starts (or we are searching for next one).
        // Actually, scanIndex should be "search for NEXT start code after current NAL".
        
        // We assume pendingData starts with a NAL (00 00 00 01...).
        // We search for the NEXT 00 00 00 01.
        
        // If we just sync pendingData to always start with 00 00 00 01
        
        // Optimization:
        // We only need to scan from where we left off? 
        // For simplicity: Scan whole buffer? No, slow.
        // Scan from 'offset' which is 4 (skip current start code).
        
        var currentOffset = 0
        while (currentOffset < allData.size) {
            // Find NEXT start code.
            // We search starting from currentOffset + 4 (to skip the start code we are currently at)
            // But verify we are at a start code?
            // Assuming pendingData[0..3] is 00 00 00 01 (after trim).
            
            // Wait, "foundFirstStartCode" logic requires us to trim pendingData immediately.
            if (foundFirstStartCode && scanIndex > 0) {
                 // We found start code at scanIndex. remove 0..scanIndex
                 val remaining = allData.copyOfRange(scanIndex, allData.size)
                 pendingData.reset()
                 pendingData.write(remaining)
                 processStreamData(ByteArray(0)) // recurse with clean state
                 return
            }

            // Standard loop: pendingData[0] is start of NAL. find end.
            val nextStart = findStartCode(allData, 4) // Scan after header
            if (nextStart != -1) {
                // Found next NAL at nextStart.
                // Current NAL is 0..nextStart
                val nal = allData.copyOfRange(0, nextStart)
                feedToDecoder(nal, nal.size)
                
                // Remove processed NAL
                val remaining = allData.copyOfRange(nextStart, allData.size)
                pendingData.reset()
                pendingData.write(remaining)
                
                // Continue processing the remaining data (which starts with 00 00 00 01)
                processStreamData(ByteArray(0)) 
                return
            } else {
                // No next start code found yet. NAL is incomplete.
                // Keep pendingData as is.
                break
            }
        }
    }
    
    private fun findStartCode(data: ByteArray, offset: Int): Int {
        for (i in offset until data.size - 3) {
             if (data[i] == 0.toByte() && 
                 data[i+1] == 0.toByte() && 
                 data[i+2] == 0.toByte() && 
                 data[i+3] == 1.toByte()) {
                     return i
             }
        }
        return -1
    }

    private fun feedToDecoder(data: ByteArray, length: Int) {
        val codec = mediaCodec ?: return
        try {
            val inputBufferIndex = codec.dequeueInputBuffer(10000)
            if (inputBufferIndex >= 0) {
                val inputBuffer = codec.getInputBuffer(inputBufferIndex)
                inputBuffer?.clear()
                inputBuffer?.put(data, 0, length)
                codec.queueInputBuffer(inputBufferIndex, 0, length, 0, 0)
            } else {
                 android.util.Log.w("VideoDecoder", "Input buffer unavailable, dropping frame chunk.")
            }
            
            val bufferInfo = MediaCodec.BufferInfo()
            var outputBufferIndex = codec.dequeueOutputBuffer(bufferInfo, 0)
            
            if (outputBufferIndex == MediaCodec.INFO_TRY_AGAIN_LATER) {
                 // Common during startup
            } else if (outputBufferIndex >= 0) {
                android.util.Log.d("VideoDecoder", "Frame Decoded! Size: ${bufferInfo.size}")
            }

            while (outputBufferIndex >= 0) {
                codec.releaseOutputBuffer(outputBufferIndex, true)
                outputBufferIndex = codec.dequeueOutputBuffer(bufferInfo, 0)
            }
        } catch (e: Exception) {
             android.util.Log.e("VideoDecoder", "Codec Error", e)
        }
    }

    private fun release() {
        streamJob?.cancel()
        try {
            mediaCodec?.stop()
            mediaCodec?.release()
        } catch (e: Exception) {}
        mediaCodec = null

        surface?.release()
        surface = null

        surfaceEntry?.release()
        surfaceEntry = null
    }
}
