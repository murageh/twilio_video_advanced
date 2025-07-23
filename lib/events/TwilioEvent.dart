import '../models/remote_participant.dart';
import '../models/room.dart';

abstract class TwilioEvent {}

class RoomConnectedEvent extends TwilioEvent {
  final Room room;

  RoomConnectedEvent(this.room);
}

class RoomReconnectingEvent extends TwilioEvent {
  final Room room;

  RoomReconnectingEvent(this.room);
}

class RoomReconnectedEvent extends TwilioEvent {
  final Room room;

  RoomReconnectedEvent(this.room);
}

class RoomDisconnectedEvent extends TwilioEvent {
  final String? error;

  RoomDisconnectedEvent(this.error);
}

class ParticipantConnectedEvent extends TwilioEvent {
  final RemoteParticipant participant;

  ParticipantConnectedEvent(this.participant);
}

class ParticipantDisconnectedEvent extends TwilioEvent {
  final RemoteParticipant participant;

  ParticipantDisconnectedEvent(this.participant);
}

class DominantSpeakerChangedEvent extends TwilioEvent {
  final RemoteParticipant? participant;

  DominantSpeakerChangedEvent(this.participant);
}

class TrackSubscribedEvent extends TwilioEvent {
  final String participantSid;
  final String trackSid;
  final String trackType;

  TrackSubscribedEvent({
    required this.participantSid,
    required this.trackSid,
    required this.trackType,
  });
}

class TrackUnsubscribedEvent extends TwilioEvent {
  final String participantSid;
  final String trackSid;
  final String trackType;

  TrackUnsubscribedEvent({
    required this.participantSid,
    required this.trackSid,
    required this.trackType,
  });
}

class TorchStatusChangedEvent extends TwilioEvent {
  final bool isOn;
  final bool isAvailable;

  TorchStatusChangedEvent({
    required this.isOn,
    required this.isAvailable,
  });
}

class TorchErrorEvent extends TwilioEvent {
  final String error;

  TorchErrorEvent(this.error);
}
