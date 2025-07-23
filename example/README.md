# Twilio Video Advanced Example

This example demonstrates how to use the `twilio_video_advanced` Flutter plugin to build a
comprehensive video calling application with observer mode, broadcasting controls, and enhanced UI
features.

## ⚠️ Platform Support Status

**🤖 Android**: ✅ Fully supported and tested  
**🍎 iOS**: ⚠️ **Not yet implemented** - iOS support is currently in development and will be
available in a future release.

This example currently works on **Android only**. The iOS implementation is still being developed.

## Features Demonstrated

- 🎯 **Observer Mode**: Join rooms without initially broadcasting
- 📺 **Go Live Functionality**: Start/stop video and audio broadcasting independently
- 🎛️ **Media Controls**: Camera toggle, microphone mute, camera switching
- 🖼️ **Picture-in-Picture**: Automatic layout switching with tap-to-switch dominance
- 👥 **Grid Layout**: Multi-participant video grid with dominant speaker highlighting
- 🔄 **Connection Management**: Reconnection handling and error states
- 📱 **Responsive UI**: Adaptive layouts for different participant counts

## Screenshots

### Home Screen

![Home Screen](screenshots/home_screen.png)

### Observer Mode - Just Joined

![Observer Mode](screenshots/observer_joined.png)

### Going Live - Video Broadcasting

![Going Live](screenshots/going_live.png)

### Picture-in-Picture Mode

![PiP Mode](screenshots/pip_mode.png)

### Grid Layout with Multiple Participants

![Grid Layout](screenshots/grid_multiple.png)

### Connection States

![Connection States](screenshots/connection_states.png)

## Getting Started

### Prerequisites

