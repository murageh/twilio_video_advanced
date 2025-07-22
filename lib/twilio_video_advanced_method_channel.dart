import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'twilio_video_advanced_platform_interface.dart';

/// An implementation of [TwilioVideoAdvancedPlatform] that uses method channels.
class MethodChannelTwilioVideoAdvanced extends TwilioVideoAdvancedPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('twilio_video_advanced');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
