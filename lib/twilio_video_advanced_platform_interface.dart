import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'twilio_video_advanced_method_channel.dart';

abstract class TwilioVideoAdvancedPlatform extends PlatformInterface {
  /// Constructs a TwilioVideoAdvancedPlatform.
  TwilioVideoAdvancedPlatform() : super(token: _token);

  static final Object _token = Object();

  static TwilioVideoAdvancedPlatform _instance =
      MethodChannelTwilioVideoAdvanced();

  /// The default instance of [TwilioVideoAdvancedPlatform] to use.
  ///
  /// Defaults to [MethodChannelTwilioVideoAdvanced].
  static TwilioVideoAdvancedPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [TwilioVideoAdvancedPlatform] when
  /// they register themselves.
  static set instance(TwilioVideoAdvancedPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
