package com.uemsihtv.hdexpress

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkRequest
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
  private val channelName = "uemsi_wifi_joiner"
  private val galleryChannelName = "uemsi_gallery_saver"
  private val galleryIo = Executors.newSingleThreadExecutor()

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, galleryChannelName)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "sdkInt" -> result.success(Build.VERSION.SDK_INT)
          "saveImage" -> {
            val bytes = call.argument<ByteArray>("bytes")
            val filename = call.argument<String>("filename") ?: "capture.jpg"
            if (bytes == null || bytes.isEmpty()) {
              result.error("bad_args", "Missing image bytes", null)
              return@setMethodCallHandler
            }
            galleryIo.execute {
              try {
                val uri = GalleryMediaStore.saveImage(this, bytes, filename)
                Handler(Looper.getMainLooper()).post { result.success(uri) }
              } catch (e: Exception) {
                Handler(Looper.getMainLooper()).post {
                  result.error("save_failed", e.message ?: "Save failed", null)
                }
              }
            }
          }
          "saveVideo" -> {
            val path = call.argument<String>("path")
            val title = call.argument<String>("title") ?: ""
            if (path.isNullOrBlank()) {
              result.error("bad_args", "Missing video path", null)
              return@setMethodCallHandler
            }
            galleryIo.execute {
              try {
                val uri = GalleryMediaStore.saveVideo(this, path, title)
                Handler(Looper.getMainLooper()).post { result.success(uri) }
              } catch (e: Exception) {
                Handler(Looper.getMainLooper()).post {
                  result.error("save_failed", e.message ?: "Save failed", null)
                }
              }
            }
          }
          else -> result.notImplemented()
        }
      }

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "joinWpa" -> {
            val ssid = call.argument<String>("ssid")
            val password = call.argument<String>("password")
            if (ssid.isNullOrBlank() || password.isNullOrBlank()) {
              result.error("bad_args", "Missing ssid/password", null)
              return@setMethodCallHandler
            }

            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
              result.success(false)
              return@setMethodCallHandler
            }

            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val specifier = WifiNetworkSpecifier.Builder()
              .setSsid(ssid)
              .setWpa2Passphrase(password)
              .build()

            val request = NetworkRequest.Builder()
              .addTransportType(android.net.NetworkCapabilities.TRANSPORT_WIFI)
              .setNetworkSpecifier(specifier)
              .build()

            val mainHandler = Handler(Looper.getMainLooper())
            var finished = false

            val callback = object : ConnectivityManager.NetworkCallback() {
              override fun onAvailable(network: Network) {
                if (finished) return
                finished = true
                try {
                  cm.bindProcessToNetwork(network)
                } catch (_: Throwable) {
                  // Best-effort: binding may fail on some devices; still report success.
                }
                try {
                  cm.unregisterNetworkCallback(this)
                } catch (_: Throwable) {}
                result.success(true)
              }

              override fun onUnavailable() {
                if (finished) return
                finished = true
                try {
                  cm.unregisterNetworkCallback(this)
                } catch (_: Throwable) {}
                result.success(false)
              }
            }

            cm.requestNetwork(request, callback)
            mainHandler.postDelayed({
              if (finished) return@postDelayed
              finished = true
              try {
                cm.unregisterNetworkCallback(callback)
              } catch (_: Throwable) {}
              result.success(false)
            }, 15_000)
          }
          else -> result.notImplemented()
        }
      }
  }
}
