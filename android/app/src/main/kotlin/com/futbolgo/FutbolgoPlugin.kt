package com.futbolgo

import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall

class FutbolgoPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        Log.d("FutbolgoPlugin", "onAttachedToEngine")
        channel = MethodChannel(binding.binaryMessenger, "futbolgo")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        Log.d("FutbolgoPlugin", "onDetachedFromEngine")
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        Log.d("FutbolgoPlugin", "onMethodCall: ${call.method}")
        try {
            val scraperClass = Class.forName("scraper.Scraper")
            Log.d("FutbolgoPlugin", "Clase scraper.Scraper encontrada")
            when (call.method) {
                "scrapeEvents" -> {
                    Log.d("FutbolgoPlugin", "Llamando scrapeEvents")
                    val method = scraperClass.getMethod("scrapeEvents")
                    val json = method.invoke(null) as String
                    Log.d("FutbolgoPlugin", "scrapeEvents resultado: ${json.take(100)}")
                    result.success(json)
                }
                "scrapeChannels" -> {
                    Log.d("FutbolgoPlugin", "Llamando scrapeChannels")
                    val method = scraperClass.getMethod("scrapeChannels")
                    val json = method.invoke(null) as String
                    result.success(json)
                }
                "scrapeAll" -> {
                    Log.d("FutbolgoPlugin", "Llamando scrapeAll")
                    val method = scraperClass.getMethod("scrapeAll")
                    val json = method.invoke(null) as String
                    Log.d("FutbolgoPlugin", "scrapeAll resultado: $json")
                    result.success(json)
                }
                "checkStreamActive" -> {
                    val url = call.argument<String>("url")
                    if (url == null) {
                        result.error("INVALID_ARGS", "url argument required", null)
                        return
                    }
                    val method = scraperClass.getMethod("checkStreamActive", String::class.java)
                    val json = method.invoke(null, url) as String
                    result.success(json)
                }
                "resolveStream" -> {
                    val url = call.argument<String>("url")
                    if (url == null) {
                        result.error("INVALID_ARGS", "url argument required", null)
                        return
                    }
                    val method = scraperClass.getMethod("resolveStreamFromURL", String::class.java)
                    val json = method.invoke(null, url) as String
                    // The response is already a raw JSON string with the resolved URL
                    result.success(json)
                }
                else -> {
                    result.notImplemented()
                }
            }
        } catch (e: Exception) {
            Log.e("FutbolgoPlugin", "Error: ${e.message}", e)
            result.error("PLUGIN_ERROR", "Failed to call Go backend: ${e.message}", null)
        }
    }
}