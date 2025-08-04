import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'TwilioAdvancedException.dart';
import 'events/TwilioEvent.dart';
import 'models/remote_participant.dart';
import 'models/room.dart';
import 'utils/permission_helper.dart';

export 'utils/permission_helper.dart';
export 'widgets/twilio_local_video_view.dart';
export 'widgets/twilio_participants_grid.dart';
export 'widgets/twilio_remote_video_view.dart';
export 'widgets/twilio_video_call_screen.dart';

/// An advanced Flutter plugin for Twilio Video that provides comprehensive video calling functionality
/// with support for observer mode, broadcasting controls, enhanced UI components, and camera flash/torch control.
///
/// ## Features
///
/// - 🎥 **Observer Mode**: Join rooms without broadcasting to watch others
/// - 📺 **Go Live**: Start/stop video and audio broadcasting independently
/// - 🎛️ **Advanced Controls**: Toggle camera, microphone, switch cameras
/// - 🔦 **Flash/Torch Control**: Toggle camera flash for better lighting during video calls
/// - 🎨 **Enhanced UI**: Picture-in-Picture, dominant speaker detection, grid layouts
/// - 🔄 **Auto-reconnection**: Robust connection handling with reconnection support
/// - 📱 **Platform Views**: Native video rendering for optimal performance
/// - 🎚️ **Video Quality Management**: Adaptive quality based on device capabilities
/// - 🔒 **Permission Handling**: Automatic permission management for camera and microphone
/// - ⚡ **Wake Lock**: Keeps screen on during video calls for better user experience
///
/// ## Basic Usage
///
/// ```dart
/// final _twilio = TwilioVideoAdvanced.instance;
///
/// // Join room in observer mode (no broadcasting initially)
/// await _twilio.connectToRoom(
///   roomName: 'my-room',
///   accessToken: 'your-access-token',
///   enableAudio: false, // Observer mode
///   enableVideo: false, // Observer mode
/// );
///
/// // Start broadcasting when ready
/// await _twilio.publishLocalVideo();
/// await _twilio.publishLocalAudio();
///
/// // Control flash/torch
/// bool isAvailable = await _twilio.isTorchAvailable();
/// if (isAvailable) {
///   await _twilio.toggleTorch();
/// }
/// ```
class TwilioVideoAdvanced {
  static const _methodChannel = MethodChannel('twilio_video_advanced/methods');
  static const _roomEventChannel = EventChannel(
    'twilio_video_advanced/room_events',
  );
  static const _participantEventChannel = EventChannel(
    'twilio_video_advanced/participant_events',
  );
  static const _trackEventChannel = EventChannel(
    'twilio_video_advanced/track_events',
  );
  static const _torchEventChannel = EventChannel(
    'twilio_video_advanced/torch_events',
  );

  static TwilioVideoAdvanced? _instance;

  /// Singleton instance of the TwilioVideoAdvanced plugin.
  ///
  /// Use this instance to access all plugin functionality:
  /// ```dart
  /// final twilio = TwilioVideoAdvanced.instance;
  /// ```
  static TwilioVideoAdvanced get instance =>
      _instance ??= TwilioVideoAdvanced._();

  /// The currently connected room, if any.
  ///
  /// Returns `null` if not connected to any room.
  Room? _currentRoom;

  Room? get currentRoom => _currentRoom;

  /// Stream of all Twilio Video events.
  ///
  /// Listen to this stream to handle room events, participant events, track events, and torch events:
  /// ```dart
  /// _twilio.eventStream.listen((event) {
  ///   if (event is RoomConnectedEvent) {
  ///     // Handle room connected
  ///   } else if (event is TorchStatusChangedEvent) {
  ///     // Handle torch status change
  ///   }
  /// });
  /// ```
  StreamController<TwilioEvent>? _eventController;

  Stream<TwilioEvent> get eventStream {
    _eventController ??= StreamController<TwilioEvent>.broadcast();
    _initializeStreams(); // Only call once
    return _eventController!.stream;
  }

  bool _streamsInitialized = false;

