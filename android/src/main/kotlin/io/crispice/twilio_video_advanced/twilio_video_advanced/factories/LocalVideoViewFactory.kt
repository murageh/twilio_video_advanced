package io.crispice.twilio_video_advanced.twilio_video_advanced.factories

import android.content.Context
import io.crispice.twilio_video_advanced.twilio_video_advanced.TwilioVideoAdvancedPlugin
import io.crispice.twilio_video_advanced.twilio_video_advanced.views.LocalVideoView
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class LocalVideoViewFactory(private val plugin: TwilioVideoAdvancedPlugin) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return LocalVideoView(plugin, viewId.toString())
    }
}