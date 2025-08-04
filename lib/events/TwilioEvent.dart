import '../models/remote_participant.dart';
import '../models/room.dart';

/// Base class for all Twilio Video events.
///
/// All events emitted by the [TwilioVideoAdvanced] plugin extend this class.
/// Use pattern matching or `is` checks to handle specific event types:
///
/// ```dart
/// _twilio.eventStream.listen((event) {
///   if (event is RoomConnectedEvent) {
///     // Handle room connection
///   } else if (event is TorchStatusChangedEvent) {
///     // Handle torch status change
///   }
/// });
/// ```
abstract class TwilioEvent {}

/// Emitted when successfully connected to a Twilio Video room.
///
/// This event indicates that the local participant has joined the room
/// and can now publish tracks or subscribe to remote participants' tracks.
///
/// The [room] contains information about the connected room including:
/// - Local participant details
/// - List of remote participants already in the room
/// - Room configuration and state
class RoomConnectedEvent extends TwilioEvent {
  /// The room that was successfully connected to.
  final Room room;

  /// Creates a room connected event.
  RoomConnectedEvent(this.room);
}

/// Emitted when the room is attempting to reconnect after a network interruption.
///
/// This event occurs when the SDK detects a network issue and begins
/// automatic reconnection attempts. The UI should show a "reconnecting" state.
class RoomReconnectingEvent extends TwilioEvent {
  /// The room that is attempting to reconnect.
  final Room room;

  /// Creates a room reconnecting event.
  RoomReconnectingEvent(this.room);
}

/// Emitted when the room has successfully reconnected after a network interruption.
///
/// This event indicates that the reconnection was successful and normal
/// operation has resumed. Update the UI to show the connected state.
class RoomReconnectedEvent extends TwilioEvent {
  /// The room that successfully reconnected.
  final Room room;

  /// Creates a room reconnected event.
  RoomReconnectedEvent(this.room);
}

/// Emitted when disconnected from a Twilio Video room.
///
/// This can occur due to:
/// - Calling [TwilioVideoAdvanced.disconnect]
/// - Network connectivity issues
/// - Server-side disconnection
/// - Access token expiration
///
/// The [error] field contains details if the disconnection was unexpected.
class RoomDisconnectedEvent extends TwilioEvent {
  /// The reason for disconnection, or null if disconnected intentionally.
  final String? error;

  /// Creates a room disconnected event.
  ///
  /// The [error] should be provided when the disconnection was unexpected
  /// or due to an error condition.
  RoomDisconnectedEvent(this.error);
}

/// Emitted when a remote participant joins the room.
///
/// This event is fired for each participant that connects to the room
/// after the local participant has joined. Use this to update the UI
/// to show the new participant.
///
/// ```dart
/// if (event is ParticipantConnectedEvent) {
///   setState(() {
///     participants.add(event.participant);
///   });
/// }
/// ```
class ParticipantConnectedEvent extends TwilioEvent {
  /// The participant that joined the room.
  final RemoteParticipant participant;

  /// Creates a participant connected event.
  ParticipantConnectedEvent(this.participant);
}

/// Emitted when a remote participant leaves the room.
///
/// This event is fired when a participant disconnects from the room.
/// Use this to update the UI to remove the participant's video view
/// and update participant counts.
///
/// ```dart
/// if (event is ParticipantDisconnectedEvent) {
///   setState(() {
///     participants.removeWhere((p) => p.sid == event.participant.sid);
///   });
/// }
/// ```
class ParticipantDisconnectedEvent extends TwilioEvent {
  /// The participant that left the room.
  final RemoteParticipant participant;

  /// Creates a participant disconnected event.
  ParticipantDisconnectedEvent(this.participant);
}

/// Emitted when the dominant speaker changes in the room.
///
/// The dominant speaker is the participant who is currently speaking
/// the loudest. This is useful for highlighting the active speaker
/// in the UI or switching to a speaker-focused layout.
///
/// ```dart
/// if (event is DominantSpeakerChangedEvent) {
///   setState(() {
///     dominantSpeaker = event.participant;
///   });
/// }
/// ```
class DominantSpeakerChangedEvent extends TwilioEvent {
  /// The participant who is now the dominant speaker.
  ///
  /// Will be null if no participant is currently speaking loudly enough
  /// to be considered dominant.
  final RemoteParticipant? participant;

