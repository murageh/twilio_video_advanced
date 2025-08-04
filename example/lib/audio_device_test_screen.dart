import 'package:flutter/material.dart';
import 'package:twilio_video_advanced/twilio_video_advanced.dart';

class AudioDeviceTestScreen extends StatefulWidget {
  const AudioDeviceTestScreen({super.key});

  @override
  State<AudioDeviceTestScreen> createState() => _AudioDeviceTestScreenState();
}

class _AudioDeviceTestScreenState extends State<AudioDeviceTestScreen> {
  final _twilio = TwilioVideoAdvanced.instance;
  List<Map<String, dynamic>> _availableDevices = [];
  Map<String, dynamic>? _selectedDevice;
  bool _isListenerActive = false;
  bool _isDeviceActivated = false;
  String _lastEvent = 'None';

  @override
  void initState() {
    super.initState();
    _requestBluetoothPermissions();
    _refreshDevices();
  }

  Future<void> _requestBluetoothPermissions() async {
    try {
      // Request all permissions including Bluetooth for audio device detection
      final result = await PermissionHelper.requestAllPermissions();

      if (!result.allBluetoothGranted) {
        setState(() {
          _lastEvent =
              'Warning: Some permissions denied. Bluetooth devices may not be detected.';
        });

        final deniedPermissions = result.deniedPermissions
            .map((p) => p.toString().split('.').last)
            .join(', ');

        _showErrorSnackBar(
          'Permissions needed for full functionality: $deniedPermissions',
        );
      } else {
        setState(() {
          _lastEvent =
              'All permissions granted. Ready to detect audio devices.';
        });
      }
    } catch (e) {
      setState(() {
        _lastEvent = 'Permission request failed: $e';
      });
    }
  }

  Future<void> _refreshDevices() async {
    try {
      final devices = await _twilio.getAvailableAudioDevices();
      final selected = await _twilio.getSelectedAudioDevice();

      setState(() {
        _availableDevices = devices;
        _selectedDevice = selected;
        _lastEvent = 'Devices refreshed - ${devices.length} devices found';
      });
    } catch (e) {
      setState(() {
        _lastEvent = 'Error refreshing devices: $e';
      });
      _showErrorSnackBar('Failed to refresh devices: $e');
    }
  }

  Future<void> _selectDevice(String deviceName) async {
    try {
      await _twilio.selectAudioDevice(deviceName);
      await _refreshDevices();
      setState(() {
        _lastEvent = 'Selected device: $deviceName';
      });
      _showSuccessSnackBar('Selected: $deviceName');
    } catch (e) {
      setState(() {
        _lastEvent = 'Error selecting device: $e';
      });
      _showErrorSnackBar('Failed to select device: $e');
    }
  }

  Future<void> _toggleListener() async {
    try {
      if (_isListenerActive) {
        await _twilio.stopAudioDeviceListener();
        setState(() {
          _isListenerActive = false;
          _lastEvent = 'Audio device listener stopped';
        });
        _showInfoSnackBar('Device listener stopped');
      } else {
        await _twilio.startAudioDeviceListener();
        setState(() {
          _isListenerActive = true;
          _lastEvent = 'Audio device listener started';
        });
        _showInfoSnackBar('Device listener started');
        // Refresh devices after starting listener
        await _refreshDevices();
      }
    } catch (e) {
      setState(() {
        _lastEvent = 'Error toggling listener: $e';
      });
      _showErrorSnackBar('Failed to toggle listener: $e');
    }
  }

