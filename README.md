# Twilio Video Advanced

An advanced Flutter plugin for Twilio Video that provides comprehensive video calling functionality
with support for observer mode, broadcasting controls, and enhanced UI components.

## ⚠️ Platform Support Status

**🤖 Android**: ✅ Fully supported and tested  
**🍎 iOS**: ⚠️ **Not yet implemented** - iOS support is currently in development and will be
available in a future release.

This plugin currently supports **Android only**. While the Dart/Flutter code is platform-agnostic,
the native iOS implementation is still being developed. If you need iOS support, please check back
for updates or consider contributing to the iOS implementation.

## Features

- 🎥 **Observer Mode**: Join rooms without broadcasting to watch others
- 📺 **Go Live**: Start/stop video and audio broadcasting independently
- 🎛️ **Advanced Controls**: Toggle camera, microphone, switch cameras
- 🔦 **Flash/Torch Control**: Toggle camera flash for better lighting during video calls
- 🎨 **Enhanced UI**: Picture-in-Picture, dominant speaker detection, grid layouts
- 🔄 **Auto-reconnection**: Robust connection handling with reconnection support
- 📱 **Platform Views**: Native video rendering for optimal performance
- 🎚️ **Video Quality Management**: Adaptive quality based on device capabilities
- 🔒 **Permission Handling**: Automatic permission management for camera and microphone
- ⚡ **Wake Lock**: Keeps screen on during video calls for better user experience

## Screenshots

### Basic Video Call

![Basic Video Call](screenshots/basic_call.png)

### Picture-in-Picture Mode

![Picture-in-Picture Mode](screenshots/pip_mode.png)

### Grid Layout with Multiple Participants

![Grid Layout](screenshots/grid_layout.png)

### Observer Mode UI

![Observer Mode](screenshots/observer_mode.png)

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  twilio_video_advanced: ^1.0.0
```

Run:

```bash
flutter pub get
```

## Platform Setup

### Android

Add the following permissions to your `android/app/src/main/AndroidManifest.xml`:

```xml

<uses-permission android:name="android.permission.CAMERA" /><uses-permission
android:name="android.permission.RECORD_AUDIO" /><uses-permission
android:name="android.permission.INTERNET" /><uses-permission
android:name="android.permission.ACCESS_NETWORK_STATE" /><uses-permission
android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

### iOS

Add the following to your `ios/Runner/Info.plist`:

```xml

<key>NSCameraUsageDescription</key><string>This app needs access to camera for video calls
</string><key>NSMicrophoneUsageDescription</key><string>This app needs access to microphone for
audio calls
</string>
```

## Usage

### Basic Setup

```dart
import 'package:twilio_video_advanced/twilio_video_advanced.dart';

class VideoCallScreen extends StatefulWidget {
  @override
  _VideoCallScreenState createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final _twilio = TwilioVideoAdvanced.instance;
  StreamSubscription<TwilioEvent>? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _setupEventListeners();
    _joinRoom();
  }

  void _setupEventListeners() {
    _eventSubscription = _twilio.eventStream.listen((event) {
      if (event is RoomConnectedEvent) {
        // Handle room connected
      } else if (event is ParticipantConnectedEvent) {
        // Handle participant joined
      }
      // Handle other events...
    });
  }

  Future<void> _joinRoom() async {
    await _twilio.connectToRoom(
      roomName: 'my-room',
      accessToken: 'your-access-token',
      enableAudio: false, // Observer mode - don't broadcast initially
      enableVideo: false,
    );
  }
}
```

### Observer Mode (Join without Broadcasting)

```dart
// Join as observer - can see/hear others but not broadcasting
await
_twilio.connectToRoom
(
roomName: 'meeting-room',
accessToken: accessToken,
enableAudio:
false
, // Don't broadcast audio initially
enableVideo
:
false
, // Don't broadcast video initially
);
```

### Go Live (Start Broadcasting)

```dart
// Start video broadcasting
await
_twilio.publishLocalVideo
();

// Start audio broadcasting
await
_twilio.publishLocalAudio
();

// Stop broadcasting
await
_twilio.unpublishLocalVideo
();await
_twilio.unpublishLocalAudio
();
```

### Media Controls

```dart
// Toggle microphone (mute/unmute)
bool isEnabled = await
_twilio.toggleLocalAudio
();

// Toggle camera (on/off)
bool isEnabled = await
_twilio.toggleLocalVideo
();

// Switch camera (front/back)
await
_twilio.switchCamera
();

// Flash/Torch Controls
// Check if flash is available on current camera
bool isAvailable = await
_twilio.isTorchAvailable
();

// Check if flash is currently on
bool isOn = await
_twilio.isTorchOn
();

// Toggle flash on/off
bool newState = await
_twilio.toggleTorch
();

// Set flash state explicitly
await
_twilio.setTorchEnabled
(true); // Turn on
await _twilio
.
setTorchEnabled
(
false
); // Turn off
```

### Using the Enhanced UI Components

#### Complete Video Call Screen

```dart
TwilioVideoCallScreen
(
roomName: 'my-room',
accessToken: 'your-access-token',
)
```

