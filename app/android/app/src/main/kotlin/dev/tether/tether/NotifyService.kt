package dev.tether.tether

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/**
 * Keeps asking the hub whether there is news, so a phone with the app closed
 * is told when a turn has finished or Claude needs an answer. It asks
 * /n/poll with a token that opens nothing else, first over the tailnet and
 * then over the hub's notification tunnel, so it works with or without
 * Tailscale. The app writes the settings (see NotifyPrefs); this only reads.
 */
class NotifyService : Service() {
    @Volatile private var running = false
    private var worker: Thread? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val prefs = NotifyPrefs.of(this)
        if (!prefs.getBoolean("enabled", false)) {
            stopSelf()
            return START_NOT_STICKY
        }
        startForegroundNow()
        if (!running) {
            running = true
            worker = Thread({ loop() }, "tether-notify").also { it.isDaemon = true; it.start() }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        worker?.interrupt()
        super.onDestroy()
    }

    private fun startForegroundNow() {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(NotificationChannel(CH_LISTEN, "Tether is listening", NotificationManager.IMPORTANCE_MIN))
        }
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        val n = builder(CH_LISTEN)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Tether is listening for updates")
            .setContentText("You are told when Claude finishes or needs you.")
            .setContentIntent(open)
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(ONGOING, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(ONGOING, n)
        }
    }

    private fun builder(channel: String): Notification.Builder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(this, channel)
        else @Suppress("DEPRECATION") Notification.Builder(this)

    private fun loop() {
        val prefs = NotifyPrefs.of(this)
        var failures = 0
        var lastGood = 0
        while (running && prefs.getBoolean("enabled", false)) {
            val token = prefs.getString("token", "") ?: ""
            val urls = (prefs.getString("urls", "") ?: "").split('\n').filter { it.isNotBlank() }
            if (token.isEmpty() || urls.isEmpty()) {
                sleep(15_000)
                continue
            }
            // Try the address that worked last first.
            val order = urls.indices.sortedBy { if (it == lastGood) 0 else 1 }
            var got = false
            for (i in order) {
                try {
                    if (pollOnce(prefs, urls[i], token)) {
                        got = true
                        lastGood = i
                        break
                    }
                } catch (e: UnauthorizedException) {
                    prefs.edit().putString("error", "The hub no longer accepts this device. Open Tether to sign in again.").putString("token", "").apply()
                    got = true
                    break
                } catch (e: Exception) {
                    prefs.edit().putString("error", "${e.javaClass.simpleName}: ${e.message}").apply()
                }
            }
            if (got) {
                failures = 0
            } else {
                failures++
                sleep(minOf(60_000L, 2_000L shl minOf(failures, 5)))
            }
        }
        running = false
        stopSelf()
    }

    private class UnauthorizedException : Exception()

    /** One long poll against [base]; false when it could not be asked. */
    private fun pollOnce(prefs: SharedPreferences, base: String, token: String): Boolean {
        val since = prefs.getLong("since", -1L)
        val query = if (since < 0) "" else "?since=$since&wait=25"
        val conn = URL(base.trimEnd('/') + "/n/poll" + query).openConnection() as HttpURLConnection
        try {
            conn.connectTimeout = 6_000
            conn.readTimeout = 40_000
            conn.setRequestProperty("Authorization", "Bearer $token")
            when (conn.responseCode) {
                200 -> {}
                401 -> throw UnauthorizedException()
                else -> throw java.io.IOException("the hub answered ${conn.responseCode}")
            }
            val body = conn.inputStream.bufferedReader().use { it.readText() }
            val json = JSONObject(body)
            val items = json.optJSONArray("items")
            if (items != null) {
                for (i in 0 until items.length()) show(prefs, items.getJSONObject(i))
            }
            prefs.edit().putLong("since", json.optLong("last", maxOf(since, 0L))).putLong("ok", System.currentTimeMillis()).remove("error").apply()
            return true
        } finally {
            conn.disconnect()
        }
    }

    private fun show(prefs: SharedPreferences, n: JSONObject) {
        val kind = n.optString("kind")
        if (kind != "test") {
            if (prefs.getBoolean("active", false)) return // the app is on screen: it shows this itself
            val wanted = (prefs.getString("kinds", "finished,approval,failed") ?: "").split(',')
            if (kind !in wanted) return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return
        val manager = getSystemService(NotificationManager::class.java)
        val channel = if (kind == "approval" || kind == "failed") CH_NEEDS else CH_DONE
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(NotificationChannel(CH_NEEDS, "Needs you", NotificationManager.IMPORTANCE_HIGH))
            manager.createNotificationChannel(NotificationChannel(CH_DONE, "Finished", NotificationManager.IMPORTANCE_DEFAULT))
        }
        val id = n.optLong("id").toInt()
        val open = PendingIntent.getActivity(
            this, id,
            Intent(this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK)
                .putExtra("tether.chat", n.optString("chat"))
                .putExtra("tether.session", n.optString("session")),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val body = n.optString("body")
        val note = builder(channel)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(n.optString("title"))
            .setContentText(body.ifEmpty { null })
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        manager.notify(NOTE_BASE + id, note)
    }

    private fun sleep(ms: Long) {
        try {
            Thread.sleep(ms)
        } catch (_: InterruptedException) {
        }
    }

    companion object {
        const val CH_LISTEN = "listen"
        const val CH_NEEDS = "needs"
        const val CH_DONE = "done"
        const val ONGOING = 7100
        const val NOTE_BASE = 7200
    }
}

/** What the app tells the service, kept where the service can read it with the app closed. */
object NotifyPrefs {
    fun of(context: Context): SharedPreferences = context.getSharedPreferences("dev.tether.notify", Context.MODE_PRIVATE)

    fun start(context: Context) {
        val intent = Intent(context, NotifyService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(intent) else context.startService(intent)
    }

    fun stop(context: Context) {
        context.stopService(Intent(context, NotifyService::class.java))
    }
}