  void _initializeStreams() {
    if (_streamsInitialized) return;
    _streamsInitialized = true;

    _roomEventChannel.receiveBroadcastStream().listen((data) {
      _eventController?.add(_parseRoomEvent(data));
    });

    _participantEventChannel.receiveBroadcastStream().listen((data) {
      _eventController?.add(_parseParticipantEvent(data));
    });

    _trackEventChannel.receiveBroadcastStream().listen((data) {
      _eventController?.add(_parseTrackEvent(data));
    });

    _torchEventChannel.receiveBroadcastStream().listen((data) {
      _eventController?.add(_parseTorchEvent(data));
    });
  }

  TwilioVideoAdvanced._();

  // CORE FUNCTIONALITY - JOIN WITHOUT BROADCASTING
  /// Connects to a Twilio Video room with observer mode support.
  ///
  /// This is the core method for joining video rooms. By default, participants
  /// join as observers (no broadcasting) and can start broadcasting later using
  /// [publishLocalVideo] and [publishLocalAudio].
  ///
  /// **Parameters:**
  /// - [roomName]: The name of the room to join
  /// - [accessToken]: Valid Twilio access token with video grants
  /// - [enableAudio]: Whether to start broadcasting audio immediately (default: false)
  /// - [enableVideo]: Whether to start broadcasting video immediately (default: false)
  /// - [enableDominantSpeaker]: Enable dominant speaker detection (default: true)
  /// - [enableAutomaticSubscription]: Automatically subscribe to tracks (default: true)
  ///
  /// **Observer Mode Example:**
  /// ```dart
  /// // Join as observer - can see others but not broadcasting
  /// await _twilio.connectToRoom(
  ///   roomName: 'my-room',
  ///   accessToken: 'your-token',
  ///   enableAudio: false, // Observer mode
  ///   enableVideo: false, // Observer mode
  /// );
  /// ```
  ///
  /// **Broadcasting Immediately Example:**
  /// ```dart
  /// // Join and start broadcasting immediately
  /// await _twilio.connectToRoom(
  ///   roomName: 'my-room',
  ///   accessToken: 'your-token',
  ///   enableAudio: true,
  ///   enableVideo: true,
  /// );
  /// ```
  ///
  /// Throws [TwilioException] if connection fails.
  Future<void> connectToRoom({
    required String roomName,
    required String accessToken,
    bool enableAudio = false, // FALSE = Join as observer
    bool enableVideo = false, // FALSE = Join as observer
    bool enableDominantSpeaker = true,
    bool enableAutomaticSubscription = true,
  }) async {
    try {
      await _methodChannel.invokeMethod('connectToRoom', {
        'roomName': roomName,
        'accessToken': accessToken,
        'enableAudio': enableAudio,
        'enableVideo': enableVideo,
        'enableDominantSpeaker': enableDominantSpeaker,
        'enableAutomaticSubscription': enableAutomaticSubscription,
      });
    } on PlatformException catch (e) {
      throw TwilioException(e.code, e.message ?? 'Unknown error');
    }
  }

  // GO LIVE FUNCTIONALITY
  /// Starts broadcasting audio to other participants in the room.
  ///
  /// This method allows participants to "go live" with audio after joining
  /// as an observer. The audio track will be published to all other participants.
  ///
  /// **Example:**
  /// ```dart
  /// // Join as observer first
  /// await _twilio.connectToRoom(roomName: 'room', accessToken: 'token');
  ///
  /// // Later, start broadcasting audio
  /// await _twilio.publishLocalAudio();
  /// ```
  ///
  /// **Note:** Ensure microphone permissions are granted before calling this method.
  /// Use [publishLocalAudioWithPermissions] for automatic permission handling.
  ///
  /// Throws [PlatformException] if audio publishing fails.
  Future<void> publishLocalAudio() async {
    await _methodChannel.invokeMethod('publishTrack', {'trackType': 'audio'});
  }

