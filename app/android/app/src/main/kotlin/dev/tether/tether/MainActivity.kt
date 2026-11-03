package dev.tether.tether

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Tailscale: is it here, ask it to connect, open it. See
        // lib/data/datasources/tailscale_android.dart.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.tether/tailscale").setMethodCallHandler { call, result ->
            when (call.method) {
                "installed" -> result.success(tailscaleInstalled())
                "connect" -> result.success(tailscaleConnect())
                "open" -> result.success(tailscaleOpen())
                else -> result.notImplemented()
            }
        }
        // App updates: hand a downloaded, checked APK to the system installer,
        // and say a release is out. See lib/data/datasources/update_platform.dart.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.tether/update").setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> installApk(call.argument<String>("path") ?: "", result)
                "notify" -> {
                    notifyUpdate(call.argument<String>("title") ?: "", call.argument<String>("body") ?: "")
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private val tailscalePackage = "com.tailscale.ipn"

    private fun tailscaleInstalled(): Boolean = try {
        packageManager.getPackageInfo(tailscalePackage, 0)
        true
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }

    /** Asks Tailscale to connect, through the intent its receiver listens for. */
    private fun tailscaleConnect(): Boolean {
        if (!tailscaleInstalled()) return false
        sendBroadcast(Intent("com.tailscale.ipn.CONNECT_VPN").setPackage(tailscalePackage))
        return true
    }

    private fun tailscaleOpen(): Boolean {
        val launch = packageManager.getLaunchIntentForPackage(tailscalePackage) ?: return false
        startActivity(launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        return true
    }

    private fun installApk(path: String, result: MethodChannel.Result) {
        val apk = File(path)
        if (!apk.exists()) {
            result.error("missing", "The downloaded update is gone; download it again.", null)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !packageManager.canRequestPackageInstalls()) {
            startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
            result.error("permission", "Allow Tether to install apps in the screen that opened, then tap Install again.", null)
            return
        }
        val uri = FileProvider.getUriForFile(this, "$packageName.updates", apk)
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, "application/vnd.android.package-archive")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
        result.success(null)
    }

    private fun notifyUpdate(title: String, body: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val open = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(NotificationChannel("updates", "App updates", NotificationManager.IMPORTANCE_DEFAULT))
            Notification.Builder(this, "updates")
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val notification = builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        manager.notify(UPDATE_NOTIFICATION, notification)
    }

    private companion object {
        const val UPDATE_NOTIFICATION = 7001
    }
}
