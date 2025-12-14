package com.example.flutter_client

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.os.Handler
import android.os.Looper
import android.util.Log

class AdbMdnsHelper(private val context: Context, private val onDeviceListUpdated: (Map<String, String>) -> Unit) {

    private val nsdManager: NsdManager = context.getSystemService(Context.NSD_SERVICE) as NsdManager
    private val discoveredServices = mutableMapOf<String, NsdServiceInfo>()
    private val resolvedDevices = mutableMapOf<String, String>() // name -> ip:port

    private val discoveryListener = createListener()
    private val pairingDiscoveryListener = createListener()

    private fun createListener() = object : NsdManager.DiscoveryListener {
        override fun onDiscoveryStarted(regType: String) {
            Log.d("AdbMdnsHelper", "Service discovery started: $regType")
        }

        override fun onServiceFound(service: NsdServiceInfo) {
            Log.d("AdbMdnsHelper", "Service found: ${service.serviceName} ${service.serviceType}")
            if (service.serviceType.contains("_adb-tls-connect") || service.serviceType.contains("_adb-tls-pairing")) {
                 nsdManager.resolveService(service, object : NsdManager.ResolveListener {
                    override fun onResolveFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
                        Log.e("AdbMdnsHelper", "Resolve failed: $errorCode")
                    }

                    override fun onServiceResolved(serviceInfo: NsdServiceInfo) {
                        Log.d("AdbMdnsHelper", "Service resolved: ${serviceInfo.serviceName} -> ${serviceInfo.host}:${serviceInfo.port}")
                        synchronized(resolvedDevices) {
                            val ip = serviceInfo.host.hostAddress
                            val port = serviceInfo.port
                            val type = if (serviceInfo.serviceType.contains("pairing")) "pairing" else "connect"
                            // Use composite key so different types don't overwrite each other
                            resolvedDevices["${serviceInfo.serviceName}_$type"] = "$ip:$port|$type"
                            notifyUpdate()
                        }
                    }
                })
            }
        }

        override fun onServiceLost(service: NsdServiceInfo) {
            Log.d("AdbMdnsHelper", "Service lost: ${service.serviceName}")
            synchronized(resolvedDevices) {
                resolvedDevices.remove(service.serviceName)
                notifyUpdate()
            }
        }

        override fun onDiscoveryStopped(serviceType: String) {
            Log.i("AdbMdnsHelper", "Discovery stopped: $serviceType")
        }

        override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
            Log.e("AdbMdnsHelper", "Discovery failed: Error code:$errorCode")
            nsdManager.stopServiceDiscovery(this)
        }

        override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {
            Log.e("AdbMdnsHelper", "Discovery failed: Error code:$errorCode")
            nsdManager.stopServiceDiscovery(this)
        }
    }

    fun startDiscovery() {
        try {
            nsdManager.discoverServices("_adb-tls-connect._tcp.", NsdManager.PROTOCOL_DNS_SD, discoveryListener)
            nsdManager.discoverServices("_adb-tls-pairing._tcp.", NsdManager.PROTOCOL_DNS_SD, pairingDiscoveryListener)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun stopDiscovery() {
        try {
            nsdManager.stopServiceDiscovery(discoveryListener)
            nsdManager.stopServiceDiscovery(pairingDiscoveryListener)
        } catch (e: Exception) {
            // Ignore if not running
        }
    }

    private fun notifyUpdate() {
        // Convert resolvedDevices to simple map for Flutter
        // Map<Name, String> where String is JSON or delimited
        onDeviceListUpdated(resolvedDevices.toMap())
    }
}