  /// Starts broadcasting video to other participants in the room.
  ///
  /// This method allows participants to "go live" with video after joining
  /// as an observer. The video track will be published to all other participants.
  ///
  /// **Example:**
  /// ```dart
  /// // Join as observer first
  /// await _twilio.connectToRoom(roomName: 'room', accessToken: 'token');
  ///
  /// // Later, start broadcasting video
  /// await _twilio.publishLocalVideo();
  /// ```
  ///
  /// **Note:** Ensure camera permissions are granted before calling this method.
  /// Use [publishLocalVideoWithPermissions] for automatic permission handling.
  ///
  /// Throws [PlatformException] if video publishing fails.
  Future<void> publishLocalVideo() async {
    await _methodChannel.invokeMethod('publishTrack', {'trackType': 'video'});
  }

  /// Stops broadcasting audio to other participants.
  ///
  /// This method stops the local audio track from being sent to other participants.
  /// The participant remains in the room but will no longer broadcast audio.
  ///
  /// **Example:**
  /// ```dart
  /// await _twilio.unpublishLocalAudio();
  /// ```
  Future<void> unpublishLocalAudio() async {
    await _methodChannel.invokeMethod('unpublishTrack', {'trackType': 'audio'});
  }

  /// Stops broadcasting video to other participants.
  ///
  /// This method stops the local video track from being sent to other participants.
  /// The participant remains in the room but will no longer broadcast video.
  ///
  /// **Example:**
  /// ```dart
  /// await _twilio.unpublishLocalVideo();
  /// ```
  Future<void> unpublishLocalVideo() async {
    await _methodChannel.invokeMethod('unpublishTrack', {'trackType': 'video'});
  }

  /// Toggles the local audio track on/off (mute/unmute).
  ///
  /// This method toggles the enabled state of the local audio track.
  /// When disabled, the audio is muted but the track remains published.
  ///
  /// **Returns:** `true` if audio is now enabled, `false` if disabled.
  ///
  /// **Example:**
  /// ```dart
  /// bool isEnabled = await _twilio.toggleLocalAudio();
  /// print('Audio is now ${isEnabled ? 'unmuted' : 'muted'}');
  /// ```
  ///
  /// Throws [PlatformException] if no audio track is available.
  Future<bool> toggleLocalAudio() async {
    return await _methodChannel.invokeMethod('toggleLocalAudio');
  }

  /// Toggles the local video track on/off.
  ///
  /// This method toggles the enabled state of the local video track.
  /// When disabled, the video is turned off but the track remains published.
  ///
  /// **Returns:** `true` if video is now enabled, `false` if disabled.
  ///
  /// **Example:**
  /// ```dart
  /// bool isEnabled = await _twilio.toggleLocalVideo();
  /// print('Video is now ${isEnabled ? 'on' : 'off'}');
  /// ```
  ///
  /// Throws [PlatformException] if no video track is available.
  Future<bool> toggleLocalVideo() async {
    return await _methodChannel.invokeMethod('toggleLocalVideo');
  }

  /// Sets the local audio track enabled state directly.
  ///
  /// This method explicitly enables or disables the local audio track
  /// without toggling. When disabled, the audio is muted but the track
  /// remains published.
  ///
  /// **Parameters:**
  /// - [enabled]: `true` to enable audio (unmute), `false` to disable (mute)
  ///
  /// **Example:**
  /// ```dart
  /// // Mute audio
  /// await _twilio.setLocalAudioEnabled(false);
  ///
  /// // Unmute audio
  /// await _twilio.setLocalAudioEnabled(true);
  /// ```
  ///
  /// Throws [PlatformException] if no audio track is available.
  Future<void> setLocalAudioEnabled(bool enabled) async {
    await _methodChannel.invokeMethod(
        'setLocalAudioEnabled', {'enabled': enabled});
  }

  /// Sets the local video track enabled state directly.
  ///
  /// This method explicitly enables or disables the local video track
  /// without toggling. When disabled, the video is turned off but the track
  /// remains published.
  ///
  /// **Parameters:**
  /// - [enabled]: `true` to enable video (camera on), `false` to disable (camera off)
  ///
  /// **Example:**
  /// ```dart
  /// // Turn camera off
  /// await _twilio.setLocalVideoEnabled(false);
  ///
  /// // Turn camera on
  /// await _twilio.setLocalVideoEnabled(true);
  /// ```
  ///
  /// Throws [PlatformException] if no video track is available.
  Future<void> setLocalVideoEnabled(bool enabled) async {
    await _methodChannel.invokeMethod(
        'setLocalVideoEnabled', {'enabled': enabled});
  }

