import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:twilio_video_advanced/events/TwilioEvent.dart';
import 'package:twilio_video_advanced/models/remote_participant.dart';
import 'package:twilio_video_advanced/twilio_video_advanced.dart';

class TwilioVideoCallScreen extends StatefulWidget {
  final String roomName;
  final String accessToken;

  const TwilioVideoCallScreen({
    super.key,
    required this.roomName,
    required this.accessToken,
  });

  @override
  State<TwilioVideoCallScreen> createState() => _TwilioVideoCallScreenState();
}

class _TwilioVideoCallScreenState extends State<TwilioVideoCallScreen> {
  final _twilio = TwilioVideoAdvanced.instance;
  final List<RemoteParticipant> _participants = [];
  RemoteParticipant? _dominantSpeaker;
  StreamSubscription<TwilioEvent>? _eventSubscription;
  bool _isConnected = false;
  bool _isAudioPublished = false;
  bool _isVideoPublished = false;
  bool _isAudioEnabled = true;
  bool _isVideoEnabled = true;
  bool _isFrontCamera = true;

  @override
  void initState() {
    super.initState();
    _setupEventListeners();
    _connectAsObserver();
  }

  void debug(String message) {
    if (kDebugMode) {
      print('TwilioVideoCallScreen::DEBUG: $message');
    } // Simple debug logging
  }

  void _setupEventListeners() {
    _eventSubscription = _twilio.eventStream.listen((event) {
      if (!mounted) return;

      debug('Event received: ${event.runtimeType}');

      if (event is RoomConnectedEvent) {
        debug(
          'Connected to room: ${event.room.name}, SID: ${event.room.sid}, Participants: ${event.room.remoteParticipants}',
        );
        if (mounted) {
          setState(() {
            _isConnected = true;
            final local = event.room.localParticipant;
            _isAudioPublished = local.isAudioPublished;
            _isVideoPublished = local.isVideoPublished;
            _isAudioEnabled = local.isAudioEnabled;
            _isVideoEnabled = local.isVideoEnabled;
            // Initialize participants from the room
            _participants.clear();
            _participants.addAll(event.room.remoteParticipants);
          });
        }
      } else if (event is RoomReconnectedEvent) {
        if (mounted) {
          setState(() {
            _participants.clear();
            _participants.addAll(event.room.remoteParticipants);
          });
        }
      } else if (event is RoomDisconnectedEvent) {
        debug('Disconnect reason: ${event.error}');
        if (mounted) {
          setState(() {
            _isConnected = false;
            _participants.clear();
            _dominantSpeaker = null;
          });
        }
      } else if (event is ParticipantConnectedEvent) {
        if (mounted) {
          setState(() {
            _participants.add(event.participant);
          });
        }
      } else if (event is ParticipantDisconnectedEvent) {
        if (mounted) {
          setState(() {
            _participants.removeWhere((p) => p.sid == event.participant.sid);
            if (_dominantSpeaker?.sid == event.participant.sid) {
              _dominantSpeaker = null;
            }
          });
        }
      } else if (event is DominantSpeakerChangedEvent) {
        if (mounted) {
          setState(() {
            _dominantSpeaker = event.participant;
          });
        }
      } else if (event is TrackSubscribedEvent && event.trackType == 'video') {
        debug(
          'Video track subscribed: participantSid=${event.participantSid}, trackSid=${event.trackSid}',
        );
        if (mounted) {
          setState(() {}); // Rebuild to show video
        }
      } else if (event is TrackUnsubscribedEvent &&
          event.trackType == 'video') {
        debug(
          'Video track unsubscribed: participantSid=${event.participantSid}, trackSid=${event.trackSid}',
        );
        if (mounted) {
          setState(() {}); // Rebuild to hide video
        }
      }
    });
  }

