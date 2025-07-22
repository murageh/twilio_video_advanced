import 'twilio_video_advanced_platform_interface.dart';

class TwilioVideoAdvanced {
  Future<String?> getPlatformVersion() {
    return TwilioVideoAdvancedPlatform.instance.getPlatformVersion();
  }
}
