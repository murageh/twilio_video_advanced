import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A widget that displays a remote participant's video feed.
///
/// This widget renders video from a specific remote participant using native
/// video rendering for optimal performance. It automatically handles video
/// track subscription and updates when the participant's video state changes.
///
/// Each remote video view is tied to a specific participant via their [participantSid].
/// The widget will automatically display video when the participant publishes
/// a video track and hide it when they stop broadcasting.
///
/// ```dart
/// // Basic usage - shows remote participant's video
/// TwilioRemoteVideoView(
///   participantSid: participant.sid,
///   width: 200,
///   height: 150,
/// )
///
/// // Full-screen remote video
/// TwilioRemoteVideoView(
///   participantSid: participant.sid,
///   width: double.infinity,
///   height: double.infinity,
/// )
/// ```
class TwilioRemoteVideoView extends StatefulWidget {
  /// The SID of the participant whose video should be displayed.
  ///
  /// This must match the SID of a [RemoteParticipant] who has joined the room.
  /// The widget will automatically show video when this participant publishes
  /// a video track.
  final String participantSid;

  /// The width of the video view.
  ///
  /// If null, the widget will expand to fill available width based on
  /// its parent's constraints.
  final double? width;

  /// The height of the video view.
  ///
  /// If null, the widget will expand to fill available height based on
  /// its parent's constraints.
  final double? height;

  /// How the video should be scaled within the widget bounds.
  ///
  /// Defaults to [BoxFit.cover] which scales the video to cover the entire
  /// widget area while maintaining aspect ratio.
  final BoxFit fit;

  /// Creates a remote video view widget.
  const TwilioRemoteVideoView({
    super.key,
    required this.participantSid,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  State<TwilioRemoteVideoView> createState() => _TwilioRemoteVideoViewState();
}

class _TwilioRemoteVideoViewState extends State<TwilioRemoteVideoView> {
  /// Prints debug information in debug mode.
  void debug(String message) {
    if (kDebugMode) {
      print('TwilioRemoteVideoView(${widget.participantSid}): $message');
    }
  }

  @override
  void initState() {
    super.initState();
    debug('Creating remote video view');
  }

  @override
  void dispose() {
    debug('Disposing remote video view');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debug('Building remote video view');
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AndroidView(
          viewType: 'twilio_remote_video_view',
          creationParams: {'participantSid': widget.participantSid},
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: (int id) {
            debug('Platform view created with ID: $id');
          },
        ),
      ),
    );
  }
}
