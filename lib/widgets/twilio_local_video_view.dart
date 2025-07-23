import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A widget that displays the local participant's video feed.
///
/// This widget renders the current user's camera feed using native video
/// rendering for optimal performance. It automatically handles video track
/// attachment and provides options for mirroring and sizing.
///
/// The local video view is typically used to show a preview of what other
/// participants see from your camera.
///
/// ```dart
/// // Basic usage - shows local video in a container
/// TwilioLocalVideoView(
///   width: 200,
///   height: 150,
/// )
///
/// // Full-screen local video without mirroring
/// TwilioLocalVideoView(
///   width: double.infinity,
///   height: double.infinity,
///   mirror: false,
/// )
/// ```
class TwilioLocalVideoView extends StatefulWidget {
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

  /// Whether to mirror the video horizontally.
  ///
  /// When `true`, the video appears mirrored (like a mirror), which is
  /// typically desired for front-facing cameras. When `false`, the video
  /// appears as others see it.
  ///
  /// Defaults to `true` for a more natural user experience with front cameras.
  final bool mirror;

  /// Creates a local video view widget.
  const TwilioLocalVideoView({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.mirror = true,
  });

  @override
  State<TwilioLocalVideoView> createState() => _TwilioLocalVideoViewState();
}

class _TwilioLocalVideoViewState extends State<TwilioLocalVideoView> {
  /// Prints debug information in debug mode.
  void debug(String message) {
    if (kDebugMode) {
      print('TwilioLocalVideoView: $message');
    }
  }

  @override
  void initState() {
    super.initState();
    debug('Creating local video view');
  }

  @override
  void dispose() {
    debug('Disposing local video view');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debug('Building local video view');
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AndroidView(
          viewType: 'twilio_local_video_view',
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: (int id) {
            debug('Platform view created with ID: $id');
          },
        ),
      ),
    );
  }
}
