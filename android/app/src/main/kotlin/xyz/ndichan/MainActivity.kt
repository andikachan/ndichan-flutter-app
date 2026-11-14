package xyz.ndichan

import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.drawable.Icon
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val PIP_CHANNEL = "xyz.ndichan/pip"
    private val ACTION_PLAY_PAUSE = "xyz.ndichan.pip.ACTION_PLAY_PAUSE"

    private var methodChannel: MethodChannel? = null
    private var isPlaying = true
    private var autoEnterEnabled = false

    private val pipActionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == ACTION_PLAY_PAUSE) {
                methodChannel?.invokeMethod("onPipAction", "playPause")
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isPipSupported" -> {
                    val supported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
                    result.success(supported)
                }
                "enterPip" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                        packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)) {
                        try {
                            val params = buildPipParams(isPlaying)
                            val entered = enterPictureInPictureMode(params)
                            result.success(entered)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "setAutoEnter" -> {
                    autoEnterEnabled = call.argument<Boolean>("enabled") ?: false
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        try {
                            val builder = PictureInPictureParams.Builder()
                                .setAutoEnterEnabled(autoEnterEnabled)
                                .setAspectRatio(Rational(16, 9))
                            setPictureInPictureParams(builder.build())
                        } catch (e: Exception) {}
                    }
                    result.success(true)
                }
                "updatePlaybackState" -> {
                    isPlaying = call.argument<Boolean>("isPlaying") ?: true
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && isInPictureInPictureMode) {
                        try {
                            setPictureInPictureParams(buildPipParams(isPlaying))
                        } catch (e: Exception) {}
                    }
                    result.success(true)
                }
                "openCastSettings" -> {
                    try {
                        val intent = Intent(android.provider.Settings.ACTION_CAST_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(android.provider.Settings.ACTION_WIRELESS_SETTINGS)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.success(false)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val filter = IntentFilter(ACTION_PLAY_PAUSE)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(pipActionReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(pipActionReceiver, filter)
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(pipActionReceiver)
        } catch (e: Exception) {}
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (autoEnterEnabled && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)) {
                try {
                    enterPictureInPictureMode(buildPipParams(isPlaying))
                } catch (e: Exception) {}
            }
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        methodChannel?.invokeMethod("onPipModeChanged", isInPictureInPictureMode)
    }

    private fun buildPipParams(playing: Boolean): PictureInPictureParams {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            throw IllegalStateException("PiP requires Android O+")
        }
        val builder = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(16, 9))

        val iconRes = if (playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
        val title = if (playing) "Pause" else "Play"
        val intent = Intent(ACTION_PLAY_PAUSE)
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getBroadcast(this, 0, intent, flags)
        val action = RemoteAction(Icon.createWithResource(this, iconRes), title, title, pendingIntent)

        builder.setActions(listOf(action))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setAutoEnterEnabled(autoEnterEnabled)
        }
        return builder.build()
    }
}