  /// Switches between front and back camera.
  ///
  /// This method switches the camera being used for video capture.
  /// The switch is seamless and doesn't interrupt the video stream.
  ///
  /// **Example:**
  /// ```dart
  /// await _twilio.switchCamera();
  /// ```
  ///
  /// **Note:** Camera availability depends on the device. Some devices may
  /// not have both front and back cameras.
  ///
  /// Throws [PlatformException] if camera switching fails or no alternative camera is available.
  Future<void> switchCamera() async {
    await _methodChannel.invokeMethod('switchCamera');
  }

  /// Checks if the camera flash/torch is available on the current camera.
  ///
  /// Flash availability depends on the current camera (front/back) and device hardware.
  /// Typically, back cameras have flash support while front cameras do not.
  ///
  /// **Returns:** `true` if flash is available, `false` otherwise.
  ///
  /// **Example:**
  /// ```dart
  /// bool isAvailable = await _twilio.isTorchAvailable();
  /// if (isAvailable) {
  ///   // Show flash toggle button
  /// }
  /// ```
  Future<bool> isTorchAvailable() async {
    return await _methodChannel.invokeMethod('isTorchAvailable');
  }

  /// Checks if the camera flash/torch is currently enabled.
  ///
  /// **Returns:** `true` if torch is currently on, `false` otherwise.
  ///
  /// **Example:**
  /// ```dart
  /// bool isOn = await _twilio.isTorchOn();
  /// print('Flash is ${isOn ? 'on' : 'off'}');
  /// ```
  Future<bool> isTorchOn() async {
    return await _methodChannel.invokeMethod('isTorchOn');
  }

  /// Sets the camera flash/torch state explicitly.
  ///
  /// This method allows you to turn the flash on or off explicitly,
  /// rather than toggling its current state.
  ///
  /// **Parameters:**
  /// - [enabled]: `true` to turn flash on, `false` to turn it off
  ///
  /// **Example:**
  /// ```dart
  /// // Turn flash on
  /// await _twilio.setTorchEnabled(true);
  ///
  /// // Turn flash off
  /// await _twilio.setTorchEnabled(false);
  /// ```
  ///
  /// **Note:** This method only works if flash is available on the current camera.
  /// Check availability with [isTorchAvailable] first.
  ///
  /// Throws [PlatformException] if flash is not available or operation fails.
  Future<void> setTorchEnabled(bool enabled) async {
    await _methodChannel.invokeMethod('setTorchEnabled', {'enabled': enabled});
  }

  /// Toggles the camera flash/torch on or off.
  ///
  /// This method switches the flash state and returns the new state.
  ///
  /// **Returns:** `true` if flash is now on, `false` if now off.
  ///
  /// **Example:**
  /// ```dart
  /// bool newState = await _twilio.toggleTorch();
  /// print('Flash toggled ${newState ? 'on' : 'off'}');
  /// ```
  ///
  /// **Note:** This method only works if flash is available on the current camera.
  /// Check availability with [isTorchAvailable] first.
  ///
  /// Throws [PlatformException] if flash is not available or operation fails.
  Future<bool> toggleTorch() async {
    return await _methodChannel.invokeMethod('toggleTorch');
  }

  // PERMISSION MANAGEMENT
  /// Requests all required permissions for video calling.
  ///
  /// This method requests camera and microphone permissions that are required
  /// for video calling functionality. It should be called before joining a room
  /// or publishing video/audio tracks.
  ///
  /// **Returns:** A [PermissionResult] containing the status of all permissions.
  ///
  /// **Example:**
  /// ```dart
  /// final result = await _twilio.requestPermissions();
  /// if (result.allGranted) {
  ///   // All permissions granted, safe to proceed
  /// } else {
  ///   // Handle denied permissions
  ///   print('Denied: ${result.deniedPermissions}');
  /// }
  /// ```
  Future<PermissionResult> requestPermissions() async {
    return await PermissionHelper.requestVideoCallPermissions();
  }