1. **Twilio Account**: Sign up at [twilio.com](https://www.twilio.com)
2. **Video API Credentials**: Get your Account SID and API Key from Twilio Console
3. **Access Tokens**: Generate tokens for testing (see below)

### Setup

1. **Clone and Install**:
   ```bash
   cd example
   flutter pub get
   ```

2. **Permissions**: The app will automatically request camera and microphone permissions on first
   run.

3. **Access Tokens**: Replace the tokens in `lib/main.dart` with your own tokens:

   ```dart
   // Generate tokens using Twilio Helper Library or API
   accessToken: 'your-generated-access-token-here'
   ```

### Generating Access Tokens

For testing, you can generate tokens using Twilio's token generator or create a simple server:

#### Using Twilio Console (Quick Testing)

1. Go to Twilio Console > Video > Tools > Testing Tools
2. Generate tokens for different identities
3. Use tokens in the example app

#### Using Node.js Helper (Recommended for Development)

```javascript
const AccessToken = require('twilio').jwt.AccessToken;
const VideoGrant = AccessToken.VideoGrant;

function generateToken(identity, roomName) {
  const token = new AccessToken(
    process.env.TWILIO_ACCOUNT_SID,
    process.env.TWILIO_API_KEY_SID,
    process.env.TWILIO_API_KEY_SECRET
  );
  
  token.identity = identity;
  
  const videoGrant = new VideoGrant({
    room: roomName
  });
  
  token.addGrant(videoGrant);
  
  return token.toJwt();
}

// Generate tokens for testing
const userToken = generateToken('user1', 'test-room');
const doctorToken = generateToken('user2', 'test-room');
```

## Running the Example

1. **Start the App**:
   ```bash
   flutter run
   ```

2. **Test Multi-User Scenario**:
    - Use two devices or emulators
    - Join the same room with different tokens
    - Test observer mode and broadcasting features

3. **Try Different Flows**:
    - Join as observer → Go live with video → Add audio
    - Join with both users as observers → One goes live
    - Test reconnection by toggling network

## Code Structure

### Main Components

```
lib/
├── main.dart                 # Entry point and home screen
└── screens/
    └── video_call_screen.dart # Complete video call implementation
```

### Key Features Demonstrated

#### 1. Observer Mode Setup

```dart
// Join room without broadcasting initially
await
_twilio.connectToRoom
(
roomName: 'cool room',
accessToken: accessToken,
enableAudio:
false
, // Observer mode
enableVideo
:
false
, // Observer mode
);
```

#### 2. Go Live Controls

```dart
// Video broadcasting toggle
ElevatedButton.icon
(
onPressed: _toggleVideoPublish,
icon: Icon(_isVideoPublished ? Icons.videocam_off : Icons.videocam),
label: Text(_isVideoPublished ? 'Stop Video' : 'Go Live'),
)

// Audio broadcasting toggle
ElevatedButton.icon(
onPressed: _toggleAudioPublish,
icon: Icon(_isAudioPublished ? Icons.mic : Icons.mic_off),
label: Text(_isAudioPublished ? 'Stop Audio' : 'Join Audio')
,
)
```

#### 3. Enhanced UI Components

```dart
// Adaptive video layout
EnhancedParticipantsGrid
(
participants: _participants,
dominantSpeaker: _dominantSpeaker,
isLocalVideoPublished: _isVideoPublished,
dominantParticipant: _dominantParticipant,
onDominantParticipantChanged: _onDominantParticipantChanged,
)
```

#### 4. Event Handling

```dart
_eventSubscription = _twilio.eventStream.listen
(
(event) {
if (event is RoomConnectedEvent) {
// Update UI for successful connection
setState(() {
_connectionState = ConnectionState.connected;
_participants.addAll(event.room.remoteParticipants);
});
} else if (event is ParticipantConnectedEvent) {
// Handle new participant
setState(() {
_participants.add(event.participant);
});
_showInfoSnackBar('${event.participant.identity} joined');
}
// ... handle other events
});
```

## User Experience Flows

### Flow 1: Observer to Broadcaster

1. **Join as Observer**: User joins room without camera/mic
2. **Watch Others**: See other participants' video feeds
3. **Go Live**: Tap "Go Live" to start video broadcasting
4. **Join Audio**: Tap "Join Audio" to start audio broadcasting
5. **Media Controls**: Use toggle buttons for mute/camera control

### Flow 2: Picture-in-Picture

1. **Two Participants**: One local + one remote with video
2. **Automatic PiP**: UI automatically switches to PiP layout
3. **Tap to Switch**: Tap either video to switch dominance
4. **Visual Feedback**: Clear indicators show who's dominant

### Flow 3: Multi-Participant Grid

1. **Multiple Users**: 3+ participants join the room
2. **Grid Layout**: UI switches to responsive grid
3. **Dominant Speaker**: Green border highlights active speaker
4. **Adaptive Sizing**: Grid adjusts based on participant count

## Testing Scenarios

### Single Device Testing

1. **Observer Mode**: Join room, verify no local video appears
2. **Go Live**: Test video publishing toggle
3. **Audio Control**: Test audio publishing and mute controls
4. **Camera Switch**: Test front/back camera switching

### Multi-Device Testing

1. **Observer + Broadcaster**: One device observes, other broadcasts
2. **PiP Mode**: Test tap-to-switch dominance
3. **Multiple Participants**: Test grid layout with 3+ devices
4. **Connection Issues**: Test reconnection by disabling/enabling network

### Edge Cases

1. **No Permissions**: Test behavior when camera/mic access denied
2. **Network Loss**: Test reconnection handling
3. **Token Expiry**: Test behavior with expired tokens
4. **Room Limits**: Test behavior when room is full

## Customization Examples

### Custom UI Theme

```dart
// Customize button styles
ElevatedButton.styleFrom
(
backgroundColor: Colors.red,
foregroundColor: Colors.white,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(
20
)
,
)
,
)
```

### Custom Event Handling

```dart
// Add custom analytics or logging
_twilio.eventStream.listen
(
(event) {
// Log events for analytics
analytics.track('twilio_event', {
'event_type': event.runtimeType.toString(),
'room_name': widget.roomName,
});

// Handle events...
});
```

### Custom Video Layouts

```dart
// Create custom grid layouts
Widget _buildCustomGrid() {
  return StaggeredGrid.count(
    crossAxisCount: 2,
    children: participants.map((p) =>
        TwilioRemoteVideoView(participantSid: p.sid)
    ).toList(),
  );
}
```

## Troubleshooting

### Common Issues

**App crashes on join:**

- Check access token validity
- Ensure proper permissions are granted
- Verify Twilio Account SID and API keys

**Video not showing:**

- Check camera permissions
- Verify participant is publishing video
- Check device camera availability

**Audio issues:**

- Verify microphone permissions
- Check device audio settings
- Ensure audio tracks are published

### Debug Tips

1. **Enable Debug Logging**:
   ```dart
   // Debug output is automatically shown in debug builds
   // Check console for detailed event logs
   ```

2. **Check Twilio Console**:
    - Monitor room activity in Twilio Console
    - Check participant connection status
    - Review error logs

3. **Test with Different Tokens**:
    - Ensure tokens have correct room grants
    - Verify token expiration times
    - Test with different participant identities

## Next Steps

After running this example, you can:

1. **Integrate into Your App**: Copy relevant code patterns
2. **Customize UI**: Modify layouts and styles to match your design
3. **Add Features**: Implement screen sharing, chat, recording
4. **Deploy**: Set up proper token server for production

## Resources

- [Twilio Video Documentation](https://www.twilio.com/docs/video)
- [Flutter Plugin Documentation](../README.md)
- [Twilio Video API Reference](https://www.twilio.com/docs/video/api)
- [Access Token Generator](https://www.twilio.com/docs/video/tutorials/user-identity-access-tokens)

## Support

For issues with this example:

1. Check the main plugin [README](../README.md)
2. Review Twilio Video documentation
3. Open an issue with reproduction steps
