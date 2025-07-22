class LocalParticipant {
  final String identity;
  final String sid;
  final bool isAudioEnabled;
  final bool isVideoEnabled;
  final bool isAudioPublished;
  final bool isVideoPublished;

  LocalParticipant({
    required this.identity,
    required this.sid,
    required this.isAudioEnabled,
    required this.isVideoEnabled,
    required this.isAudioPublished,
    required this.isVideoPublished,
  });

  factory LocalParticipant.fromJson(Map<String, dynamic> json) {
    return LocalParticipant(
      identity: json['identity'],
      sid: json['sid'],
      isAudioEnabled: json['isAudioEnabled'],
      isVideoEnabled: json['isVideoEnabled'],
      isAudioPublished: json['isAudioPublished'],
      isVideoPublished: json['isVideoPublished'],
    );
  }
}