  /// Checks the current status of required permissions.
  ///
  /// This method checks the current permission status without requesting them.
  /// Use this to determine if permissions need to be requested.
  ///
  /// **Returns:** A [PermissionResult] containing the current permission status.
  ///
  /// **Example:**
  /// ```dart
  /// final result = await _twilio.checkPermissions();
  /// if (!result.cameraGranted) {
  ///   // Camera permission not granted
  /// }
  /// ```
  Future<PermissionResult> checkPermissions() async {
    return await PermissionHelper.checkPermissions();
  }

  /// Checks if all required permissions are currently granted.
  ///
  /// This is a convenience method that returns `true` only if all required
  /// permissions (camera and microphone) are granted.
  ///
  /// **Returns:** `true` if all permissions are granted, `false` otherwise.
  ///
  /// **Example:**
  /// ```dart
  /// bool hasAll = await _twilio.hasAllPermissions();
  /// if (hasAll) {
  ///   // Safe to use video calling features
  /// }
  /// ```
  Future<bool> hasAllPermissions() async {
    return await PermissionHelper.hasAllPermissions();
  }

  /// Connects to a room with automatic permission handling.
  ///
  /// This method combines room connection with automatic permission management.
  /// It will request permissions if needed before connecting to the room.
  ///
  /// **Parameters:**
  /// - [roomName]: The name of the room to join
  /// - [accessToken]: Valid Twilio access token with video grants
  /// - [enableAudio]: Whether to start broadcasting audio immediately (default: false)
  /// - [enableVideo]: Whether to start broadcasting video immediately (default: false)
  /// - [enableDominantSpeaker]: Enable dominant speaker detection (default: true)
  /// - [enableAutomaticSubscription]: Automatically subscribe to tracks (default: true)
  /// - [autoRequestPermissions]: Whether to automatically request permissions (default: true)
  ///
  /// **Example:**
  /// ```dart
  /// await _twilio.connectToRoomWithPermissions(
  ///   roomName: 'my-room',
  ///   accessToken: 'your-token',
  ///   enableVideo: true, // Will request camera permission automatically
  /// );
  /// ```
  ///
  /// Throws [TwilioException] if permissions are denied or connection fails.
  Future<void> connectToRoomWithPermissions({
    required String roomName,
    required String accessToken,
    bool enableAudio = false,
    bool enableVideo = false,
    bool enableDominantSpeaker = true,
    bool enableAutomaticSubscription = true,
    bool autoRequestPermissions = true,
  }) async {
    if (autoRequestPermissions) {
      final permissions = await requestPermissions();

      if (!permissions.allGranted) {
        final deniedPermissions = permissions.deniedPermissions
            .map((p) =>
        p
            .toString()
            .split('.')
            .last)
            .join(', ');
        throw TwilioException(
          'PERMISSIONS_DENIED',
          'Required permissions not granted: $deniedPermissions',
        );
      }
    }

    return connectToRoom(
      roomName: roomName,
      accessToken: accessToken,
      enableAudio: enableAudio,
      enableVideo: enableVideo,
      enableDominantSpeaker: enableDominantSpeaker,
      enableAutomaticSubscription: enableAutomaticSubscription,
    );
  }

  /// Publishes video with automatic permission check.
  ///
  /// This method checks camera permission before publishing video and
  /// requests it if not already granted.
  ///
  /// **Example:**
  /// ```dart
  /// try {
  ///   await _twilio.publishLocalVideoWithPermissions();
  /// } catch (e) {
  ///   // Handle permission denied or publishing error
  /// }
  /// ```
  ///
  /// Throws [TwilioException] if camera permission is denied or publishing fails.
  Future<void> publishLocalVideoWithPermissions() async {
    final permissions = await checkPermissions();
    if (!permissions.cameraGranted) {
      final result = await PermissionHelper.requestPermission(
          Permission.camera);
      if (!result.isGranted) {
        throw TwilioException(
          'CAMERA_PERMISSION_DENIED',
          'Camera permission is required to publish video',
        );
      }
    }
    return publishLocalVideo();
  }

