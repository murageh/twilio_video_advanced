import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twilio_video_advanced/twilio_video_advanced_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelTwilioVideoAdvanced platform =
      MethodChannelTwilioVideoAdvanced();
  const MethodChannel channel = MethodChannel('twilio_video_advanced');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return '42';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
