import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TwilioRemoteVideoView extends StatefulWidget {
  final String participantSid;
  final double? width;
  final double? height;
  final BoxFit fit;

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
    return Container(
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