#### Custom Participants Grid

```dart
EnhancedParticipantsGrid
(
participants: remoteParticipants,
dominantSpeaker: dominantSpeaker,
isLocalVideoPublished: isVideoPublished,
dominantParticipant: dominantParticipant,
onDominantParticipantChanged: (newDominant) {
// Handle dominance changes
},
)
```

#### Individual Video Views

```dart
// Local video view
TwilioLocalVideoView
(
width: 200,
height: 150,
mirror: true,
)

// Remote video view
TwilioRemoteVideoView(
participantSid: participant.sid,
width
:
200
,
height
:
150
,
)
```

## Event Handling

The plugin provides comprehensive event handling through a unified stream:

```dart
_twilio.eventStream.listen
(
(event) {
switch (event.runtimeType) {
case RoomConnectedEvent:
final roomEvent = event as RoomConnectedEvent;
// Access room.localParticipant, room.remoteParticipants
break;

case ParticipantConnectedEvent:
final participantEvent = event as ParticipantConnectedEvent;
// Handle new participant
break;

case DominantSpeakerChangedEvent:
final speakerEvent = event as DominantSpeakerChangedEvent;
// Update UI to highlight dominant speaker
break;

case TrackSubscribedEvent:
final trackEvent = event as TrackSubscribedEvent;
// Handle video/audio track subscription
break;
}
});
```

## Advanced Features

### Picture-in-Picture Mode

The `EnhancedParticipantsGrid` automatically switches to PiP mode when there's one remote
participant and local video is published. Users can tap to switch dominance.

### Dominant Speaker Detection

Visual indicators show who's currently speaking with green borders and volume icons.

### Auto-reconnection

The plugin handles network interruptions gracefully with automatic reconnection attempts.

### Observer to Broadcaster Flow

Start as an observer and seamlessly transition to broadcasting:

1. Join room in observer mode
2. Use "Go Live" button to start video
3. Use "Join Audio" to start audio
4. Toggle individual media controls

## API Reference

### Core Methods

| Method                  | Description                      |
|-------------------------|----------------------------------|
| `connectToRoom()`       | Join a video room                |
| `disconnect()`          | Leave the current room           |
| `publishLocalVideo()`   | Start video broadcasting         |
| `unpublishLocalVideo()` | Stop video broadcasting          |
| `publishLocalAudio()`   | Start audio broadcasting         |
| `unpublishLocalAudio()` | Stop audio broadcasting          |
| `toggleLocalAudio()`    | Toggle microphone on/off         |
| `toggleLocalVideo()`    | Toggle camera on/off             |
| `switchCamera()`        | Switch between front/back camera |

### Flash/Torch Control Methods

| Method                  | Description                                   |
|-------------------------|-----------------------------------------------|
| `isTorchAvailable()`    | Check if flash is available on current camera |
| `isTorchOn()`           | Check if flash is currently enabled           |
| `toggleTorch()`         | Toggle flash on/off and return new state      |
| `setTorchEnabled(bool)` | Set flash state explicitly                    |

### Permission Management Methods

| Method                               | Description                                   |
|--------------------------------------|-----------------------------------------------|
| `requestPermissions()`               | Request camera and microphone permissions     |
| `checkPermissions()`                 | Check current permission status               |
| `hasAllPermissions()`                | Check if all required permissions are granted |
| `connectToRoomWithPermissions()`     | Connect with automatic permission handling    |
| `publishLocalVideoWithPermissions()` | Publish video with permission check           |
| `publishLocalAudioWithPermissions()` | Publish audio with permission check           |

### Events

| Event                          | Description                          |
|--------------------------------|--------------------------------------|
| `RoomConnectedEvent`           | Room connection established          |
| `RoomDisconnectedEvent`        | Room connection lost                 |
| `ParticipantConnectedEvent`    | Remote participant joined            |
| `ParticipantDisconnectedEvent` | Remote participant left              |
| `DominantSpeakerChangedEvent`  | Active speaker changed               |
| `TrackSubscribedEvent`         | Video/audio track became available   |
| `TrackUnsubscribedEvent`       | Video/audio track became unavailable |
| `TorchStatusChangedEvent`      | Flash/torch status changed           |
| `TorchErrorEvent`              | Flash/torch operation error          |

## Troubleshooting

### Common Issues

**Video not showing:**

- Ensure camera permissions are granted
- Check that video track is published
- Verify participant SID matches

**Audio not working:**

- Check microphone permissions
- Ensure audio track is published and enabled
- Verify device audio settings

**Connection issues:**

- Validate access token expiration
- Check network connectivity
- Review Twilio Console for room status

### Debug Mode

Enable debug logging in development:

```dart
// Debug information is automatically logged in debug builds
// Check console output for detailed event information
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For issues and questions:

- Check the [example app](example/) for implementation details
- Review the [API documentation](https://pub.dev/documentation/twilio_video_advanced)
- Open an issue on [GitHub](https://github.com/your-repo/twilio_video_advanced)

## Acknowledgments

- Built on [Twilio Video SDK](https://www.twilio.com/video)
- Inspired by modern video calling experiences
- Flutter community feedback and contributions
