import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:twilio_video_advanced/events/TwilioEvent.dart';
import 'package:twilio_video_advanced/models/remote_participant.dart';
import 'package:twilio_video_advanced/twilio_video_advanced.dart';

import 'enhanced_participants_grid.dart';

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

  // New state for dominance management
  DominantParticipant _dominantParticipant = DominantParticipant.none;
  bool _manualDominanceSet = false; // Track if user manually set dominance

  @override
  void initState() {
    super.initState();
    _setupEventListeners();
    _connectAsObserver();
  }

  void debug(String message) {
    if (kDebugMode) {
      print('TwilioVideoCallScreen::DEBUG: $message');
    }
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

            // Set initial dominance
            _updateAutoDominance();
          });
        }
      } else if (event is RoomReconnectedEvent) {
        if (mounted) {
          setState(() {
            _participants.clear();
            _participants.addAll(event.room.remoteParticipants);
            _updateAutoDominance();
          });
        }
      } else if (event is RoomDisconnectedEvent) {
        debug('Disconnect reason: ${event.error}');
        if (mounted) {
          setState(() {
            _isConnected = false;
            _participants.clear();
            _dominantSpeaker = null;
            _dominantParticipant = DominantParticipant.none;
            _manualDominanceSet = false;
          });
        }
      } else if (event is ParticipantConnectedEvent) {
        if (mounted) {
          setState(() {
            _participants.add(event.participant);
            _updateAutoDominance();
          });
        }
      } else if (event is ParticipantDisconnectedEvent) {
        if (mounted) {
          setState(() {
            _participants.removeWhere((p) => p.sid == event.participant.sid);
            if (_dominantSpeaker?.sid == event.participant.sid) {
              _dominantSpeaker = null;
            }
            _updateAutoDominance();
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
      } else
      if (event is TrackUnsubscribedEvent && event.trackType == 'video') {
        debug(
          'Video track unsubscribed: participantSid=${event.participantSid}, trackSid=${event.trackSid}',
        );
        if (mounted) {
          setState(() {}); // Rebuild to hide video
        }
      }
    });
  }

  // Auto-dominance logic
  void _updateAutoDominance() {
    if (_manualDominanceSet) return; // Don't override manual selection

    if (_participants.isEmpty) {
      // Only local participant - make local dominant if video is published
      _dominantParticipant =
      _isVideoPublished ? DominantParticipant.local : DominantParticipant.none;
    } else if (_participants.length == 1 && _isVideoPublished) {
      // One remote + local - make remote dominant by default
      _dominantParticipant = DominantParticipant.remote;
    } else {
      // Multiple participants - use grid layout
      _dominantParticipant = DominantParticipant.none;
    }

    debug('Auto-dominance updated to: $_dominantParticipant');
  }

  // Manual dominance switching
  void _onDominantParticipantChanged(DominantParticipant newDominant) {
    setState(() {
      _dominantParticipant = newDominant;
      _manualDominanceSet = true; // Mark as manually set
    });
    debug('Manual dominance changed to: $newDominant');
  }

  // Reset manual dominance when video state changes
  void _resetManualDominance() {
    _manualDominanceSet = false;
    _updateAutoDominance();
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
    setState(() {
      _isVideoPublished = !_isVideoPublished;
      _resetManualDominance(); // Reset dominance when video state changes
    });
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
            // Enhanced participants grid with dynamic layout - extends to bottom with padding for controls
            Positioned.fill(
              bottom: 100, // Space for control buttons
              child: EnhancedParticipantsGrid(
                participants: _participants,
                dominantSpeaker: _dominantSpeaker,
                isLocalVideoPublished: _isVideoPublished,
                dominantParticipant: _dominantParticipant,
                onDominantParticipantChanged: _onDominantParticipantChanged,
              ),
            ),

            // Improved control panel with better organization and responsive design
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                constraints: const BoxConstraints(
                    minHeight: 100, maxHeight: 120),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.9),
                    ],
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: IntrinsicHeight(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Go Live Section
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _toggleVideoPublish,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isVideoPublished ? Colors
                                        .red : Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  icon: Icon(
                                    _isVideoPublished
                                        ? Icons.videocam_off
                                        : Icons.videocam,
                                    size: 18,
                                  ),
                                  label: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      _isVideoPublished
                                          ? 'Stop Video'
                                          : 'Go Live',
                                      style: const TextStyle(fontSize: 11,
                                          fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Audio Broadcasting Section
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _toggleAudioPublish,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isAudioPublished ? Colors
                                        .blue : Colors.grey[600],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  icon: Icon(
                                    _isAudioPublished ? Icons.mic : Icons
                                        .mic_off,
                                    size: 18,
                                  ),
                                  label: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      _isAudioPublished
                                          ? 'Stop Audio'
                                          : 'Join Audio',
                                      style: const TextStyle(fontSize: 11,
                                          fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Media Controls Section
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Audio mute toggle
                                Container(
                                  decoration: BoxDecoration(
                                    color: _isAudioEnabled ? Colors.white
                                        .withOpacity(0.9) : Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    onPressed: _isAudioPublished
                                        ? _toggleAudio
                                        : null,
                                    icon: Icon(
                                      _isAudioEnabled ? Icons.mic : Icons
                                          .mic_off,
                                      color: _isAudioEnabled
                                          ? Colors.black
                                          : Colors.white,
                                      size: 20,
                                    ),
                                    tooltip: _isAudioEnabled
                                        ? 'Mute'
                                        : 'Unmute',
                                  ),
                                ),

                                const SizedBox(width: 6),

                                // Video enable toggle
                                Container(
                                  decoration: BoxDecoration(
                                    color: _isVideoEnabled ? Colors.white
                                        .withOpacity(0.9) : Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    onPressed: _isVideoPublished
                                        ? _toggleVideo
                                        : null,
                                    icon: Icon(
                                      _isVideoEnabled ? Icons.videocam : Icons
                                          .videocam_off,
                                      color: _isVideoEnabled
                                          ? Colors.black
                                          : Colors.white,
                                      size: 20,
                                    ),
                                    tooltip: _isVideoEnabled
                                        ? 'Turn off camera'
                                        : 'Turn on camera',
                                  ),
                                ),

                                const SizedBox(width: 6),

                                // Camera switch
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    onPressed: _isVideoPublished
                                        ? _switchCamera
                                        : null,
                                    icon: const Icon(
                                      Icons.flip_camera_ios,
                                      color: Colors.black,
                                      size: 20,
                                    ),
                                    tooltip: 'Switch camera',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Disconnect button
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _twilio.disconnect,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  icon: const Icon(Icons.call_end, size: 18),
                                  label: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Leave',
                                      style: TextStyle(fontSize: 11,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Connection status with user-friendly message
            if (!_isConnected)
              Container(
                color: Colors.black.withOpacity(0.8),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Joining room...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Please wait while we connect you',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Status indicators for user feedback
            Positioned(
              top: 16,
              left: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Participant count
                  if (_isConnected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                              Icons.people, color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${_participants.length + 1} in room',
                            style: const TextStyle(color: Colors.white,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                  // Broadcasting status
                  if (_isVideoPublished || _isAudioPublished)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.fiber_manual_record,
                                color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              _isVideoPublished ? 'LIVE' : 'AUDIO ONLY',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Debug info (only in debug mode)
            if (kDebugMode)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Dominant: $_dominantParticipant${_manualDominanceSet
                        ? ' (Manual)'
                        : ' (Auto)'}',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
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
