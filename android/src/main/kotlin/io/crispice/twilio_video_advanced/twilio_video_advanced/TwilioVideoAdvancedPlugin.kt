package io.crispice.twilio_video_advanced.twilio_video_advanced

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import com.twilio.video.*
import io.crispice.twilio_video_advanced.twilio_video_advanced.factories.LocalVideoViewFactory
import io.crispice.twilio_video_advanced.twilio_video_advanced.factories.RemoteVideoViewFactory
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import tvi.webrtc.Camera2Enumerator

class TwilioVideoAdvancedPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var methodChannel: MethodChannel
    private lateinit var roomEventChannel: EventChannel
    private lateinit var participantEventChannel: EventChannel
    private lateinit var trackEventChannel: EventChannel

    private var roomEventSink: EventChannel.EventSink? = null
    private var participantEventSink: EventChannel.EventSink? = null
    private var trackEventSink: EventChannel.EventSink? = null

    private lateinit var context: Context
    private val handler = Handler(Looper.getMainLooper())

    // Twilio Video objects
    private var room: Room? = null
    private var localAudioTrack: LocalAudioTrack? = null
    private var localVideoTrack: LocalVideoTrack? = null
    private var cameraCapturer: Camera2Capturer? = null
    private var currentCameraId: String? = null
    private var isFrontCamera = true
    private val videoRenderers = mutableMapOf<String, VideoView>()
    private val participantToViewId =
        mutableMapOf<String, String>() // Track participant -> viewId mapping
    private val viewIdToParticipant =
        mutableMapOf<String, String>() // Track viewId -> participant mapping

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext

        methodChannel =
            MethodChannel(flutterPluginBinding.binaryMessenger, "twilio_video_advanced/methods")
        methodChannel.setMethodCallHandler(this)

        roomEventChannel =
            EventChannel(flutterPluginBinding.binaryMessenger, "twilio_video_advanced/room_events")
        roomEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                roomEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                roomEventSink = null
            }
        })

        participantEventChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "twilio_video_advanced/participant_events"
        )
        participantEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                participantEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                participantEventSink = null
            }
        })

        trackEventChannel =
            EventChannel(flutterPluginBinding.binaryMessenger, "twilio_video_advanced/track_events")
        trackEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                trackEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                trackEventSink = null
            }
        })

        // Register platform view factories for video rendering
        flutterPluginBinding.platformViewRegistry.registerViewFactory(
            "twilio_local_video_view",
            LocalVideoViewFactory(this)
        )

        flutterPluginBinding.platformViewRegistry.registerViewFactory(
            "twilio_remote_video_view",
            RemoteVideoViewFactory(this)
        )
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        when (call.method) {
            "connectToRoom" -> connectToRoom(call, result)
            "disconnect" -> disconnect(result)
            "publishTrack" -> publishTrack(call, result)
            "unpublishTrack" -> unpublishTrack(call, result)
            "toggleLocalAudio" -> toggleLocalAudio(result)
            "toggleLocalVideo" -> toggleLocalVideo(result)
            "switchCamera" -> switchCamera(result)
            else -> result.notImplemented()
        }
    }

    private fun createCameraCapturer(): Camera2Capturer? {
        val camera2Enumerator = Camera2Enumerator(context)

        // Try front camera first
        for (cameraId in camera2Enumerator.deviceNames) {
            if (camera2Enumerator.isFrontFacing(cameraId)) {
                return Camera2Capturer(context, cameraId)
            }
        }

        // Fallback to back camera
        for (cameraId in camera2Enumerator.deviceNames) {
            if (camera2Enumerator.isBackFacing(cameraId)) {
                return Camera2Capturer(context, cameraId)
            }
        }

        return null
    }

    private fun connectToRoom(call: MethodCall, result: MethodChannel.Result) {
        val roomName = call.argument<String>("roomName")!!
        val accessToken = call.argument<String>("accessToken")!!
        val enableAudio = call.argument<Boolean>("enableAudio") ?: false
        val enableVideo = call.argument<Boolean>("enableVideo") ?: false
        val enableDominantSpeaker = call.argument<Boolean>("enableDominantSpeaker") ?: true
        val enableAutomaticSubscription =
            call.argument<Boolean>("enableAutomaticSubscription") ?: true

        try {
            // Create tracks but don't add them if disabled (observer mode)
            val audioTracks = mutableListOf<LocalAudioTrack>()
            val videoTracks = mutableListOf<LocalVideoTrack>()

            // Always create tracks for later use, but only add if enabled
            localAudioTrack = LocalAudioTrack.create(context, enableAudio, "audio")
            if (enableAudio) {
                localAudioTrack?.let { audioTracks.add(it) }
            }

            if (enableVideo) {
                cameraCapturer = createCameraCapturer()
                if (cameraCapturer != null) {
                    localVideoTrack =
                        LocalVideoTrack.create(context, enableVideo, cameraCapturer!!, "video")
                    localVideoTrack?.let { videoTracks.add(it) }
                }
            }

            val connectOptions = ConnectOptions.Builder(accessToken)
                .roomName(roomName)
                .audioTracks(audioTracks)
                .videoTracks(videoTracks)
                .enableDominantSpeaker(enableDominantSpeaker)
                .enableAutomaticSubscription(enableAutomaticSubscription)
                .build()

            room = Video.connect(context, connectOptions, roomListener)
            result.success(null)

        } catch (e: Exception) {
            result.error("CONNECT_FAILED", e.message, null)
        }
    }

    private fun disconnect(result: MethodChannel.Result) {
        room?.disconnect()
        cleanupTracks()
        result.success(null)
    }

    private fun publishTrack(call: MethodCall, result: MethodChannel.Result) {
        val trackType = call.argument<String>("trackType")!!

        try {
            when (trackType) {
                "audio" -> {
                    if (localAudioTrack == null) {
                        localAudioTrack = LocalAudioTrack.create(context, true, "audio")
                    }
                    localAudioTrack?.let {
                        room?.localParticipant?.publishTrack(it)
                    }
                }

                "video" -> {
                    if (localVideoTrack == null) {
                        cameraCapturer = createCameraCapturer()
                        if (cameraCapturer != null) {
                            localVideoTrack =
                                LocalVideoTrack.create(context, true, cameraCapturer!!, "video")
                        }
                    }
                    localVideoTrack?.let {
                        room?.localParticipant?.publishTrack(it)
                    }
                }
            }
            result.success(null)
        } catch (e: Exception) {
            result.error("PUBLISH_FAILED", e.message, null)
        }
    }

    private fun unpublishTrack(call: MethodCall, result: MethodChannel.Result) {
        val trackType = call.argument<String>("trackType")!!

        try {
            when (trackType) {
                "audio" -> localAudioTrack?.let { room?.localParticipant?.unpublishTrack(it) }
                "video" -> localVideoTrack?.let { room?.localParticipant?.unpublishTrack(it) }
            }
            result.success(null)
        } catch (e: Exception) {
            result.error("UNPUBLISH_FAILED", e.message, null)
        }
    }

    private fun toggleLocalAudio(result: MethodChannel.Result) {
        localAudioTrack?.let {
            it.enable(!it.isEnabled)
            result.success(it.isEnabled)
        } ?: result.error("NO_TRACK", "No audio track available", null)
    }

    private fun toggleLocalVideo(result: MethodChannel.Result) {
        localVideoTrack?.let {
            it.enable(!it.isEnabled)
            result.success(it.isEnabled)
        } ?: result.error("NO_TRACK", "No video track available", null)
    }

    private fun switchCamera(result: MethodChannel.Result) {
        val camera2Enumerator = Camera2Enumerator(context)
        val targetFrontFacing = !isFrontCamera

        for (cameraId in camera2Enumerator.deviceNames) {
            if (camera2Enumerator.isFrontFacing(cameraId) == targetFrontFacing) {
                cameraCapturer?.switchCamera(cameraId)
                currentCameraId = cameraId
                isFrontCamera = targetFrontFacing
                break
            }
        }
        result.success(null)
    }

    private val roomListener = object : Room.Listener {
        override fun onConnected(room: Room) {
            // Add listeners for existing participants
            room.remoteParticipants.forEach { participant ->
                participant.setListener(remoteParticipantListener)
            }

            handler.post {
                roomEventSink?.success(
                    mapOf(
                        "event" to "connected",
                        "room" to mapRoom(room)
                    )
                )
            }
        }

        override fun onDisconnected(room: Room, twilioException: TwilioException?) {
            handler.post {
                roomEventSink?.success(
                    mapOf(
                        "event" to "disconnected",
                        "room" to mapRoom(room),
                        "error" to twilioException?.message
                    )
                )
            }
            cleanupTracks()
        }

        override fun onParticipantConnected(room: Room, participant: RemoteParticipant) {
            participant.setListener(remoteParticipantListener)
            handler.post {
                participantEventSink?.success(
                    mapOf(
                        "event" to "participantConnected",
                        "participant" to mapRemoteParticipant(participant)
                    )
                )
            }
        }

        override fun onParticipantDisconnected(room: Room, participant: RemoteParticipant) {
            handler.post {
                participantEventSink?.success(
                    mapOf(
                        "event" to "participantDisconnected",
                        "participant" to mapRemoteParticipant(participant)
                    )
                )
            }
        }

        override fun onDominantSpeakerChanged(room: Room, participant: RemoteParticipant?) {
            handler.post {
                participantEventSink?.success(
                    mapOf(
                        "event" to "dominantSpeakerChanged",
                        "participant" to if (participant != null) mapRemoteParticipant(participant) else null
                    )
                )
            }
        }

        override fun onConnectFailure(room: Room, twilioException: TwilioException) {
            handler.post {
                roomEventSink?.success(
                    mapOf(
                        "event" to "connectFailure",
                        "error" to twilioException.message
                    )
                )
            }
        }

        override fun onReconnected(room: Room) {
            handler.post {
                roomEventSink?.success(
                    mapOf(
                        "event" to "reconnected",
                        "room" to mapRoom(room)
                    )
                )
            }
        }

        override fun onReconnecting(room: Room, twilioException: TwilioException) {
            handler.post {
                roomEventSink?.success(
                    mapOf(
                        "event" to "reconnecting",
                        "room" to mapRoom(room),
                        "error" to twilioException.message
                    )
                )
            }
        }

        override fun onRecordingStarted(room: Room) {}
        override fun onRecordingStopped(room: Room) {}
    }

    private val remoteParticipantListener = object : RemoteParticipant.Listener {
        override fun onVideoTrackSubscribed(
            participant: RemoteParticipant,
            publication: RemoteVideoTrackPublication,
            track: RemoteVideoTrack
        ) {
            // Attach to existing video views
            attachVideoTrack(participant.sid, track)

            // Notify Flutter about the subscription
            handler.post {
                trackEventSink?.success(
                    mapOf(
                        "event" to "trackSubscribed",
                        "participantSid" to participant.sid,
                        "trackSid" to track.sid,
                        "trackType" to "video"
                    )
                )
            }
        }

        override fun onVideoTrackSubscriptionFailed(
            remoteParticipant: RemoteParticipant,
            remoteVideoTrackPublication: RemoteVideoTrackPublication,
            twilioException: TwilioException
        ) {
        }

        override fun onVideoTrackUnsubscribed(
            participant: RemoteParticipant,
            publication: RemoteVideoTrackPublication,
            track: RemoteVideoTrack
        ) {
            handler.post {
                trackEventSink?.success(
                    mapOf(
                        "event" to "trackUnsubscribed",
                        "participantSid" to participant.sid,
                        "trackSid" to track.sid,
                        "trackType" to "video"
                    )
                )
            }
        }

        override fun onDataTrackPublished(
            remoteParticipant: RemoteParticipant,
            remoteDataTrackPublication: RemoteDataTrackPublication
        ) {
        }

        override fun onDataTrackUnpublished(
            remoteParticipant: RemoteParticipant,
            remoteDataTrackPublication: RemoteDataTrackPublication
        ) {
        }

        override fun onDataTrackSubscribed(
            remoteParticipant: RemoteParticipant,
            remoteDataTrackPublication: RemoteDataTrackPublication,
            remoteDataTrack: RemoteDataTrack
        ) {
        }

        override fun onDataTrackSubscriptionFailed(
            remoteParticipant: RemoteParticipant,
            remoteDataTrackPublication: RemoteDataTrackPublication,
            twilioException: TwilioException
        ) {
        }

        override fun onDataTrackUnsubscribed(
            remoteParticipant: RemoteParticipant,
            remoteDataTrackPublication: RemoteDataTrackPublication,
            remoteDataTrack: RemoteDataTrack
        ) {
        }

        override fun onAudioTrackPublished(
            remoteParticipant: RemoteParticipant,
            remoteAudioTrackPublication: RemoteAudioTrackPublication
        ) {
        }

        override fun onAudioTrackUnpublished(
            remoteParticipant: RemoteParticipant,
            remoteAudioTrackPublication: RemoteAudioTrackPublication
        ) {
        }

        override fun onAudioTrackSubscribed(
            remoteParticipant: RemoteParticipant,
            remoteAudioTrackPublication: RemoteAudioTrackPublication,
            remoteAudioTrack: RemoteAudioTrack
        ) {
        }

        override fun onAudioTrackSubscriptionFailed(
            remoteParticipant: RemoteParticipant,
            remoteAudioTrackPublication: RemoteAudioTrackPublication,
            twilioException: TwilioException
        ) {
        }

        override fun onAudioTrackUnsubscribed(
            remoteParticipant: RemoteParticipant,
            remoteAudioTrackPublication: RemoteAudioTrackPublication,
            remoteAudioTrack: RemoteAudioTrack
        ) {
        }

        override fun onVideoTrackPublished(
            remoteParticipant: RemoteParticipant,
            remoteVideoTrackPublication: RemoteVideoTrackPublication
        ) {
        }

        override fun onVideoTrackUnpublished(
            remoteParticipant: RemoteParticipant,
            remoteVideoTrackPublication: RemoteVideoTrackPublication
        ) {
        }

        override fun onVideoTrackEnabled(
            participant: RemoteParticipant,
            publication: RemoteVideoTrackPublication
        ) {
        }

        override fun onVideoTrackDisabled(
            participant: RemoteParticipant,
            publication: RemoteVideoTrackPublication
        ) {
        }

        override fun onAudioTrackEnabled(
            participant: RemoteParticipant,
            publication: RemoteAudioTrackPublication
        ) {
        }

        override fun onAudioTrackDisabled(
            participant: RemoteParticipant,
            publication: RemoteAudioTrackPublication
        ) {
        }
    }

    private fun mapRoom(room: Room): Map<String, Any?> = mapOf(
        "name" to room.name,
        "sid" to room.sid,
        "state" to room.state.ordinal,
        "localParticipant" to room.localParticipant?.let { mapLocalParticipant(it) },
        "remoteParticipants" to room.remoteParticipants.map { mapRemoteParticipant(it) }
    )

    private fun mapLocalParticipant(participant: LocalParticipant): Map<String, Any?> = mapOf(
        "identity" to participant.identity,
        "sid" to participant.sid,
        "isAudioEnabled" to (localAudioTrack?.isEnabled ?: false),
        "isVideoEnabled" to (localVideoTrack?.isEnabled ?: false),
        "isAudioPublished" to (localAudioTrack != null && participant.localAudioTracks.isNotEmpty()),
        "isVideoPublished" to (localVideoTrack != null && participant.localVideoTracks.isNotEmpty())
    )

    private fun mapRemoteParticipant(participant: RemoteParticipant): Map<String, Any?> = mapOf(
        "identity" to participant.identity,
        "sid" to participant.sid,
        "isConnected" to (participant.state == Participant.State.CONNECTED)
    )

    // Add video renderer management
    fun createLocalVideoView(viewId: String): VideoView {
        val videoView = VideoView(context)
        localVideoTrack?.addSink(videoView)
        videoRenderers[viewId] = videoView
        // Mark this as local video view
        viewIdToParticipant[viewId] = "LOCAL"
        return videoView
    }

    fun createRemoteVideoView(viewId: String, participantSid: String): VideoView {
        val videoView = VideoView(context)

        // Store the mapping
        participantToViewId[participantSid] = viewId
        viewIdToParticipant[viewId] = participantSid
        videoRenderers[viewId] = videoView

        // Try immediate attachment if track is already available
        room?.remoteParticipants?.find { it.sid == participantSid }?.let { participant ->
            participant.remoteVideoTracks.firstOrNull()?.remoteVideoTrack?.addSink(videoView)
        }

        return videoView
    }

    // Fixed method to only attach to the correct participant's video view
    fun attachVideoTrack(participantSid: String, track: RemoteVideoTrack) {
        // Only attach to the specific participant's video view
        participantToViewId[participantSid]?.let { viewId ->
            videoRenderers[viewId]?.let { videoView ->
                track.addSink(videoView)
            }
        }
    }

    fun releaseVideoView(viewId: String) {
        val participantSid = viewIdToParticipant[viewId]

        // Clean up mappings
        viewIdToParticipant.remove(viewId)
        participantSid?.let {
            if (it != "LOCAL") {
                participantToViewId.remove(it)
            }
        }

        videoRenderers.remove(viewId)?.release()
    }

    private fun cleanupTracks() {
        localAudioTrack?.release()
        localVideoTrack?.release()
        cameraCapturer?.stopCapture()
        localAudioTrack = null
        localVideoTrack = null
        cameraCapturer = null
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        roomEventChannel.setStreamHandler(null)
        participantEventChannel.setStreamHandler(null)
        trackEventChannel.setStreamHandler(null)
        cleanupTracks()
    }
}
