import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TwilioLocalVideoView extends StatefulWidget {
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool mirror;

  const TwilioLocalVideoView({
    Key? key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.mirror = true,
  }) : super(key: key);

  @override
  State<TwilioLocalVideoView> createState() => _TwilioLocalVideoViewState();
}

class _TwilioLocalVideoViewState extends State<TwilioLocalVideoView> {
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
    return Container(
      width: widget.width,
      height: widget.height,
      child: Transform(
        alignment: Alignment.center,
        transform:
            widget.mirror ? Matrix4.rotationY(math.pi) : Matrix4.identity(),
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
      ),
    );
  }
}
