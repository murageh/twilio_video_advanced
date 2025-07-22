import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:twilio_video_advanced/twilio_video_advanced.dart';

void main() {
  runApp(MyApp());
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<void> requestPermissions() async {
    await [
      Permission.camera,
      Permission.microphone,
    ].request();
  }

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await requestPermissions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Twilio Video Demo')),
      body: Center(
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        TwilioVideoCallScreen(
                          roomName: 'cool room',
                          accessToken: 'test-token',
                        ),
                  ),
                );
              },
              child: Text('Join Video Call as User 1'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        TwilioVideoCallScreen(
                          roomName: 'cool room',
                          accessToken: 'test-token',
                        ),
                  ),
                );
              },
              child: Text('Join Video Call as User 2'),
            ),
          ],
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomePage(),
    );
  }
}