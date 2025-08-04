import 'dart:async';

import 'package:flutter/material.dart';
import 'package:twilio_video_advanced/events/TwilioEvent.dart';
import 'package:twilio_video_advanced/models/remote_participant.dart';
import 'package:twilio_video_advanced/twilio_video_advanced.dart';
import 'package:twilio_video_advanced/widgets/enhanced_participants_grid.dart';

class CustomNameTestScreen extends StatefulWidget {
  final String roomName;
  final String accessToken;

  const CustomNameTestScreen({
    super.key,
    required this.roomName,
    required this.accessToken,
  });

  @override
  State<CustomNameTestScreen> createState() => _CustomNameTestScreenState();
}

class _CustomNameTestScreenState extends State<CustomNameTestScreen> {
  final _twilio = TwilioVideoAdvanced.instance;
  final List<RemoteParticipant> _participants = [];
  StreamSubscription<TwilioEvent>? _eventSubscription;

  bool _isConnected = false;
  bool _isVideoPublished = false;

  @override
  void initState() {
    super.initState();
    _setupEventListeners();
    _connectToRoom();
  }

  void _setupEventListeners() {
    _eventSubscription = _twilio.eventStream.listen((event) {
      if (!mounted) return;

      if (event is RoomConnectedEvent) {
        setState(() {
          _isConnected = true;
          _participants.clear();
          _participants.addAll(event.room.remoteParticipants);
        });

        // Set a custom name for the local participant after connecting
        _setCustomLocalName();
      } else if (event is ParticipantConnectedEvent) {
        setState(() {
          _participants.add(event.participant);
        });

        // Set a custom name for new participants
        _setCustomParticipantName(event.participant);
      } else if (event is ParticipantDisconnectedEvent) {
        setState(() {
          _participants.removeWhere((p) => p.sid == event.participant.sid);
        });
      } else if (event is ParticipantDisplayNameChangedEvent) {
        // Handle display name changes
        setState(() {
          // Find and update the participant with the new display name
          final index = _participants.indexWhere(
                (p) => p.sid == event.participantSid,
          );
          if (index != -1) {
            _participants[index] = _participants[index].copyWith(
              displayName: event.displayName,
            );
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Display name updated: ${event.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  Future<void> _connectToRoom() async {
    try {
      await _twilio.connectToRoom(
        roomName: widget.roomName,
        accessToken: widget.accessToken,
        enableAudio: false,
        enableVideo: false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to connect: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _setCustomLocalName() async {
    // Set a custom name for the local participant
    await _twilio.setLocalDisplayName('Dr. Johnson (You)');
  }

  Future<void> _setCustomParticipantName(RemoteParticipant participant) async {
    // Set custom names based on identity or use predefined names
    String customName;
    switch (participant.identity) {
      case 'pana-patient-id':
        customName = 'Alice Smith (Patient)';
        break;
      case 'pana-doctor-id':
        customName = 'Dr. Johnson (Doctor)';
        break;
      default:
        customName = 'User ${participant.identity}';
    }

    await _twilio.setParticipantDisplayName(
      participantSid: participant.sid,
      displayName: customName,
    );
  }

  Future<void> _toggleVideo() async {
    try {
      if (_isVideoPublished) {
        await _twilio.unpublishLocalVideo();
      } else {
        await _twilio.publishLocalVideo();
      }
      setState(() => _isVideoPublished = !_isVideoPublished);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to toggle video: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Custom Name Test'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Connection status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: _isConnected ? Colors.green : Colors.orange,
              child: Text(
                _isConnected
                    ? 'Connected to ${widget.roomName}'
                    : 'Connecting...',
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),

            // Video area
            Expanded(
              child: _isConnected
                  ? EnhancedParticipantsGrid(
                participants: _participants,
                dominantSpeaker: null,
                isLocalVideoPublished: _isVideoPublished,
                dominantParticipant: DominantParticipant.none,
                onDominantParticipantChanged: (_) {},
              )
                  : const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),

            // Debug info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.grey[900],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Debug Info:',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Participants: ${_participants.length}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  for (final participant in _participants)
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 4),
                      child: Text(
                        '• ${participant.name} (identity: ${participant
                            .identity}, sid: ${participant.sid.substring(
                            0, 8)}...)',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),

            // Controls
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isConnected ? _toggleVideo : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isVideoPublished ? Colors.red : Colors
                          .green,
                    ),
                    icon: Icon(_isVideoPublished ? Icons.videocam_off : Icons
                        .videocam),
                    label: Text(
                        _isVideoPublished ? 'Stop Video' : 'Start Video'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey),
                    icon: const Icon(Icons.exit_to_app),
                    label: const Text('Leave'),
                  ),
                ],
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
