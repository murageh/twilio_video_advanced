class RemoteParticipant {
  final String identity;
  final String sid;
  final bool isConnected;

  RemoteParticipant({
    required this.identity,
    required this.sid,
    required this.isConnected,
  });

  factory RemoteParticipant.fromJson(Map<String, dynamic> json) {
    return RemoteParticipant(
      identity: json['identity'],
      sid: json['sid'],
      isConnected: json['isConnected'],
    );
  }
}
