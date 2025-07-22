package io.crispice.twilio_video_advanced.twilio_video_advanced.views

import android.view.View
import io.crispice.twilio_video_advanced.twilio_video_advanced.TwilioVideoAdvancedPlugin
import io.flutter.plugin.platform.PlatformView

class LocalVideoView(
    private val plugin: TwilioVideoAdvancedPlugin,
    private val viewId: String
) : PlatformView {
    private val videoView = plugin.createLocalVideoView(viewId)

    override fun getView(): View = videoView

    override fun dispose() {
        plugin.releaseVideoView(viewId)
    }
}