  Future<void> _toggleActivation() async {
    try {
      if (_isDeviceActivated) {
        await _twilio.deactivateAudioDevice();
        setState(() {
          _isDeviceActivated = false;
          _lastEvent = 'Audio device deactivated';
        });
        _showInfoSnackBar('Audio device deactivated');
      } else {
        await _twilio.activateAudioDevice();
        setState(() {
          _isDeviceActivated = true;
          _lastEvent = 'Audio device activated';
        });
        _showSuccessSnackBar('Audio device activated');
      }
    } catch (e) {
      setState(() {
        _lastEvent = 'Error toggling activation: $e';
      });
      _showErrorSnackBar('Failed to toggle activation: $e');
    }
  }

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
      ),
    );
  }

  IconData _getDeviceIcon(String deviceType) {
    switch (deviceType) {
      case 'BluetoothHeadset':
        return Icons.bluetooth_audio;
      case 'WiredHeadset':
        return Icons.headphones;
      case 'Earpiece':
        return Icons.phone;
      case 'Speakerphone':
        return Icons.speaker;
      default:
        return Icons.audio_file;
    }
  }

  Color _getDeviceColor(String deviceType) {
    switch (deviceType) {
      case 'BluetoothHeadset':
        return Colors.blue;
      case 'WiredHeadset':
        return Colors.green;
      case 'Earpiece':
        return Colors.orange;
      case 'Speakerphone':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Device Test'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _refreshDevices,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Devices',
          ),
        ],
      ),
      backgroundColor: Colors.grey[100],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Control Panel
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Audio Device Controls',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo[800],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Listener Control
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _toggleListener,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _isListenerActive ? Colors.red : Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            icon: Icon(
                              _isListenerActive ? Icons.stop : Icons.play_arrow,
                            ),
                            label: Text(
                              _isListenerActive
                                  ? 'Stop Listener'
                                  : 'Start Listener',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                _selectedDevice != null
                                    ? _toggleActivation
                                    : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _isDeviceActivated
                                      ? Colors.orange
                                      : Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            icon: Icon(
                              _isDeviceActivated
                                  ? Icons.volume_off
                                  : Icons.volume_up,
                            ),
                            label: Text(
                              _isDeviceActivated ? 'Deactivate' : 'Activate',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Current Selection
            if (_selectedDevice != null)
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        _getDeviceIcon(_selectedDevice!['type']),
                        color: _getDeviceColor(_selectedDevice!['type']),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Currently Selected',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _selectedDevice!['name'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _selectedDevice!['type'],
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isDeviceActivated)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'ACTIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Available Devices
            Text(
              'Available Audio Devices (${_availableDevices.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Expanded(
              child:
                  _availableDevices.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.headset_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No audio devices available',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start the listener to detect devices',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                      : ListView.builder(
                        itemCount: _availableDevices.length,
                        itemBuilder: (context, index) {
                          final device = _availableDevices[index];
                          final isSelected =
                              _selectedDevice?['name'] == device['name'];

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getDeviceColor(
                                  device['type'],
                                ).withOpacity(0.1),
                                child: Icon(
                                  _getDeviceIcon(device['type']),
                                  color: _getDeviceColor(device['type']),
                                ),
                              ),
                              title: Text(
                                device['name'],
                                style: TextStyle(
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(device['type']),
                              trailing:
                                  isSelected
                                      ? const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      )
                                      : const Icon(
                                        Icons.radio_button_unchecked,
                                        color: Colors.grey,
                                      ),
                              onTap: () => _selectDevice(device['name']),
                            ),
                          );
                        },
                      ),
            ),

            const SizedBox(height: 16),

            // Event Log
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Last Event:',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _lastEvent,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'How to Test Audio Devices',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. Start the device listener to detect available audio devices\n'
                    '2. Connect/disconnect Bluetooth headphones or wired headphones\n'
                    '3. Select different devices to switch audio output\n'
                    '4. Activate the device to route audio to it\n'
                    '5. Test during a video call to hear the difference',
                    style: TextStyle(fontSize: 13, color: Colors.blue[700]),
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
    // Clean up listener when leaving the screen
    if (_isListenerActive) {
      _twilio.stopAudioDeviceListener();
    }
    if (_isDeviceActivated) {
      _twilio.deactivateAudioDevice();
    }
    super.dispose();
  }
}
