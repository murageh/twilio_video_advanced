import 'package:flutter/material.dart';

import '../models/remote_participant.dart';
import 'twilio_remote_video_view.dart';

class TwilioParticipantsGrid extends StatelessWidget {
  final List<RemoteParticipant> participants;
  final RemoteParticipant? dominantSpeaker;

  const TwilioParticipantsGrid({
    super.key,
    required this.participants,
    this.dominantSpeaker,
  });

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return const Center(child: Text('No participants yet'));
    }

    return GridView.builder(
      key: ValueKey('grid_${participants.map((p) => p.sid).join('_')}'),
      // Force rebuild when participants change
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: participants.length == 1 ? 1 : 2,
        childAspectRatio: 16 / 9,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        final participant = participants[index];
        final isDominant = dominantSpeaker?.sid == participant.sid;

        return Container(
          key: ValueKey('container_${participant.sid}'),
          // Unique key for container
          decoration: BoxDecoration(
            border: Border.all(
              color: isDominant ? Colors.green : Colors.transparent,
              width: 3,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              TwilioRemoteVideoView(
                key: ValueKey(
                  'remote_${participant.sid}_${DateTime.now().millisecondsSinceEpoch}',
                ),
                // Force unique key with timestamp
                participantSid: participant.sid,
                width: double.infinity,
                height: double.infinity,
              ),
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${participant.identity} (${participant.sid})',
                    // Show SID for debugging
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
              if (isDominant)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(Icons.volume_up, color: Colors.green, size: 20),
                ),
            ],
          ),
        );
      },
    );
  }
}
