package io.crispice.twilio_video_advanced.twilio_video_advanced_example

import android.media.AudioManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val VOLUME_CONTROL_CHANNEL = "twilio_video_advanced/volume_control"
    private var savedVolumeControlStream = 50
    private var volumeControlStream = 50

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Cache the current volume control stream
        savedVolumeControlStream = volumeControlStream

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            VOLUME_CONTROL_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setVolumeControlStream" -> {
                    val streamType = call.argument<Int>("streamType") ?: 0
                    val enabled = call.argument<Boolean>("enabled") ?: false

                    setVolumeControlStream(streamType, enabled)
                    result.success(null)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun setVolumeControlStream(streamType: Int, enabled: Boolean) {
        volumeControlStream = if (enabled) {
            /*
             * Enable changing the volume using the up/down keys during a conversation
             * Following Twilio's best practices for audio configuration
             */
            when (streamType) {
                AudioManager.STREAM_VOICE_CALL -> AudioManager.STREAM_VOICE_CALL
                else -> streamType
            }
        } else {
            savedVolumeControlStream
        }
    }
}
