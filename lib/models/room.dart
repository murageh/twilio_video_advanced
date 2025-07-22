import 'package:flutter/foundation.dart';
import 'package:twilio_video_advanced/models/remote_participant.dart';

import 'local_participant.dart';

class Room {
  final String name;
  final String sid;
  final int state; // 0=connected, 1=connecting, 2=disconnected, 3=reconnecting
  final LocalParticipant localParticipant;
  final List<RemoteParticipant> remoteParticipants;

  Room({
    required this.name,
    required this.sid,
    required this.state,
    required this.localParticipant,
    this.remoteParticipants = const [],
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    void debug(String message) {
      if (kDebugMode) {
        print('Room::DEBUG: $message');
      }
    }

    // extract remote participants from JSON
    List<RemoteParticipant> remoteParticipants = [];
    debug('Room.fromJson: json=$json');
    debug(
      'Room.fromJson: json.remoteParticipants=${json['remoteParticipants']}',
    );
    if (json['remoteParticipants'] != null) {
      remoteParticipants =
          (json['remoteParticipants'] as List)
              .map(
                (p) => RemoteParticipant.fromJson(Map<String, dynamic>.from(p)),
              )
              .toList();
    }

    debug(
      'Room.fromJson: name=${json['name']}, sid=${json['sid']}, state=${json['state']}, localParticipant=${json['localParticipant']} remoteParticipants=${remoteParticipants.length}',
    );

    return Room(
      name: json['name'],
      sid: json['sid'],
      state: json['state'],
      localParticipant: LocalParticipant.fromJson(
        Map<String, dynamic>.from(json['localParticipant']),
      ),
      remoteParticipants: remoteParticipants,
    );
  }

  void debug(String message) {
    if (kDebugMode) {
      print('Room::DEBUG: $message');
    }
  }
}
