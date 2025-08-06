package io.crispice.twilio_video_advanced.twilio_video_advanced

import android.app.ActivityManager
import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CaptureRequest
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import androidx.annotation.NonNull
import com.twilio.audioswitch.AudioDevice
import com.twilio.audioswitch.AudioSwitch
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
    private lateinit var torchEventChannel: EventChannel

    private var roomEventSink: EventChannel.EventSink? = null
    private var participantEventSink: EventChannel.EventSink? = null
    private var trackEventSink: EventChannel.EventSink? = null
    private var torchEventSink: EventChannel.EventSink? = null

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

    // Torch/Flash support with actual hardware control
    private var torchAvailable = false
    private var torchEnabled = false
    private var cameraManager: CameraManager? = null
    private var torchCallback: CameraManager.TorchCallback? = null

    // Wake lock for keeping screen on during video calls
    private var wakeLock: PowerManager.WakeLock? = null
    private var isWakeLockActive = false

    // Audio manager for handling audio routing
    private var audioManager: AudioManager? = null
    private var isSpeakerPhoneEnabled = true
    private var savedVolumeControlStream = 0
    private var previousAudioMode = 0
    private var previousMicrophoneMute = false
    private var audioFocusRequest: Any? = null // AudioFocusRequest for API 26+

    // AudioSwitch for managing audio devices
    private var audioSwitch: AudioSwitch? = null
    private var isAudioSwitchStarted = false
    private var isAudioDeviceActivated = false

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext

        // Initialize camera manager for torch control
        cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager

        // Initialize wake lock for keeping screen on
        initializeWakeLock()

        // Initialize audio manager
        audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audioManager?.isSpeakerphoneOn = isSpeakerPhoneEnabled

        // Initialize AudioSwitch for managing audio devices
        audioSwitch = AudioSwitch(
            context,
            loggingEnabled = true,
            preferredDeviceList = listOf(
                AudioDevice.BluetoothHeadset::class.java,
                AudioDevice.WiredHeadset::class.java,
                AudioDevice.Speakerphone::class.java,
                AudioDevice.Earpiece::class.java,
            ),
        )

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

        torchEventChannel =
            EventChannel(flutterPluginBinding.binaryMessenger, "twilio_video_advanced/torch_events")
        torchEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                torchEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                torchEventSink = null
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
            "setLocalAudioEnabled" -> setLocalAudioEnabled(call, result)
            "setLocalVideoEnabled" -> setLocalVideoEnabled(call, result)
            "switchCamera" -> switchCamera(result)
            "isTorchAvailable" -> isTorchAvailable(result)
            "isTorchOn" -> isTorchOn(result)
            "setTorchEnabled" -> setTorchEnabled(call, result)
            "toggleTorch" -> toggleTorch(result)
            "setVideoQuality" -> setVideoQuality(call, result)
            "getDeviceCapabilities" -> getDeviceCapabilities(result)
            "getRecommendedVideoQuality" -> getRecommendedVideoQuality(result)
            // Audio device management methods
            "getAvailableAudioDevices" -> getAvailableAudioDevices(result)
            "getSelectedAudioDevice" -> getSelectedAudioDevice(result)
            "selectAudioDevice" -> selectAudioDevice(call, result)
            "startAudioDeviceListener" -> startAudioDeviceListener(result)
            "stopAudioDeviceListener" -> stopAudioDeviceListener(result)
            "activateAudioDevice" -> activateAudioDevice(result)
            "deactivateAudioDevice" -> deactivateAudioDevice(result)
            else -> result.notImplemented()
        }
    }

    private fun createCameraCapturer(): Camera2Capturer? {
        val camera2Enumerator = Camera2Enumerator(context)

        // Try front camera first
        for (cameraId in camera2Enumerator.deviceNames) {
            if (camera2Enumerator.isFrontFacing(cameraId)) {
                currentCameraId = cameraId
                isFrontCamera = true
                return Camera2Capturer(context, cameraId)
            }
        }

        // Fallback to back camera
        for (cameraId in camera2Enumerator.deviceNames) {
            if (camera2Enumerator.isBackFacing(cameraId)) {
                currentCameraId = cameraId
                isFrontCamera = false
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
                        // Configure audio for video calling when audio is published
                        configureAudioForVideoCalling()
                        // Start AudioSwitch when audio is published following Twilio's best practices
                        if (!isAudioSwitchStarted) {
                            audioSwitch?.start { audioDevices, selectedDevice ->
                                // Handle audio device changes - notify Flutter if needed
                                handler.post {
                                    // Audio device changes are handled automatically by AudioSwitch
                                    // Could emit events here if UI needs to be updated
                                }
                            }
                            isAudioSwitchStarted = true
                        }
                        // Activate audio device to route audio properly
                        if (!isAudioDeviceActivated) {
                            audioSwitch?.activate()
                            isAudioDeviceActivated = true
                        }
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
                        // Acquire wake lock when video starts to keep screen on
                        acquireWakeLock()
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
                "audio" -> {
                    localAudioTrack?.let { room?.localParticipant?.unpublishTrack(it) }
                    // Reset audio configuration when audio is unpublished
                    resetAudioConfiguration()
                    // Deactivate audio device when audio is unpublished
                    if (isAudioDeviceActivated) {
                        audioSwitch?.deactivate()
                        isAudioDeviceActivated = false
                    }
                    // Stop AudioSwitch when audio is no longer needed
                    if (isAudioSwitchStarted) {
                        audioSwitch?.stop()
                        isAudioSwitchStarted = false
                    }
                }
                "video" -> {
                    localVideoTrack?.let { room?.localParticipant?.unpublishTrack(it) }
                    // Release wake lock when video stops
                    releaseWakeLock()
                }
            }
            result.success(null)
        } catch (e: Exception) {
            result.error("UNPUBLISH_FAILED", e.message, null)
        }
    }

    private fun toggleLocalAudio(result: MethodChannel.Result) {
        localAudioTrack?.let {
            it.enable(!it.isEnabled)

            // Emit event for audio enabled state change
            handler.post {
                trackEventSink?.success(
                    mapOf(
                        "event" to "localAudioEnabled",
                        "enabled" to it.isEnabled
                    )
                )
            }

            result.success(it.isEnabled)
        } ?: result.error("NO_TRACK", "No audio track available", null)
    }

    private fun toggleLocalVideo(result: MethodChannel.Result) {
        localVideoTrack?.let {
            it.enable(!it.isEnabled)

            // Emit event for video enabled state change
            handler.post {
                trackEventSink?.success(
                    mapOf(
                        "event" to "localVideoEnabled",
                        "enabled" to it.isEnabled
                    )
                )
            }

            result.success(it.isEnabled)
        } ?: result.error("NO_TRACK", "No video track available", null)
    }

    private fun setLocalAudioEnabled(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled") ?: false

        try {
            localAudioTrack?.let {
                it.enable(enabled)

                // Emit event for audio enabled state change
                handler.post {
                    trackEventSink?.success(
                        mapOf(
                            "event" to "localAudioEnabled",
                            "enabled" to it.isEnabled
                        )
                    )
                }

                result.success(null)
            } ?: result.error("NO_TRACK", "No audio track available", null)
        } catch (e: Exception) {
            result.error("SET_AUDIO_ENABLED_FAILED", e.message, null)
        }
    }

    private fun setLocalVideoEnabled(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled") ?: false

        try {
            localVideoTrack?.let {
                it.enable(enabled)

                // Emit event for video enabled state change
                handler.post {
                    trackEventSink?.success(
                        mapOf(
                            "event" to "localVideoEnabled",
                            "enabled" to it.isEnabled
                        )
                    )
                }

                result.success(null)
            } ?: result.error("NO_TRACK", "No video track available", null)
        } catch (e: Exception) {
            result.error("SET_VIDEO_ENABLED_FAILED", e.message, null)
        }
    }

    private fun switchCamera(result: MethodChannel.Result) {
        try {
            val camera2Enumerator = Camera2Enumerator(context)
            val targetFrontFacing = !isFrontCamera

            var targetCameraId: String? = null
            for (cameraId in camera2Enumerator.deviceNames) {
                if (camera2Enumerator.isFrontFacing(cameraId) == targetFrontFacing) {
                    targetCameraId = cameraId
                    break
                }
            }

            if (targetCameraId != null && targetCameraId != currentCameraId) {
                cameraCapturer?.switchCamera(targetCameraId)
                currentCameraId = targetCameraId
                isFrontCamera = targetFrontFacing

                // Update mirroring for all local video views after camera switch
                updateAllLocalVideoViewsMirroring()

                // Check torch availability after camera switch
                updateTorchAvailability()
                result.success(null)
            } else {
                result.error(
                    "SWITCH_FAILED",
                    "No alternative camera available or already using target camera",
                    null
                )
            }
        } catch (e: Exception) {
            result.error("SWITCH_FAILED", "Failed to switch camera: ${e.message}", null)
        }
    }

    // TORCH/FLASH METHODS
    private fun isTorchAvailable(result: MethodChannel.Result) {
        updateTorchAvailability()
        result.success(torchAvailable)
    }

    private fun isTorchOn(result: MethodChannel.Result) {
        result.success(torchEnabled)
    }

    private fun setTorchEnabled(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled") ?: false

        if (torchAvailable && cameraCapturer != null) {
            try {
                torchEnabled = enabled
                // Note: Camera2Capturer doesn't have setTorchEnabled method in Twilio SDK
                // We need to implement this through the camera characteristics
                updateTorchStatus(enabled)
                result.success(enabled)
            } catch (e: Exception) {
                handler.post {
                    torchEventSink?.success(
                        mapOf(
                            "event" to "torchError",
                            "error" to "Failed to set torch: ${e.message}"
                        )
                    )
                }
                result.error("TORCH_ERROR", e.message, null)
            }
        } else {
            result.error(
                "TORCH_UNAVAILABLE",
                "Torch/Flash not available on this device or camera not initialized",
                null
            )
        }
    }

    private fun toggleTorch(result: MethodChannel.Result) {
        if (torchAvailable && cameraCapturer != null) {
            try {
                torchEnabled = !torchEnabled
                updateTorchStatus(torchEnabled)
                result.success(torchEnabled)
            } catch (e: Exception) {
                handler.post {
                    torchEventSink?.success(
                        mapOf(
                            "event" to "torchError",
                            "error" to "Failed to toggle torch: ${e.message}"
                        )
                    )
                }
                result.error("TORCH_ERROR", e.message, null)
            }
        } else {
            result.error(
                "TORCH_UNAVAILABLE",
                "Torch/Flash not available on this device or camera not initialized",
                null
            )
        }
    }

    private fun updateTorchAvailability() {
        try {
            val currentCameraId = getCurrentCameraId()

            if (currentCameraId != null) {
                // Use Android's Camera2 API to check flash availability
                torchAvailable = hasFlashSupport(currentCameraId)
            } else {
                torchAvailable = false
            }

            // Notify Flutter about torch availability
            handler.post {
                torchEventSink?.success(
                    mapOf(
                        "event" to "torchStatusChanged",
                        "isOn" to torchEnabled,
                        "isAvailable" to torchAvailable
                    )
                )
            }
        } catch (e: Exception) {
            torchAvailable = false
            handler.post {
                torchEventSink?.success(
                    mapOf(
                        "event" to "torchError",
                        "error" to "Failed to check torch availability: ${e.message}"
                    )
                )
            }
        }
    }

    private fun hasFlashSupport(cameraId: String): Boolean {
        return try {
            val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val characteristics = cameraManager.getCameraCharacteristics(cameraId)
            val flashInfo = characteristics.get(CameraCharacteristics.FLASH_INFO_AVAILABLE)
            flashInfo == true
        } catch (e: Exception) {
            false
        }
    }

    private fun getCurrentCameraId(): String? {
        if (currentCameraId != null) return currentCameraId

        val camera2Enumerator = Camera2Enumerator(context)

        // Find current camera based on front/back preference
        for (cameraId in camera2Enumerator.deviceNames) {
            if (camera2Enumerator.isFrontFacing(cameraId) == isFrontCamera) {
                currentCameraId = cameraId
                return cameraId
            }
        }

        return null
    }

    private fun updateTorchStatus(enabled: Boolean) {
        try {
            if (cameraCapturer != null) {
                // Use Twilio's updateCaptureRequest to control the torch
                val success = cameraCapturer!!.updateCaptureRequest { captureRequestBuilder ->
                    if (enabled) {
                        captureRequestBuilder.set(
                            CaptureRequest.FLASH_MODE,
                            CaptureRequest.FLASH_MODE_TORCH
                        )
                    } else {
                        captureRequestBuilder.set(
                            CaptureRequest.FLASH_MODE,
                            CaptureRequest.FLASH_MODE_OFF
                        )
                    }
                }

                if (success) {
                    torchEnabled = enabled

                    // Notify Flutter about successful torch status change
                    handler.post {
                        torchEventSink?.success(
                            mapOf(
                                "event" to "torchStatusChanged",
                                "isOn" to torchEnabled,
                                "isAvailable" to torchAvailable
                            )
                        )
                    }
                } else {
                    throw Exception("Failed to schedule torch update - another update may be pending")
                }
            } else {
                throw Exception("Camera capturer not available")
            }
        } catch (e: Exception) {
            torchEnabled = false
            handler.post {
                torchEventSink?.success(
                    mapOf(
                        "event" to "torchError",
                        "error" to "Failed to control torch: ${e.message}"
                    )
                )
            }
        }
    }

    private fun setTorch(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled") ?: false

        if (torchAvailable) {
            // Toggle the torch state
            torchEnabled = enabled
            updateTorchStatus(enabled)
            result.success(null)
        } else {
            result.error("TORCH_UNAVAILABLE", "Torch/Flash not available on this device", null)
        }
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

        // Set mirroring based on camera type - front camera should be mirrored, back camera should not
        updateVideoViewMirroring(videoView)

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
        currentCameraId = null
        // Reset to default state
        isFrontCamera = true

        // Release wake lock when cleaning up
        releaseWakeLock()

        // Reset audio configuration
        resetAudioConfiguration()

        // Stop and deactivate audio switch when cleaning up
        if (isAudioDeviceActivated) {
            audioSwitch?.deactivate()
            isAudioDeviceActivated = false
        }
        if (isAudioSwitchStarted) {
            audioSwitch?.stop()
            isAudioSwitchStarted = false
        }
    }

    // VIDEO MIRRORING METHODS
    private fun updateVideoViewMirroring(videoView: VideoView) {
        // Front camera should be mirrored (like a mirror), back camera should not be mirrored
        // isFrontCamera = true means front camera, should be mirrored = true
        // isFrontCamera = false means back camera, should not be mirrored = false
        videoView.setMirror(isFrontCamera)
    }

    private fun updateAllLocalVideoViewsMirroring() {
        // Update mirroring for all local video views when camera switches
        videoRenderers.forEach { (viewId, videoView) ->
            if (viewIdToParticipant[viewId] == "LOCAL") {
                updateVideoViewMirroring(videoView)
            }
        }
    }

    // VIDEO QUALITY MANAGEMENT METHODS
    private fun setVideoQuality(call: MethodCall, result: MethodChannel.Result) {
        val quality = call.argument<String>("quality") ?: "standard"
        val width = call.argument<Int>("width")
        val height = call.argument<Int>("height")
        val framerate = call.argument<Int>("framerate")
        val bitrate = call.argument<Int>("bitrate")

        try {
            when {
                // Custom quality with specific parameters
                width != null && height != null -> {
                    applyCustomVideoFormat(width, height, framerate ?: 30, bitrate)
                    result.success("Custom video quality applied: ${width}x${height}@${framerate ?: 30}fps")
                }
                // Preset quality levels
                else -> {
                    val format = getVideoFormatForQuality(quality)
                    applyVideoFormat(format)
                    result.success("Video quality set to $quality: ${format.width}x${format.height}@${format.framerate}fps")
                }
            }
        } catch (e: Exception) {
            result.error("QUALITY_ERROR", "Failed to set video quality: ${e.message}", null)
        }
    }

    private fun getDeviceCapabilities(result: MethodChannel.Result) {
        try {
            val activityManager =
                context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val memoryInfo = ActivityManager.MemoryInfo()
            activityManager.getMemoryInfo(memoryInfo)

            val totalMemoryMB = memoryInfo.totalMem / (1024 * 1024)
            val availableMemoryMB = memoryInfo.availMem / (1024 * 1024)

            // Get camera capabilities
            val cameraCapabilities = getCameraCapabilities()

            // Determine device tier based on specs
            val deviceTier = determineDeviceTier(totalMemoryMB, cameraCapabilities)

            val capabilities = mapOf(
                "device" to mapOf(
                    "model" to Build.MODEL,
                    "manufacturer" to Build.MANUFACTURER,
                    "sdkVersion" to Build.VERSION.SDK_INT,
                    "tier" to deviceTier
                ),
                "memory" to mapOf(
                    "totalMB" to totalMemoryMB,
                    "availableMB" to availableMemoryMB,
                    "lowMemory" to memoryInfo.lowMemory
                ),
                "camera" to cameraCapabilities,
                "video" to mapOf(
                    "supportedQualities" to getSupportedVideoQualities(deviceTier),
                    "recommendedQuality" to getRecommendedQualityForDevice(deviceTier)
                )
            )

            result.success(capabilities)
        } catch (e: Exception) {
            result.error(
                "CAPABILITIES_ERROR",
                "Failed to get device capabilities: ${e.message}",
                null
            )
        }
    }

    private fun getRecommendedVideoQuality(result: MethodChannel.Result) {
        try {
            val activityManager =
                context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val memoryInfo = ActivityManager.MemoryInfo()
            activityManager.getMemoryInfo(memoryInfo)

            val totalMemoryMB = memoryInfo.totalMem / (1024 * 1024)
            val isLowMemory = memoryInfo.lowMemory
            val cameraCapabilities = getCameraCapabilities()

            val deviceTier = determineDeviceTier(totalMemoryMB, cameraCapabilities)
            val recommendedQuality = getRecommendedQualityForDevice(deviceTier, isLowMemory)

            result.success(
                mapOf(
                    "quality" to recommendedQuality,
                    "deviceTier" to deviceTier,
                    "reason" to getQualityRecommendationReason(deviceTier, isLowMemory)
                )
            )
        } catch (e: Exception) {
            result.error(
                "RECOMMENDATION_ERROR",
                "Failed to get recommended quality: ${e.message}",
                null
            )
        }
    }

    private fun getCameraCapabilities(): Map<String, Any> {
        return try {
            Camera2Enumerator(context)
            val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager

            val capabilities = mutableMapOf<String, Any>()
            val supportedFormats = mutableListOf<Map<String, Any>>()

            // Get capabilities for current camera
            currentCameraId?.let { cameraId ->
                val characteristics = cameraManager.getCameraCharacteristics(cameraId)
                val streamConfigMap =
                    characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)

                streamConfigMap?.let { configMap ->
                    val outputSizes =
                        configMap.getOutputSizes(android.graphics.ImageFormat.YUV_420_888)
                    outputSizes?.forEach { size ->
                        supportedFormats.add(
                            mapOf(
                                "width" to size.width,
                                "height" to size.height
                            )
                        )
                    }
                }

                capabilities["maxResolution"] = supportedFormats.maxByOrNull {
                    (it["width"] as Int) * (it["height"] as Int)
                } ?: mapOf("width" to 1280, "height" to 720)
            }

            capabilities["supportedFormats"] = supportedFormats
            capabilities["frontCamera"] = isFrontCamera
            capabilities
        } catch (e: Exception) {
            mapOf(
                "supportedFormats" to listOf<Map<String, Any>>(),
                "maxResolution" to mapOf("width" to 1280, "height" to 720),
                "frontCamera" to isFrontCamera
            )
        }
    }

    private fun determineDeviceTier(
        totalMemoryMB: Long,
        cameraCapabilities: Map<String, Any>
    ): String {
        val maxRes = cameraCapabilities["maxResolution"] as? Map<String, Any>
        val maxWidth = maxRes?.get("width") as? Int ?: 1280
        val maxHeight = maxRes?.get("height") as? Int ?: 720
        val maxPixels = maxWidth * maxHeight

        return when {
            totalMemoryMB >= 6000 && maxPixels >= 1920 * 1080 -> "high"
            totalMemoryMB >= 3000 && maxPixels >= 1280 * 720 -> "medium"
            else -> "low"
        }
    }

    private fun getSupportedVideoQualities(deviceTier: String): List<String> {
        return when (deviceTier) {
            "high" -> listOf("low", "standard", "high", "ultra")
            "medium" -> listOf("low", "standard", "high")
            else -> listOf("low", "standard")
        }
    }

    private fun getRecommendedQualityForDevice(
        deviceTier: String,
        isLowMemory: Boolean = false
    ): String {
        return when {
            isLowMemory -> "low"
            deviceTier == "high" -> "high"
            deviceTier == "medium" -> "standard"
            else -> "low"
        }
    }

    private fun getQualityRecommendationReason(deviceTier: String, isLowMemory: Boolean): String {
        return when {
            isLowMemory -> "Low memory detected, using low quality to maintain performance"
            deviceTier == "high" -> "High-end device detected, can handle high quality video"
            deviceTier == "medium" -> "Mid-range device detected, using standard quality for balance"
            else -> "Lower-end device detected, using low quality to ensure smooth performance"
        }
    }

    private fun getVideoFormatForQuality(quality: String): VideoFormat {
        return when (quality) {
            "low" -> VideoFormat(640, 480, 15)
            "standard" -> VideoFormat(1280, 720, 30)
            "high" -> VideoFormat(1920, 1080, 30)
            "ultra" -> VideoFormat(1920, 1080, 60)
            else -> VideoFormat(1280, 720, 30)
        }
    }

    private fun applyVideoFormat(format: VideoFormat) {
        // This would require recreating the video track with new constraints
        // For now, this is a placeholder - actual implementation depends on Twilio SDK capabilities
        videoRenderers.forEach { (viewId, videoView) ->
            if (viewIdToParticipant[viewId] == "LOCAL") {
                // Apply video scale type based on quality
                when (format.quality) {
                    "high", "ultra" -> videoView.setVideoScaleType(VideoScaleType.ASPECT_FILL)
                    else -> videoView.setVideoScaleType(VideoScaleType.ASPECT_FIT)
                }
            }
        }
    }

    private fun applyCustomVideoFormat(width: Int, height: Int, framerate: Int, bitrate: Int?) {
        val customFormat = VideoFormat(width, height, framerate, bitrate)
        applyVideoFormat(customFormat)
    }

    // Data class for video format configuration
    data class VideoFormat(
        val width: Int,
        val height: Int,
        val framerate: Int,
        val bitrate: Int? = null
    ) {
        val quality: String
            get() = when {
                width >= 1920 && height >= 1080 && framerate >= 60 -> "ultra"
                width >= 1920 && height >= 1080 -> "high"
                width >= 1280 && height >= 720 -> "standard"
                else -> "low"
            }
    }

    // WAKE LOCK MANAGEMENT
    private fun initializeWakeLock() {
        try {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "TwilioVideoAdvanced::WakeLock"
            ).apply {
                setReferenceCounted(false)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun acquireWakeLock() {
        try {
            if (wakeLock != null && !isWakeLockActive) {
                wakeLock?.acquire(60 * 60 * 1000L /*60 minutes*/)
                isWakeLockActive = true
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock != null && isWakeLockActive) {
                wakeLock?.release()
                isWakeLockActive = false
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    // AUDIO MANAGEMENT FOR TELEMEDICINE/VIDEO CALLING
    // Following Twilio's best practices for audio configuration
    private fun configureAudioForVideoCalling() {
        try {
            audioManager?.let { am ->
                // Save current audio state
                previousAudioMode = am.mode

                // Request audio focus before making any device switch
                requestAudioFocus()

                /*
                 * Use MODE_IN_COMMUNICATION as the default audio mode. It is required
                 * to be in this mode when playout and/or recording starts for the best
                 * possible VoIP performance. Some devices have difficulties with
                 * speaker mode if this is not set.
                 */
                am.mode = AudioManager.MODE_IN_COMMUNICATION

                /*
                 * Always disable microphone mute during a WebRTC call.
                 */
                previousMicrophoneMute = am.isMicrophoneMute
                am.isMicrophoneMute = false

                /*
                 * Enable changing the volume using the up/down keys during a conversation
                 */
                setVolumeControl(true)
            }
        } catch (e: Exception) {
            // Log but don't fail - audio configuration is enhancement, not critical
            e.printStackTrace()
        }
    }

    private fun resetAudioConfiguration() {
        try {
            audioManager?.let { am ->
                // Reset to previous mode when not in video call
                am.mode = previousAudioMode

                // Abandon audio focus
                abandonAudioFocus()

                am.isMicrophoneMute = previousMicrophoneMute

                // Reset volume control
                setVolumeControl(false)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun requestAudioFocus() {
        try {
            audioManager?.let { am ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val playbackAttributes = android.media.AudioAttributes.Builder()
                        .setUsage(android.media.AudioAttributes.USAGE_VOICE_COMMUNICATION)
                        .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                    val focusRequest = android.media.AudioFocusRequest.Builder(
                        AudioManager.AUDIOFOCUS_GAIN_TRANSIENT
                    )
                        .setAudioAttributes(playbackAttributes)
                        .setAcceptsDelayedFocusGain(true)
                        .setOnAudioFocusChangeListener { }
                        .build()
                    am.requestAudioFocus(focusRequest)
                    audioFocusRequest = focusRequest // Save the request for later use
                } else {
                    @Suppress("DEPRECATION")
                    am.requestAudioFocus(
                        null,
                        AudioManager.STREAM_VOICE_CALL,
                        AudioManager.AUDIOFOCUS_GAIN_TRANSIENT
                    )
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun abandonAudioFocus() {
        try {
            audioManager?.let { am ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    // Note: In a full implementation, you'd store the focusRequest
                    // and call am.abandonAudioFocusRequest(focusRequest) here
                    @Suppress("DEPRECATION")
                    am.abandonAudioFocus(null)
                } else {
                    @Suppress("DEPRECATION")
                    am.abandonAudioFocus(null)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun setVolumeControl(enable: Boolean) {
        try {
            if (enable) {
                /*
                 * Enable changing the volume using the up/down keys during a conversation
                 */
                savedVolumeControlStream = 50 // This would typically be set on the Activity
                // Note: Volume control stream should be set on the Activity level
                // savedVolumeControlStream = AudioManager.STREAM_VOICE_CALL
            } else {
                // Reset volume control stream
                // This would be handled at the Activity level
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    // AUDIO DEVICE MANAGEMENT METHODS
    private fun getAvailableAudioDevices(result: MethodChannel.Result) {
        try {
            // Get the list of available audio devices
            val devices = audioSwitch?.availableAudioDevices?.map { device ->
                mapOf(
                    "name" to device.name,
                    "type" to when (device) {
                        is AudioDevice.BluetoothHeadset -> "BluetoothHeadset"
                        is AudioDevice.WiredHeadset -> "WiredHeadset"
                        is AudioDevice.Earpiece -> "Earpiece"
                        is AudioDevice.Speakerphone -> "Speakerphone"
                        else -> "Unknown"
                    }
                )
            } ?: emptyList()

            result.success(devices)
        } catch (e: Exception) {
            result.error("AUDIO_DEVICES_ERROR", "Failed to get audio devices: ${e.message}", null)
        }
    }

    private fun getSelectedAudioDevice(result: MethodChannel.Result) {
        try {
            // Get the currently selected audio device
            val selectedDevice = audioSwitch?.selectedAudioDevice

            result.success(
                selectedDevice?.let { device ->
                    mapOf(
                        "name" to device.name,
                        "type" to when (device) {
                            is AudioDevice.BluetoothHeadset -> "BluetoothHeadset"
                            is AudioDevice.WiredHeadset -> "WiredHeadset"
                            is AudioDevice.Earpiece -> "Earpiece"
                            is AudioDevice.Speakerphone -> "Speakerphone"
                            else -> "Unknown"
                        }
                    )
                }
            )
        } catch (e: Exception) {
            result.error(
                "SELECTED_AUDIO_DEVICE_ERROR",
                "Failed to get selected audio device: ${e.message}",
                null
            )
        }
    }

    private fun selectAudioDevice(call: MethodCall, result: MethodChannel.Result) {
        val deviceName = call.argument<String>("deviceName") ?: return result.error(
            "INVALID_ARGUMENT",
            "Device name is required",
            null
        )

        try {
            // Find and select the audio device by name
            val targetDevice = audioSwitch?.availableAudioDevices?.find { it.name == deviceName }
            if (targetDevice != null) {
                audioSwitch?.selectDevice(targetDevice)

                // start it
                audioSwitch?.activate()

                result.success(null)
            } else {
                result.error(
                    "DEVICE_NOT_FOUND",
                    "Audio device with name '$deviceName' not found",
                    null
                )
            }
        } catch (e: Exception) {
            result.error(
                "SELECT_AUDIO_DEVICE_ERROR",
                "Failed to select audio device: ${e.message}",
                null
            )
        }
    }

    private fun startAudioDeviceListener(result: MethodChannel.Result) {
        try {
            if (!isAudioSwitchStarted) {
                audioSwitch?.start { audioDevices, selectedDevice ->
                    // Handle audio device changes
                    handler.post {
                        // You could emit these changes via an event channel if needed
                        // For now, we just update internal state
                    }
                }
                isAudioSwitchStarted = true
            }
            result.success(null)
        } catch (e: Exception) {
            result.error(
                "START_AUDIO_DEVICE_LISTENER_ERROR",
                "Failed to start audio device listener: ${e.message}",
                null
            )
        }
    }

    private fun stopAudioDeviceListener(result: MethodChannel.Result) {
        try {
            if (isAudioSwitchStarted) {
                audioSwitch?.stop()
                isAudioSwitchStarted = false
            }
            result.success(null)
        } catch (e: Exception) {
            result.error(
                "STOP_AUDIO_DEVICE_LISTENER_ERROR",
                "Failed to stop audio device listener: ${e.message}",
                null
            )
        }
    }

    private fun activateAudioDevice(result: MethodChannel.Result) {
        try {
            // Check if AudioSwitch is started first
            if (!isAudioSwitchStarted) {
                // Start AudioSwitch if not already started
                audioSwitch?.start { audioDevices, selectedDevice ->
                    audioManager?.isSpeakerphoneOn = selectedDevice is AudioDevice.Speakerphone
                    // Handle audio device changes
                    handler.post {
                        // Emit audio device change events to Flutter
                        try {
                            trackEventSink?.success(
                                mapOf(
                                    "event" to "audioDeviceChanged",
                                    "availableDevices" to audioDevices.map { device ->
                                        mapOf(
                                            "name" to device.name,
                                            "type" to when (device) {
                                                is AudioDevice.BluetoothHeadset -> "BluetoothHeadset"
                                                is AudioDevice.WiredHeadset -> "WiredHeadset"
                                                is AudioDevice.Earpiece -> "Earpiece"
                                                is AudioDevice.Speakerphone -> "Speakerphone"
                                                else -> "Unknown"
                                            }
                                        )
                                    },
                                    "selectedDevice" to selectedDevice?.let { device ->
                                        mapOf(
                                            "name" to device.name,
                                            "type" to when (device) {
                                                is AudioDevice.BluetoothHeadset -> "BluetoothHeadset"
                                                is AudioDevice.WiredHeadset -> "WiredHeadset"
                                                is AudioDevice.Earpiece -> "Earpiece"
                                                is AudioDevice.Speakerphone -> "Speakerphone"
                                                else -> "Unknown"
                                            }
                                        )
                                    }
                                )
                            )
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                    }
                }
                isAudioSwitchStarted = true
            }

            // Now activate the audio device
            audioSwitch?.activate()
            isAudioDeviceActivated = true
            result.success(null)
        } catch (e: Exception) {
            result.error(
                "ACTIVATE_AUDIO_DEVICE_ERROR",
                "Failed to activate audio device: ${e.message}",
                null
            )
        }
    }

    private fun deactivateAudioDevice(result: MethodChannel.Result) {
        try {
            // Only deactivate if currently activated
            if (isAudioDeviceActivated) {
                audioSwitch?.deactivate()
                isAudioDeviceActivated = false
            }
            result.success(null)
        } catch (e: Exception) {
            // Log the warning but don't fail - this is common with Bluetooth devices
            println("AudioSwitch deactivation warning: ${e.message}")

            // Still mark as deactivated since the operation was attempted
            isAudioDeviceActivated = false
            result.success(null)
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        roomEventChannel.setStreamHandler(null)
        participantEventChannel.setStreamHandler(null)
        trackEventChannel.setStreamHandler(null)
        // Reset audio configuration when plugin is detached
        resetAudioConfiguration()
        cleanupTracks()
    }
}
