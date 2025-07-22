import 'package:flutter_test/flutter_test.dart';
import 'package:twilio_video_advanced/twilio_video_advanced.dart';
import 'package:twilio_video_advanced/twilio_video_advanced_platform_interface.dart';
import 'package:twilio_video_advanced/twilio_video_advanced_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockTwilioVideoAdvancedPlatform
    with MockPlatformInterfaceMixin
    implements TwilioVideoAdvancedPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final TwilioVideoAdvancedPlatform initialPlatform =
      TwilioVideoAdvancedPlatform.instance;

  test('$MethodChannelTwilioVideoAdvanced is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelTwilioVideoAdvanced>());
  });

  test('getPlatformVersion', () async {
    TwilioVideoAdvanced twilioVideoAdvancedPlugin = TwilioVideoAdvanced();
    MockTwilioVideoAdvancedPlatform fakePlatform =
        MockTwilioVideoAdvancedPlatform();
    TwilioVideoAdvancedPlatform.instance = fakePlatform;

    expect(await twilioVideoAdvancedPlugin.getPlatformVersion(), '42');
  });
}
