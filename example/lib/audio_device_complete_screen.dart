import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:twilio_video_advanced/events/TwilioEvent.dart';
import 'package:twilio_video_advanced/twilio_video_advanced.dart';

/// Complete audio device management screen following Twilio's best practices.
///
/// This screen demonstrates:
/// - Proper audio device activation/deactivation
/// - Volume control stream management
/// - Audio device selection and switching
/// - Integration with video calling lifecycle
class AudioDeviceCompleteScreen extends StatefulWidget {
  const AudioDeviceCompleteScreen({super.key});

  @override
  State<AudioDeviceCompleteScreen> createState() =>
      _AudioDeviceCompleteScreenState();
}

class _AudioDeviceCompleteScreenState extends State<AudioDeviceCompleteScreen> {
  final TwilioVideoAdvanced _twilio = TwilioVideoAdvanced.instance;
  late StreamSubscription<TwilioEvent> _eventSubscription;

  // Connection state
  bool _isConnected = false;
  bool _isConnecting = false;
  String _roomName = 'cool-room';
  String _accessToken = '';

  // Audio state
  bool _isAudioPublished = false;
  bool _isAudioEnabled = true;
  bool _isAudioDeviceActivated = false;

  // Video state
  bool _isVideoPublished = false;
  bool _isVideoEnabled = true;

  // Audio devices
  List<Map<String, dynamic>> _availableDevices = [];
  Map<String, dynamic>? _selectedDevice;
  bool _isAudioDeviceListenerActive = false;

  // Volume control
  int _currentVolumeControlStream = 0;
  bool _isVolumeControlEnabled = false;

  // UI state
  String _statusMessage = 'Ready to test audio devices';
  bool _showAdvancedControls = false;

  @override
  void initState() {
    super.initState();
    _initializeAudioDeviceManagement();
    _setupEventListening();
  }

  @override
  void dispose() {
    _eventSubscription.cancel();
    _cleanupAudioDeviceManagement();
    super.dispose();
  }

  void _initializeAudioDeviceManagement() {
    _statusMessage = 'Initializing audio device management...';
    setState(() {});

    // Start audio device listener for automatic device detection
    _startAudioDeviceListener();

    // Get initial audio devices
    _refreshAudioDevices();
  }

  void _setupEventListening() {
    _eventSubscription = _twilio.eventStream.listen((event) {
      if (event is RoomConnectedEvent) {
        setState(() {
          _isConnected = true;
          _isConnecting = false;
          _statusMessage = 'Connected to room: ${event.room.name}';
        });

        // Audio devices are automatically activated when audio is published
        // following Twilio's best practices
      } else if (event is RoomDisconnectedEvent) {
        setState(() {
          _isConnected = false;
          _isConnecting = false;
          _isAudioPublished = false;
          _isVideoPublished = false;
          _isAudioDeviceActivated = false;
          _statusMessage =
              event.error != null
                  ? 'Disconnected: ${event.error}'
                  : 'Disconnected from room';
        });
      } else if (event is LocalAudioEnabledEvent) {
        setState(() {
          _isAudioEnabled = event.enabled;
          _statusMessage = 'Audio ${event.enabled ? 'enabled' : 'disabled'}';
        });
      } else if (event is LocalVideoEnabledEvent) {
        setState(() {
          _isVideoEnabled = event.enabled;
          _statusMessage = 'Video ${event.enabled ? 'enabled' : 'disabled'}';
        });
      } else if (event is VolumeControlStreamChangedEvent) {
        // Handle volume control stream changes from Android
        setState(() {
          _currentVolumeControlStream = event.streamType;
          _isVolumeControlEnabled = event.enabled;
        });

        // Set volume control stream at the platform level
        _setVolumeControlStream(event.streamType, event.enabled);

        _statusMessage =
            event.enabled
                ? 'Volume control enabled for video calling (stream: ${event.streamType})'
                : 'Volume control reset to default';
      } else if (event is TorchStatusChangedEvent) {
        _statusMessage =
            'Torch ${event.isOn ? 'enabled' : 'disabled'} '
            '(available: ${event.isAvailable})';
      }

      if (mounted) setState(() {});
    });
  }

  Future<void> _startAudioDeviceListener() async {
    try {
      await _twilio.startAudioDeviceListener();
      setState(() {
        _isAudioDeviceListenerActive = true;
        _statusMessage = 'Audio device listener started';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to start audio device listener: $e';
      });
    }
  }

  Future<void> _stopAudioDeviceListener() async {
    try {
      await _twilio.stopAudioDeviceListener();
      setState(() {
        _isAudioDeviceListenerActive = false;
        _statusMessage = 'Audio device listener stopped';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to stop audio device listener: $e';
      });
    }
  }