  Future<void> _connectAsObserver() async {
    try {
      await _twilio.connectToRoom(
        roomName: widget.roomName,
        accessToken: widget.accessToken,
        enableAudio: false,
        enableVideo: false,
      );
    } catch (e) {
      debug('Connection error: $e');
      // Show error dialog instead of silent failure
    }
  }

  Future<void> _toggleAudioPublish() async {
    if (_isAudioPublished) {
      await _twilio.unpublishLocalAudio();
    } else {
      await _twilio.publishLocalAudio();
    }
    setState(() => _isAudioPublished = !_isAudioPublished);
  }

  Future<void> _toggleVideoPublish() async {
    if (_isVideoPublished) {
      await _twilio.unpublishLocalVideo();
    } else {
      await _twilio.publishLocalVideo();
    }
    setState(() => _isVideoPublished = !_isVideoPublished);
  }

  Future<void> _toggleAudio() async {
    final enabled = await _twilio.toggleLocalAudio();
    setState(() => _isAudioEnabled = enabled);
  }

  Future<void> _toggleVideo() async {
    final enabled = await _twilio.toggleLocalVideo();
    setState(() => _isVideoEnabled = enabled);
  }

  Future<void> _switchCamera() async {
    await _twilio.switchCamera();
    setState(() => _isFrontCamera = !_isFrontCamera);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Remote participants grid
            TwilioParticipantsGrid(
              participants: _participants,
              dominantSpeaker: _dominantSpeaker,
            ),

            // Local video preview (bottom right corner)
            if (_isVideoPublished)
              Positioned(
                bottom: 120,
                right: 16,
                child: Container(
                  width: 120,
                  height: 160,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    children: [
                      const TwilioLocalVideoView(
                        key: ValueKey('local_video'), // Add unique key
                      ),
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'LOCAL',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Control buttons
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.black54,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Go Live / Stop Broadcasting
                    FloatingActionButton(
                      heroTag: 'publish',
                      backgroundColor:
                          _isVideoPublished ? Colors.red : Colors.green,
                      onPressed: _toggleVideoPublish,
                      child: Icon(
                        _isVideoPublished ? Icons.stop : Icons.videocam,
                      ),
                    ),

                    // Audio publish toggle
                    FloatingActionButton(
                      heroTag: 'audio_publish',
                      backgroundColor:
                          _isAudioPublished ? Colors.blue : Colors.grey,
                      onPressed: _toggleAudioPublish,
                      child: Icon(
                        _isAudioPublished ? Icons.mic : Icons.mic_off,
                      ),
                    ),

                    // Audio mute toggle
                    FloatingActionButton(
                      heroTag: 'audio',
                      backgroundColor:
                          _isAudioEnabled ? Colors.white : Colors.red,
                      onPressed: _isAudioPublished ? _toggleAudio : null,
                      child: Icon(
                        _isAudioEnabled ? Icons.mic : Icons.mic_off,
                        color: Colors.black,
                      ),
                    ),

                    // Video enable toggle
                    FloatingActionButton(
                      heroTag: 'video',
                      backgroundColor:
                          _isVideoEnabled ? Colors.white : Colors.red,
                      onPressed: _isVideoPublished ? _toggleVideo : null,
                      child: Icon(
                        _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                        color: Colors.black,
                      ),
                    ),

                    // Camera switch
                    FloatingActionButton(
                      heroTag: 'camera',
                      backgroundColor: Colors.white,
                      onPressed: _isVideoPublished ? _switchCamera : null,
                      child: const Icon(
                        Icons.flip_camera_ios,
                        color: Colors.black,
                      ),
                    ),

                    // Disconnect
                    FloatingActionButton(
                      heroTag: 'disconnect',
                      backgroundColor: Colors.red,
                      onPressed: _twilio.disconnect,
                      child: const Icon(Icons.call_end),
                    ),
                  ],
                ),
              ),
            ),

            // Connection status
            if (!_isConnected) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _twilio.disconnect();
    super.dispose();
  }
}
