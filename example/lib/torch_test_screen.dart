import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:twilio_video_advanced/twilio_video_advanced.dart';
import 'package:twilio_video_advanced/events/TwilioEvent.dart';

class TorchTestScreen extends StatefulWidget {
  const TorchTestScreen({super.key});

  @override
  State<TorchTestScreen> createState() => _TorchTestScreenState();
}

class _TorchTestScreenState extends State<TorchTestScreen> {
  final _twilio = TwilioVideoAdvanced.instance;
  bool _isTorchAvailable = false;
  bool _isTorchOn = false;
  bool _isFrontCamera = true;
  bool _isCameraInitialized = false;
  String _lastTorchEvent = 'None';

  @override
  void initState() {
    super.initState();
    _setupTorchListeners();
    _initializeCamera();
  }

  void _setupTorchListeners() {
    _twilio.eventStream.listen((event) {
      if (event is TorchStatusChangedEvent) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isTorchAvailable = event.isAvailable;
              _isTorchOn = event.isOn;
              _lastTorchEvent =
                  'Status: Available=${event.isAvailable}, On=${event.isOn}';
            });
          }
        });
      } else if (event is TorchErrorEvent) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _lastTorchEvent = 'Error: ${event.error}';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Torch Error: ${event.error}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
      }
    });
  }

  Future<void> _initializeCamera() async {
    try {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _lastTorchEvent = 'Initializing camera...';
          });
        }
      });

      // Initialize camera by publishing a video track temporarily
      await _twilio.publishLocalVideo();

      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
            _lastTorchEvent = 'Camera initialized';
          });
        }
      });

      // Check torch availability after camera initialization
      await Future.delayed(Duration(milliseconds: 500));
      _checkTorchAvailability();
    } catch (e) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _lastTorchEvent = 'Camera initialization failed: $e';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to initialize camera: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }
  }

  Future<void> _checkTorchAvailability() async {
    try {
      final available = await _twilio.isTorchAvailable();
      final isOn = await _twilio.isTorchOn();
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isTorchAvailable = available;
            _isTorchOn = isOn;
            _lastTorchEvent =
                'Check: Available=$available, On=$isOn, Camera=${_isFrontCamera ? 'front' : 'back'}';
          });
        }
      });
    } catch (e) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _lastTorchEvent = 'Check failed: $e';
          });
        }
      });
    }
  }

  Future<void> _toggleTorch() async {
    try {
      final newState = await _twilio.toggleTorch();
      if (mounted) {
        setState(() {
          _isTorchOn = newState;
          _lastTorchEvent = 'Toggled to: $newState';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Torch ${newState ? 'ON' : 'OFF'}'),
            backgroundColor: newState ? Colors.orange : Colors.grey,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastTorchEvent = 'Toggle failed: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to toggle torch: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _setTorch(bool enabled) async {
    try {
      await _twilio.setTorchEnabled(enabled);
      if (mounted) {
        setState(() {
          _isTorchOn = enabled;
          _lastTorchEvent = 'Set to: $enabled';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastTorchEvent = 'Set failed: $e';
        });
      }
    }
  }

  Future<void> _switchCamera() async {
    try {
      await _twilio.switchCamera();
      if (mounted) {
        setState(() {
          _isFrontCamera = !_isFrontCamera;
          _lastTorchEvent =
              'Camera switched to ${_isFrontCamera ? 'front' : 'back'}';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Switched to ${_isFrontCamera ? 'front' : 'back'} camera',
            ),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Check torch availability after camera switch
      await Future.delayed(Duration(milliseconds: 500));
      _checkTorchAvailability();
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastTorchEvent = 'Camera switch failed: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to switch camera: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Torch Test'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Camera Status Indicator
              if (!_isCameraInitialized)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.orange,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Initializing camera...',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

              // Torch Status Card
              Card(
                color: Colors.grey[900],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isTorchAvailable
                                ? Icons.flash_on
                                : Icons.flash_off,
                            color:
                                _isTorchAvailable ? Colors.orange : Colors.grey,
                            size: 32,
                          ),
                          SizedBox(width: 12),
                          Text(
                            _isTorchAvailable ? 'Flash Available' : 'No Flash',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Current State: ${_isTorchOn ? 'ON' : 'OFF'}',
                        style: TextStyle(
                          color: _isTorchOn ? Colors.orange : Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Camera: ${_isFrontCamera ? 'Front' : 'Back'}',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 32),

              // Control Buttons
              if (_isCameraInitialized) ...[
                // Toggle Button
                ElevatedButton.icon(
                  onPressed: _isTorchAvailable ? _toggleTorch : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isTorchAvailable
                            ? (_isTorchOn ? Colors.orange : Colors.grey[700])
                            : Colors.grey[800],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: Icon(_isTorchOn ? Icons.flash_off : Icons.flash_on),
                  label: Text(
                    _isTorchAvailable
                        ? (_isTorchOn ? 'Turn OFF' : 'Turn ON')
                        : 'No Flash Available',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),

                SizedBox(height: 16),

                // Explicit On/Off Buttons
                if (_isTorchAvailable) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () => _setTorch(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        child: Text('Force ON'),
                      ),
                      ElevatedButton(
                        onPressed: () => _setTorch(false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[700],
                          foregroundColor: Colors.white,
                        ),
                        child: Text('Force OFF'),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                ],

                // Camera Switch Button
                ElevatedButton.icon(
                  onPressed: _switchCamera,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: Icon(
                    _isFrontCamera ? Icons.camera_rear : Icons.camera_front,
                  ),
                  label: Text(
                    'Switch to ${_isFrontCamera ? 'Back' : 'Front'} Camera',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ] else ...[
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Please wait while camera initializes...',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              SizedBox(height: 32),

              // Refresh Button
              TextButton.icon(
                onPressed:
                    _isCameraInitialized ? _checkTorchAvailability : null,
                icon: Icon(Icons.refresh, color: Colors.white70),
                label: Text(
                  'Refresh Status',
                  style: TextStyle(color: Colors.white70),
                ),
              ),

              SizedBox(height: 24),

              // Event Log
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[700]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last Event:',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _lastTorchEvent,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),

              // Instructions
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[900]?.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instructions:',
                      style: TextStyle(
                        color: Colors.blue[300],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Flash is typically only available on back camera\n'
                      '• Front cameras usually don\'t have flash\n'
                      '• Test with back camera for best results\n'
                      '• Events will show torch status changes',
                      style: TextStyle(color: Colors.blue[100], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Clean up camera resources when leaving the screen
    try {
      _twilio.unpublishLocalVideo();
    } catch (e) {
      print('Error cleaning up video: $e');
    }
    super.dispose();
  }
}