  Future<void> _refreshAudioDevices() async {
    try {
      final devices = await _twilio.getAvailableAudioDevices();
      final selected = await _twilio.getSelectedAudioDevice();

      setState(() {
        _availableDevices = devices;
        _selectedDevice = selected;
        _statusMessage = 'Found ${devices.length} audio devices';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to get audio devices: $e';
      });
    }
  }

  Future<void> _selectAudioDevice(String deviceName) async {
    try {
      await _twilio.selectAudioDevice(deviceName);
      await _refreshAudioDevices();
      setState(() {
        _statusMessage = 'Selected audio device: $deviceName';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to select device: $e';
      });
    }
  }

  Future<void> _activateAudioDevice() async {
    try {
      await _twilio.activateAudioDevice();
      setState(() {
        _isAudioDeviceActivated = true;
        _statusMessage = 'Audio device activated';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to activate audio device: $e';
      });
    }
  }

  Future<void> _deactivateAudioDevice() async {
    try {
      await _twilio.deactivateAudioDevice();
      setState(() {
        _isAudioDeviceActivated = false;
        _statusMessage = 'Audio device deactivated';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to deactivate audio device: $e';
      });
    }
  }

  // Platform-specific volume control stream management
  Future<void> _setVolumeControlStream(int streamType, bool enabled) async {
    if (Platform.isAndroid) {
      try {
        // Use platform channel to set volume control stream in Android Activity
        const platform = MethodChannel('twilio_video_advanced/volume_control');
        await platform.invokeMethod('setVolumeControlStream', {
          'streamType': streamType,
          'enabled': enabled,
        });
      } catch (e) {
        print('Failed to set volume control stream: $e');
        // Fallback: Use SystemSound to set volume control stream
        if (enabled) {
          // For video calling, we want volume keys to control voice call volume
          SystemSound.play(SystemSoundType.click);
        }
      }
    }
  }