  /// Publishes audio with automatic permission check.
  ///
  /// This method checks microphone permission before publishing audio and
  /// requests it if not already granted.
  ///
  /// **Example:**
  /// ```dart
  /// try {
  ///   await _twilio.publishLocalAudioWithPermissions();
  /// } catch (e) {
  ///   // Handle permission denied or publishing error
  /// }
  /// ```
  ///
  /// Throws [TwilioException] if microphone permission is denied or publishing fails.
  Future<void> publishLocalAudioWithPermissions() async {
    final permissions = await checkPermissions();
    if (!permissions.microphoneGranted) {
      final result = await PermissionHelper.requestPermission(
          Permission.microphone);
      if (!result.isGranted) {
        throw TwilioException(
          'MICROPHONE_PERMISSION_DENIED',
          'Microphone permission is required to publish audio',
        );
      }
    }
    return publishLocalAudio();
  }

  /// Disconnects from the current room.
  ///
  /// This method leaves the current room and cleans up all resources.
  /// After calling this method, you'll need to call [connectToRoom] again
  /// to join a new room.
  ///
  /// **Example:**
  /// ```dart
  /// await _twilio.disconnect();
  /// ```
  ///
  /// **Note:** This method is safe to call even if not connected to a room.
  Future<void> disconnect() async {
    await _methodChannel.invokeMethod('disconnect');
    _currentRoom = null;
  }

  /// Gets a list of available audio output devices.
  ///
  /// Returns a list of audio devices including speakers, earphones, Bluetooth headsets, etc.
  /// Each device contains name and type information.
  ///
  /// **Returns:** A list of maps containing device information.
  ///
  /// **Example:**
  /// ```dart
  /// final devices = await _twilio.getAvailableAudioDevices();
  /// for (final device in devices) {
  ///   print('${device['name']} (${device['type']})');
  /// }
  /// ```
  Future<List<Map<String, dynamic>>> getAvailableAudioDevices() async {
    final result = await _methodChannel.invokeMethod(
        'getAvailableAudioDevices');
    if (result == null) return [];

    // Convert the result to the expected type
    final List<dynamic> deviceList = List<dynamic>.from(result);
    return deviceList
        .map((device) => Map<String, dynamic>.from(device))
        .toList();
  }

  /// Gets the currently selected audio output device.
  ///
  /// **Returns:** A map containing the selected device information, or null if none selected.
  ///
  /// **Example:**
  /// ```dart
  /// final selectedDevice = await _twilio.getSelectedAudioDevice();
  /// if (selectedDevice != null) {
  ///   print('Current device: ${selectedDevice['name']}');
  /// }
  /// ```
  Future<Map<String, dynamic>?> getSelectedAudioDevice() async {
    final result = await _methodChannel.invokeMethod('getSelectedAudioDevice');
    if (result == null) return null;

    // Convert the result to the expected type
    return Map<String, dynamic>.from(result);
  }

  /// Selects a specific audio output device.
  ///
  /// This allows you to programmatically switch between speakers, earphones,
  /// Bluetooth headsets, etc.
  ///
  /// **Parameters:**
  /// - [deviceName]: The name of the device to select
  ///
  /// **Example:**
  /// ```dart
  /// await _twilio.selectAudioDevice('Speaker');
  /// // or
  /// await _twilio.selectAudioDevice('Bluetooth Headset');
  /// ```
  Future<void> selectAudioDevice(String deviceName) async {
    await _methodChannel.invokeMethod(
        'selectAudioDevice', {'deviceName': deviceName});
  }

  /// Starts listening for audio device changes.
  ///
  /// This enables automatic detection of when audio devices are
  /// connected/disconnected (like Bluetooth headsets).
  ///
  /// **Example:**
  /// ```dart
  /// await _twilio.startAudioDeviceListener();
  /// ```
  Future<void> startAudioDeviceListener() async {
    await _methodChannel.invokeMethod('startAudioDeviceListener');
  }

