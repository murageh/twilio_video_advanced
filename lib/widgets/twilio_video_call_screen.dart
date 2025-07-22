import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:twilio_video_advanced/events/TwilioEvent.dart';
import 'package:twilio_video_advanced/models/remote_participant.dart';
import 'package:twilio_video_advanced/twilio_video_advanced.dart';

import 'enhanced_participants_grid.dart';

enum ConnectionState {
  connecting,
  connected,
  disconnected,
  reconnecting,
  failed
}

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

  // Connection and state management
  ConnectionState _connectionState = ConnectionState.connecting;
  String? _lastError;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  // Media states
  bool _isAudioPublished = false;
  bool _isVideoPublished = false;
  bool _isAudioEnabled = true;
  bool _isVideoEnabled = true;
  bool _isFrontCamera = true;

  // Dominance management
  DominantParticipant _dominantParticipant = DominantParticipant.none;
  bool _manualDominanceSet = false;

  @override
  void initState() {
    super.initState();
    _setupEventListeners();
    _connectToRoom();
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
        if (mounted) {
          setState(() {
            _connectionState = ConnectionState.connected;
            _lastError = null;
            _reconnectAttempts = 0;
            final local = event.room.localParticipant;
            _isAudioPublished = local.isAudioPublished;
            _isVideoPublished = local.isVideoPublished;
            _isAudioEnabled = local.isAudioEnabled;
            _isVideoEnabled = local.isVideoEnabled;
            _participants.clear();
            _participants.addAll(event.room.remoteParticipants);
            _updateAutoDominance();
          });
          _showSuccessSnackBar('Connected to ${widget.roomName}');
        }
      } else if (event is RoomReconnectedEvent) {
        if (mounted) {
          setState(() {
            _connectionState = ConnectionState.connected;
            _lastError = null;
            _participants.clear();
            _participants.addAll(event.room.remoteParticipants);
            _updateAutoDominance();
          });
          _showSuccessSnackBar('Reconnected successfully');
        }
      } else if (event is RoomDisconnectedEvent) {
        debug('Disconnect reason: ${event.error}');
        if (mounted) {
          setState(() {
            _connectionState = ConnectionState.disconnected;
            _lastError = event.error;
            _participants.clear();
            _dominantSpeaker = null;
            _dominantParticipant = DominantParticipant.none;
            _manualDominanceSet = false;
          });
          // _handleDisconnection(event.error);
        }
      } else if (event is ParticipantConnectedEvent) {
        if (mounted) {
          setState(() {
            _participants.add(event.participant);
            _updateAutoDominance();
          });
          _showInfoSnackBar('${event.participant.identity} joined');
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
          _showInfoSnackBar('${event.participant.identity} left');
        }
      } else if (event is DominantSpeakerChangedEvent) {
        if (mounted) {
          setState(() {
            _dominantSpeaker = event.participant;
          });
        }
      } else if (event is TrackSubscribedEvent && event.trackType == 'video') {
        debug('Video track subscribed: participantSid=${event.participantSid}');
        if (mounted) {
          setState(() {});
        }
      } else
      if (event is TrackUnsubscribedEvent && event.trackType == 'video') {
        debug(
            'Video track unsubscribed: participantSid=${event.participantSid}');
        if (mounted) {
          setState(() {});
        }
      }
    });
  }

  Future<void> _connectToRoom() async {
    try {
      setState(() {
        _connectionState = ConnectionState.connecting;
        _lastError = null;
      });

      await _twilio.connectToRoom(
        roomName: widget.roomName,
        accessToken: widget.accessToken,
        enableAudio: false,
        enableVideo: false,
      );
    } catch (e) {
      debug('Connection error: $e');
      if (mounted) {
        setState(() {
          _connectionState = ConnectionState.failed;
          _lastError = e.toString();
        });
        _showConnectionErrorDialog(e.toString());
      }
    }
  }

  void _handleDisconnection(String? error) {
    if (error != null && error.isNotEmpty && !error.contains('disconnect')) {
      // Unexpected disconnection - offer to reconnect
      _showReconnectDialog(error);
    }
    // else {
    //   // Normal disconnection - show end call dialog
    //   _showCallEndedDialog();
    // }
  }

  void _showConnectionErrorDialog(String error) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Text('Connection Failed'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Unable to connect to the video room.'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    error,
                    style: const TextStyle(
                        fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // Exit to previous screen
                },
                child: const Text('Go Back'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _connectToRoom(); // Retry connection
                },
                child: const Text('Retry'),
              ),
            ],
          ),
    );
  }

  void _showReconnectDialog(String error) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.orange),
                SizedBox(width: 8),
                Text('Connection Lost'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('You have been disconnected from the video room.'),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Reason: $error',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // Exit to previous screen
                },
                child: const Text('Leave'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _reconnectAttempts++;
                  _connectToRoom(); // Attempt to reconnect
                },
                child: const Text('Reconnect'),
              ),
            ],
          ),
    );
  }

  // void _showCallEndedDialog() {
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (context) => AlertDialog(
  //       title: const Row(
  //         children: [
  //           Icon(Icons.call_end, color: Colors.red),
  //           SizedBox(width: 8),
  //           Text('Call Ended'),
  //         ],
  //       ),
  //       content: const Text('The video call has ended.'),
  //       actions: [
  //         TextButton(
  //           onPressed: () {
  //             Navigator.of(context).pop();
  //             Navigator.of(context).pop(); // Exit to previous screen
  //           },
  //           child: const Text('Leave'),
  //         ),
  //         ElevatedButton(
  //           onPressed: () {
  //             Navigator.of(context).pop();
  //             _connectToRoom(); // Rejoin the call
  //           },
  //           child: const Text('Rejoin'),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _connectToRoom,
        ),
      ),
    );
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

  Future<void> _toggleAudioPublish() async {
    try {
      if (_isAudioPublished) {
        await _twilio.unpublishLocalAudio();
        _showInfoSnackBar('Audio stopped');
      } else {
        await _twilio.publishLocalAudio();
        _showSuccessSnackBar('Audio started');
      }
      setState(() => _isAudioPublished = !_isAudioPublished);
    } catch (e) {
      _showErrorSnackBar(
          'Failed to ${_isAudioPublished ? 'stop' : 'start'} audio: ${e
              .toString()}');
    }
  }

  Future<void> _toggleVideoPublish() async {
    try {
      if (_isVideoPublished) {
        await _twilio.unpublishLocalVideo();
        _showInfoSnackBar('Video stopped');
      } else {
        await _twilio.publishLocalVideo();
        _showSuccessSnackBar('Going live!');
      }
      setState(() {
        _isVideoPublished = !_isVideoPublished;
        _resetManualDominance();
      });
    } catch (e) {
      _showErrorSnackBar(
          'Failed to ${_isVideoPublished ? 'stop' : 'start'} video: ${e
              .toString()}');
    }
  }

  Future<void> _toggleAudio() async {
    try {
      final enabled = await _twilio.toggleLocalAudio();
      setState(() => _isAudioEnabled = enabled);
      _showInfoSnackBar(enabled ? 'Audio unmuted' : 'Audio muted');
    } catch (e) {
      _showErrorSnackBar('Failed to toggle audio: ${e.toString()}');
    }
  }

  Future<void> _toggleVideo() async {
    try {
      final enabled = await _twilio.toggleLocalVideo();
      setState(() => _isVideoEnabled = enabled);
      _showInfoSnackBar(enabled ? 'Camera on' : 'Camera off');
    } catch (e) {
      _showErrorSnackBar('Failed to toggle camera: ${e.toString()}');
    }
  }

  Future<void> _switchCamera() async {
    try {
      await _twilio.switchCamera();
      setState(() => _isFrontCamera = !_isFrontCamera);
      _showInfoSnackBar(
          'Camera switched to ${_isFrontCamera ? 'front' : 'back'}');
    } catch (e) {
      _showErrorSnackBar('Failed to switch camera: ${e.toString()}');
    }
  }

  Future<void> _leaveCall() async {
    try {
      await _twilio.disconnect();
    } catch (e) {
      _showErrorSnackBar('Failed to leave call: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Main content based on connection state
            if (_connectionState == ConnectionState.connected)
              _buildConnectedView()
            else
              if (_connectionState == ConnectionState.connecting)
                _buildConnectingView()
              else
                if (_connectionState == ConnectionState.failed)
                  _buildErrorView()
                else
                  _buildDisconnectedView(),

            // Status indicators
            _buildStatusIndicators(),

            // Debug info (only in debug mode)
            if (kDebugMode) _buildDebugInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedView() {
    return Stack(
      children: [
        // Video area
        Positioned.fill(
          bottom: 100,
          child: EnhancedParticipantsGrid(
            participants: _participants,
            dominantSpeaker: _dominantSpeaker,
            isLocalVideoPublished: _isVideoPublished,
            dominantParticipant: _dominantParticipant,
            onDominantParticipantChanged: _onDominantParticipantChanged,
          ),
        ),

        // Control panel
        _buildControlPanel(),
      ],
    );
  }

  Widget _buildConnectingView() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
            const SizedBox(height: 20),
            const Text(
              'Joining room...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.roomName,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            if (_reconnectAttempts > 0) ...[
              const SizedBox(height: 16),
              Text(
                'Reconnecting... (Attempt ${_reconnectAttempts})',
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Container(
      color: Colors.black.withOpacity(0.9),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 24),
            const Text(
              'Connection Failed',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _lastError ?? 'Unknown error occurred',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                  ),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                ),
                ElevatedButton.icon(
                  onPressed: _connectToRoom,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisconnectedView() {
    return Container(
      color: Colors.black.withOpacity(0.9),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.call_end,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 24),
            const Text(
              'Call Ended',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_lastError != null && _lastError!.isNotEmpty) ...[
              Text(
                _lastError!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'What would you like to do?',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(
                      Icons.exit_to_app, size: 18, color: Colors.white),
                  label: const Text('Leave'),
                ),
                ElevatedButton.icon(
                  onPressed: _connectToRoom,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  icon: const Icon(Icons.video_call),
                  label: const Text('Rejoin'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        constraints: const BoxConstraints(minHeight: 100, maxHeight: 120),
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
                            backgroundColor: _isVideoPublished
                                ? Colors.red
                                : Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          icon: Icon(
                            _isVideoPublished ? Icons.videocam_off : Icons
                                .videocam,
                            size: 18,
                          ),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _isVideoPublished ? 'Stop Video' : 'Go Live',
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold),
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
                            backgroundColor: _isAudioPublished
                                ? Colors.blue
                                : Colors.grey[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          icon: Icon(
                            _isAudioPublished ? Icons.mic : Icons.mic_off,
                            size: 18,
                          ),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _isAudioPublished ? 'Stop Audio' : 'Join Audio',
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold),
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
                            color: _isAudioEnabled ? Colors.white.withOpacity(
                                0.9) : Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: _isAudioPublished ? _toggleAudio : null,
                            icon: Icon(
                              _isAudioEnabled ? Icons.mic : Icons.mic_off,
                              color: _isAudioEnabled ? Colors.black : Colors
                                  .white,
                              size: 20,
                            ),
                            tooltip: _isAudioEnabled ? 'Mute' : 'Unmute',
                          ),
                        ),

                        const SizedBox(width: 6),

                        // Video enable toggle
                        Container(
                          decoration: BoxDecoration(
                            color: _isVideoEnabled ? Colors.white.withOpacity(
                                0.9) : Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: _isVideoPublished ? _toggleVideo : null,
                            icon: Icon(
                              _isVideoEnabled ? Icons.videocam : Icons
                                  .videocam_off,
                              color: _isVideoEnabled ? Colors.black : Colors
                                  .white,
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
                            onPressed: _isVideoPublished ? _switchCamera : null,
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
                          onPressed: _leaveCall,
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
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold),
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
    );
  }

  Widget _buildStatusIndicators() {
    return Positioned(
      top: 16,
      left: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Connection status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getConnectionStatusColor().withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getConnectionStatusIcon(), color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  _getConnectionStatusText(),
                  style: const TextStyle(color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          // Participant count (only when connected)
          if (_connectionState == ConnectionState.connected)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${_participants.length + 1} in room',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

          // Broadcasting status
          if ((_isVideoPublished || _isAudioPublished) &&
              _connectionState == ConnectionState.connected)
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
                    const Icon(Icons.fiber_manual_record, color: Colors.white,
                        size: 12),
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
    );
  }

  Widget _buildDebugInfo() {
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    );
  }

  Color _getConnectionStatusColor() {
    switch (_connectionState) {
      case ConnectionState.connected:
        return Colors.green;
      case ConnectionState.connecting:
      case ConnectionState.reconnecting:
        return Colors.orange;
      case ConnectionState.disconnected:
      case ConnectionState.failed:
        return Colors.red;
    }
  }

  IconData _getConnectionStatusIcon() {
    switch (_connectionState) {
      case ConnectionState.connected:
        return Icons.wifi;
      case ConnectionState.connecting:
      case ConnectionState.reconnecting:
        return Icons.wifi_find;
      case ConnectionState.disconnected:
      case ConnectionState.failed:
        return Icons.wifi_off;
    }
  }

  String _getConnectionStatusText() {
    switch (_connectionState) {
      case ConnectionState.connected:
        return 'Connected';
      case ConnectionState.connecting:
        return 'Connecting...';
      case ConnectionState.reconnecting:
        return 'Reconnecting...';
      case ConnectionState.disconnected:
        return 'Disconnected';
      case ConnectionState.failed:
        return 'Connection Failed';
    }
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _eventSubscription?.cancel();
    _twilio.disconnect();
    super.dispose();
  }
}