  Future<void> _connectToRoom() async {
    if (_accessToken.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter access token';
      });
      return;
    }

    setState(() {
      _isConnecting = true;
      _statusMessage = 'Connecting to room...';
    });

    try {
      // Connect in observer mode first (best practice)
      await _twilio.connectToRoomWithPermissions(
        roomName: _roomName,
        accessToken: _accessToken,
        enableAudio: false, // Observer mode
        enableVideo: false, // Observer mode
      );
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _statusMessage = 'Failed to connect: $e';
      });
    }
  }

  Future<void> _disconnect() async {
    await _twilio.disconnect();
  }

  Future<void> _publishAudio() async {
    try {
      await _twilio.publishLocalAudioWithPermissions();
      setState(() {
        _isAudioPublished = true;
        _isAudioDeviceActivated =
            true; // Automatically activated when audio is published
        _statusMessage = 'Audio published and device activated';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to publish audio: $e';
      });
    }
  }

  Future<void> _unpublishAudio() async {
    try {
      await _twilio.unpublishLocalAudio();
      setState(() {
        _isAudioPublished = false;
        _isAudioDeviceActivated =
            false; // Automatically deactivated when audio is unpublished
        _statusMessage = 'Audio unpublished and device deactivated';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to unpublish audio: $e';
      });
    }
  }

  Future<void> _publishVideo() async {
    try {
      await _twilio.publishLocalVideoWithPermissions();
      setState(() {
        _isVideoPublished = true;
        _statusMessage = 'Video published';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to publish video: $e';
      });
    }
  }

  Future<void> _unpublishVideo() async {
    try {
      await _twilio.unpublishLocalVideo();
      setState(() {
        _isVideoPublished = false;
        _statusMessage = 'Video unpublished';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to unpublish video: $e';
      });
    }
  }

  Future<void> _toggleAudio() async {
    try {
      final enabled = await _twilio.toggleLocalAudio();
      setState(() {
        _isAudioEnabled = enabled;
        _statusMessage = 'Audio ${enabled ? 'unmuted' : 'muted'}';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to toggle audio: $e';
      });
    }
  }

  Future<void> _toggleVideo() async {
    try {
      final enabled = await _twilio.toggleLocalVideo();
      setState(() {
        _isVideoEnabled = enabled;
        _statusMessage = 'Video ${enabled ? 'enabled' : 'disabled'}';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to toggle video: $e';
      });
    }
  }

  void _cleanupAudioDeviceManagement() {
    // Stop audio device listener when disposing
    if (_isAudioDeviceListenerActive) {
      _twilio.stopAudioDeviceListener();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Device Management'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              _showAdvancedControls ? Icons.expand_less : Icons.expand_more,
            ),
            onPressed: () {
              setState(() {
                _showAdvancedControls = !_showAdvancedControls;
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              color: _isConnected ? Colors.green.shade50 : Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isConnected ? Icons.check_circle : Icons.info,
                          color: _isConnected ? Colors.green : Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_statusMessage, style: const TextStyle(fontSize: 14)),
                    if (_isVolumeControlEnabled) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Volume Control: Stream $_currentVolumeControlStream',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Connection Controls
            if (!_isConnected) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Room Connection',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Room Name',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => _roomName = value,
                        controller: TextEditingController(text: _roomName),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Access Token',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => _accessToken = value,
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isConnecting ? null : _connectToRoom,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                        ),
                        child:
                            _isConnecting
                                ? const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text('Connecting...'),
                                  ],
                                )
                                : const Text('Connect to Room'),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Publishing Controls
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Media Publishing',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  _isAudioPublished
                                      ? _unpublishAudio
                                      : _publishAudio,
                              icon: Icon(
                                _isAudioPublished ? Icons.mic_off : Icons.mic,
                              ),
                              label: Text(
                                _isAudioPublished
                                    ? 'Stop Audio'
                                    : 'Go Live (Audio)',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    _isAudioPublished
                                        ? Colors.red
                                        : Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  _isVideoPublished
                                      ? _unpublishVideo
                                      : _publishVideo,
                              icon: Icon(
                                _isVideoPublished
                                    ? Icons.videocam_off
                                    : Icons.videocam,
                              ),
                              label: Text(
                                _isVideoPublished
                                    ? 'Stop Video'
                                    : 'Go Live (Video)',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    _isVideoPublished
                                        ? Colors.red
                                        : Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  _isAudioPublished ? _toggleAudio : null,
                              icon: Icon(
                                _isAudioEnabled ? Icons.mic : Icons.mic_off,
                              ),
                              label: Text(_isAudioEnabled ? 'Mute' : 'Unmute'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    _isAudioEnabled
                                        ? Colors.orange
                                        : Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  _isVideoPublished ? _toggleVideo : null,
                              icon: Icon(
                                _isVideoEnabled
                                    ? Icons.videocam
                                    : Icons.videocam_off,
                              ),
                              label: Text(
                                _isVideoEnabled ? 'Hide Video' : 'Show Video',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    _isVideoEnabled
                                        ? Colors.orange
                                        : Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Audio Device Management
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Audio Devices',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: _refreshAudioDevices,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_selectedDevice != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _getAudioDeviceIcon(_selectedDevice!['type']),
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Current: ${_selectedDevice!['name']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      'Type: ${_selectedDevice!['type']}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _isAudioDeviceActivated
                                          ? Colors.green
                                          : Colors.orange,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _isAudioDeviceActivated
                                      ? 'Active'
                                      : 'Inactive',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_availableDevices.isNotEmpty) ...[
                        const Text(
                          'Available Devices:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        ...(_availableDevices.map(
                          (device) => Card(
                            margin: const EdgeInsets.only(bottom: 4),
                            child: ListTile(
                              leading: Icon(
                                _getAudioDeviceIcon(device['type']),
                              ),
                              title: Text(device['name']),
                              subtitle: Text(device['type']),
                              trailing:
                                  _selectedDevice?['name'] == device['name']
                                      ? const Icon(
                                        Icons.check,
                                        color: Colors.green,
                                      )
                                      : null,
                              onTap: () => _selectAudioDevice(device['name']),
                            ),
                          ),
                        )),
                      ] else ...[
                        const Text('No audio devices found'),
                      ],
                    ],
                  ),
                ),
              ),

              // Disconnect Button
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    onPressed: _disconnect,
                    icon: const Icon(Icons.call_end),
                    label: const Text('Disconnect'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
            ],

            // Advanced Controls (expandable)
            if (_showAdvancedControls) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Advanced Audio Controls',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  _isAudioDeviceActivated
                                      ? null
                                      : _activateAudioDevice,
                              child: const Text('Activate Audio Device'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  _isAudioDeviceActivated
                                      ? _deactivateAudioDevice
                                      : null,
                              child: const Text('Deactivate Audio Device'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  _isAudioDeviceListenerActive
                                      ? null
                                      : _startAudioDeviceListener,
                              child: const Text('Start Device Listener'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  _isAudioDeviceListenerActive
                                      ? _stopAudioDeviceListener
                                      : null,
                              child: const Text('Stop Device Listener'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getAudioDeviceIcon(String deviceType) {
    switch (deviceType) {
      case 'BluetoothHeadset':
        return Icons.bluetooth_audio;
      case 'WiredHeadset':
        return Icons.headset;
      case 'Speakerphone':
        return Icons.volume_up;
      case 'Earpiece':
        return Icons.phone;
      default:
        return Icons.audio_file;
    }
  }
}