  /// Stops listening for audio device changes.
  ///
  /// **Example:**
  /// ```dart
  /// await _twilio.stopAudioDeviceListener();
  /// ```
  Future<void> stopAudioDeviceListener() async {
    await _methodChannel.invokeMethod('stopAudioDeviceListener');
  }

  /// Activates the selected audio device.
  ///
  /// This actually routes audio to the selected device. You typically
  /// call this after selecting a device.
  ///
  /// **Example:**
  /// ```dart
  /// await _twilio.selectAudioDevice('Bluetooth Headset');
  /// await _twilio.activateAudioDevice();
  /// ```
  Future<void> activateAudioDevice() async {
    await _methodChannel.invokeMethod('activateAudioDevice');
  }

  /// Deactivates the current audio device.
  ///
  /// This stops audio routing and returns to the default system behavior.
  ///
  /// **Example:**
  /// ```dart
  /// await _twilio.deactivateAudioDevice();
  /// ```
  Future<void> deactivateAudioDevice() async {
    await _methodChannel.invokeMethod('deactivateAudioDevice');
  }

  TwilioEvent _parseRoomEvent(dynamic data) {
    debug('Received room event: ${data['event']} with data: $data');
    switch (data['event']) {
      case 'connected':
        _currentRoom = Room.fromJson(Map<String, dynamic>.from(data['room']));
        return RoomConnectedEvent(_currentRoom!);
      case 'disconnected':
        return RoomDisconnectedEvent(data['error']);
      case 'connectFailure':
        return RoomDisconnectedEvent(data['error']);
      case 'reconnecting':
        return RoomDisconnectedEvent(data['error']);
      case 'reconnected':
        _currentRoom = Room.fromJson(Map<String, dynamic>.from(data['room']));
        return RoomConnectedEvent(_currentRoom!);
      default:
        throw UnimplementedError('Unknown event: ${data['event']}');
    }
  }

  TwilioEvent _parseParticipantEvent(dynamic data) {
    switch (data['event']) {
      case 'participantConnected':
        return ParticipantConnectedEvent(
          RemoteParticipant.fromJson(
              Map<String, dynamic>.from(data['participant'])),
        );
      case 'participantDisconnected':
        return ParticipantDisconnectedEvent(
          RemoteParticipant.fromJson(
              Map<String, dynamic>.from(data['participant'])),
        );
      case 'dominantSpeakerChanged':
        return DominantSpeakerChangedEvent(
          data['participant'] != null
              ? RemoteParticipant.fromJson(
              Map<String, dynamic>.from(data['participant']))
              : null,
        );
      default:
        throw UnimplementedError('Unknown event: ${data['event']}');
    }
  }

  TwilioEvent _parseTrackEvent(dynamic data) {
    switch (data['event']) {
      case 'trackSubscribed':
        return TrackSubscribedEvent(
          participantSid: data['participantSid'],
          trackSid: data['trackSid'],
          trackType: data['trackType'],
        );
      case 'trackUnsubscribed':
        return TrackUnsubscribedEvent(
          participantSid: data['participantSid'],
          trackSid: data['trackSid'],
          trackType: data['trackType'],
        );
      case 'localAudioEnabled':
        return LocalAudioEnabledEvent(data['enabled'] ?? false);
      case 'localVideoEnabled':
        return LocalVideoEnabledEvent(data['enabled'] ?? false);
      default:
        throw UnimplementedError('Unknown track event: ${data['event']}');
    }
  }

  TwilioEvent _parseTorchEvent(dynamic data) {
    switch (data['event']) {
      case 'torchStatusChanged':
        return TorchStatusChangedEvent(
          isOn: data['isOn'] ?? false,
          isAvailable: data['isAvailable'] ?? false,
        );
      case 'torchError':
        return TorchErrorEvent(data['error'] ?? 'Unknown torch error');
      default:
        throw UnimplementedError('Unknown torch event: ${data['event']}');
    }
  }

  void debug(String message) {
    if (kDebugMode) {
      print('[TwilioVideoAdvanced] $message');
    }
  }
}
