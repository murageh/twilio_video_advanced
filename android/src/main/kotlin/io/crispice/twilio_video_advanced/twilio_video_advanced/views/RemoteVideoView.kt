package io.crispice.twilio_video_advanced.twilio_video_advanced.views

import android.view.View
import io.crispice.twilio_video_advanced.twilio_video_advanced.TwilioVideoAdvancedPlugin
import io.flutter.plugin.platform.PlatformView

class RemoteVideoView(
    private val plugin: TwilioVideoAdvancedPlugin,
    private val viewId: String,
    private val participantSid: String
) : PlatformView {
    private val videoView = plugin.createRemoteVideoView(viewId, participantSid)

    override fun getView(): View = videoView

    override fun dispose() {
        plugin.releaseVideoView(viewId)
    }
}