  /// Creates a dominant speaker changed event.
  DominantSpeakerChangedEvent(this.participant);
}

/// Emitted when a track (video or audio) is subscribed to from a remote participant.
///
/// This event indicates that the local participant has successfully
/// subscribed to a track published by a remote participant. For video
/// tracks, this means the video can now be rendered.
///
/// ```dart
/// if (event is TrackSubscribedEvent && event.trackType == 'video') {
///   // Video track is now available for rendering
///   setState(() {
///     // Update UI to show video
///   });
/// }
/// ```
class TrackSubscribedEvent extends TwilioEvent {
  /// The SID of the participant who published the track.
  final String participantSid;

  /// The SID of the subscribed track.
  final String trackSid;

  /// The type of track subscribed to ('video' or 'audio').
  final String trackType;

  /// Creates a track subscribed event.
  TrackSubscribedEvent({
    required this.participantSid,
    required this.trackSid,
    required this.trackType,
  });
}

/// Emitted when a track (video or audio) is unsubscribed from a remote participant.
///
/// This event indicates that the local participant is no longer subscribed
/// to a track from a remote participant. For video tracks, the video
/// should be removed from the UI.
///
/// ```dart
/// if (event is TrackUnsubscribedEvent && event.trackType == 'video') {
///   // Video track is no longer available
///   setState(() {
///     // Update UI to hide video
///   });
/// }
/// ```
class TrackUnsubscribedEvent extends TwilioEvent {
  /// The SID of the participant who unpublished the track.
  final String participantSid;

  /// The SID of the unsubscribed track.
  final String trackSid;

  /// The type of track unsubscribed from ('video' or 'audio').
  final String trackType;

  /// Creates a track unsubscribed event.
  TrackUnsubscribedEvent({
    required this.participantSid,
    required this.trackSid,
    required this.trackType,
  });
}

/// Emitted when the camera flash/torch status changes.
///
/// This event is fired whenever the torch availability or state changes,
/// such as when switching cameras or when the torch is toggled on/off.
///
/// ```dart
/// if (event is TorchStatusChangedEvent) {
///   setState(() {
///     isTorchAvailable = event.isAvailable;
///     isTorchOn = event.isOn;
///   });
/// }
/// ```
class TorchStatusChangedEvent extends TwilioEvent {
  /// Whether the torch is currently turned on.
  final bool isOn;

  /// Whether the torch is available on the current camera.
  final bool isAvailable;

  /// Creates a torch status changed event.
  TorchStatusChangedEvent({
    required this.isOn,
    required this.isAvailable,
  });
}

/// Emitted when a torch/flash operation encounters an error.
///
/// This event indicates that an attempt to control the camera flash
/// has failed. Common causes include:
/// - Flash not available on current camera
/// - Camera not initialized
/// - Hardware-level error
///
/// ```dart
/// if (event is TorchErrorEvent) {
///   showSnackBar('Flash error: ${event.error}');
/// }
/// ```
class TorchErrorEvent extends TwilioEvent {
  /// A description of the torch error that occurred.
  final String error;

  /// Creates a torch error event.
  TorchErrorEvent(this.error);
}

/// Emitted when the local audio track enabled state changes.
///
/// This event is fired when the local participant's audio is enabled
/// or disabled (muted/unmuted), providing the new state.
///
/// ```dart
/// if (event is LocalAudioEnabledEvent) {
///   setState(() {
///     isAudioEnabled = event.enabled;
///   });
///   print('Audio ${event.enabled ? 'unmuted' : 'muted'}');
/// }
/// ```
class LocalAudioEnabledEvent extends TwilioEvent {
  /// Whether the local audio track is now enabled.
  final bool enabled;

  /// Creates a local audio enabled event.
  LocalAudioEnabledEvent(this.enabled);
}

/// Emitted when the local video track enabled state changes.
///
/// This event is fired when the local participant's video is enabled
/// or disabled (camera on/off), providing the new state.
///
/// ```dart
/// if (event is LocalVideoEnabledEvent) {
///   setState(() {
///     isVideoEnabled = event.enabled;
///   });
///   print('Video ${event.enabled ? 'enabled' : 'disabled'}');
/// }
/// ```
class LocalVideoEnabledEvent extends TwilioEvent {
  /// Whether the local video track is now enabled.
  final bool enabled;

  /// Creates a local video enabled event.
  LocalVideoEnabledEvent(this.enabled);
}
