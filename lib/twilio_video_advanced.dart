import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'TwilioAdvancedException.dart';
import 'events/TwilioEvent.dart';
import 'models/remote_participant.dart';
import 'models/room.dart';

export 'widgets/twilio_local_video_view.dart';
export 'widgets/twilio_participants_grid.dart';
export 'widgets/twilio_remote_video_view.dart';
export 'widgets/twilio_video_call_screen.dart';

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

  static TwilioVideoAdvanced? _instance;

  static TwilioVideoAdvanced get instance =>
      _instance ??= TwilioVideoAdvanced._();

  Room? _currentRoom;

  Room? get currentRoom => _currentRoom;

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
  }

  TwilioVideoAdvanced._();

  // CORE FUNCTIONALITY - JOIN WITHOUT BROADCASTING
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
  Future<void> publishLocalAudio() async {
    await _methodChannel.invokeMethod('publishTrack', {'trackType': 'audio'});
  }

  Future<void> publishLocalVideo() async {
    await _methodChannel.invokeMethod('publishTrack', {'trackType': 'video'});
  }

  Future<void> unpublishLocalAudio() async {
    await _methodChannel.invokeMethod('unpublishTrack', {'trackType': 'audio'});
  }

  Future<void> unpublishLocalVideo() async {
    await _methodChannel.invokeMethod('unpublishTrack', {'trackType': 'video'});
  }

  // MEDIA CONTROLS
  Future<bool> toggleLocalAudio() async {
    return await _methodChannel.invokeMethod('toggleLocalAudio');
  }

  Future<bool> toggleLocalVideo() async {
    return await _methodChannel.invokeMethod('toggleLocalVideo');
  }

  Future<void> switchCamera() async {
    await _methodChannel.invokeMethod('switchCamera');
  }

  Future<void> disconnect() async {
    await _methodChannel.invokeMethod('disconnect');
    _currentRoom = null;
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
      default:
        throw UnimplementedError('Unknown track event: ${data['event']}');
    }
  }

  void debug(String message) {
    if (kDebugMode) {
      print('[TwilioVideoAdvanced] $message');
    }
  }
}
