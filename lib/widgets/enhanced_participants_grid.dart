import 'package:flutter/material.dart';

import '../models/remote_participant.dart';
import 'twilio_local_video_view.dart';
import 'twilio_remote_video_view.dart';

enum DominantParticipant { local, remote, none }

class EnhancedParticipantsGrid extends StatelessWidget {
  final List<RemoteParticipant> participants;
  final RemoteParticipant? dominantSpeaker;
  final bool isLocalVideoPublished;
  final DominantParticipant dominantParticipant;
  final Function(DominantParticipant) onDominantParticipantChanged;

  const EnhancedParticipantsGrid({
    super.key,
    required this.participants,
    this.dominantSpeaker,
    required this.isLocalVideoPublished,
    required this.dominantParticipant,
    required this.onDominantParticipantChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Determine layout based on participants
    if (participants.isEmpty && !isLocalVideoPublished) {
      return const Center(
        child: Text(
          'No video available',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      );
    }

    if (participants.isEmpty && isLocalVideoPublished) {
      // Only local video - show fullscreen
      return _buildSingleVideoView(
        child: const TwilioLocalVideoView(),
        label: 'You',
        isLocal: true,
      );
    }

    if (participants.length == 1 && isLocalVideoPublished) {
      // One remote + local - use dominant/PiP layout
      return _buildDominantPiPLayout();
    }

    if (participants.length == 1 && !isLocalVideoPublished) {
      // Only one remote participant
      final participant = participants.first;
      return _buildSingleVideoView(
        child: TwilioRemoteVideoView(
          key: ValueKey('remote_${participant.sid}'),
          participantSid: participant.sid,
          width: double.infinity,
          height: double.infinity,
        ),
        label: participant.identity,
        isLocal: false,
      );
    }

    // Multiple participants - use grid layout
    return _buildGridLayout();
  }

  Widget _buildSingleVideoView({
    required Widget child,
    required String label,
    required bool isLocal,
  }) {
    return Stack(
      children: [
        child,
        Positioned(
          bottom: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDominantPiPLayout() {
    final remoteParticipant = participants.first;
    final isDominantRemote = dominantParticipant == DominantParticipant.remote;

    return Stack(
      children: [
        // Dominant (fullscreen) video
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              // Switch dominance when tapping the background
              onDominantParticipantChanged(
                isDominantRemote
                    ? DominantParticipant.local
                    : DominantParticipant.remote,
              );
            },
            child:
                isDominantRemote
                    ? TwilioRemoteVideoView(
                      key: ValueKey('dominant_remote_${remoteParticipant.sid}'),
                      participantSid: remoteParticipant.sid,
                      width: double.infinity,
                      height: double.infinity,
                    )
                    : const TwilioLocalVideoView(
                      key: ValueKey('dominant_local'),
                    ),
          ),
        ),

        // Picture-in-Picture video (small, tappable)
        Positioned(
          bottom: 120,
          right: 16,
          child: GestureDetector(
            onTap: () {
              // Switch dominance when tapping PiP
              onDominantParticipantChanged(
                isDominantRemote
                    ? DominantParticipant.local
                    : DominantParticipant.remote,
              );
            },
            child: Container(
              width: 120,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDominantRemote ? Colors.blue : Colors.green,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  children: [
                    isDominantRemote
                        ? const TwilioLocalVideoView(key: ValueKey('pip_local'))
                        : TwilioRemoteVideoView(
                          key: ValueKey('pip_remote_${remoteParticipant.sid}'),
                          participantSid: remoteParticipant.sid,
                          width: double.infinity,
                          height: double.infinity,
                        ),

                    // PiP label
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (isDominantRemote ? Colors.blue : Colors.green)
                              .withOpacity(0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isDominantRemote ? 'You' : remoteParticipant.identity,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),

                    // Tap indicator
                    const Positioned(
                      bottom: 4,
                      right: 4,
                      child: Icon(
                        Icons.touch_app,
                        color: Colors.white70,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Dominant video label
        Positioned(
          bottom: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isDominantRemote ? Icons.person : Icons.videocam,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  isDominantRemote ? remoteParticipant.identity : 'You',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                if (dominantSpeaker?.sid == remoteParticipant.sid &&
                    isDominantRemote)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.volume_up, color: Colors.green, size: 16),
                  ),
              ],
            ),
          ),
        ),

        // Switch dominance hint
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Tap to switch',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGridLayout() {
    // Include local video in grid if published
    final allParticipants = <Widget>[];

    if (isLocalVideoPublished) {
      allParticipants.add(
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              const TwilioLocalVideoView(key: ValueKey('grid_local')),
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'You',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Add remote participants
    for (final participant in participants) {
      final isDominant = dominantSpeaker?.sid == participant.sid;

      allParticipants.add(
        Container(
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
                key: ValueKey('grid_remote_${participant.sid}'),
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
                    participant.identity,
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
        ),
      );
    }

    return GridView.count(
      key: ValueKey('grid_${allParticipants.length}'),
      crossAxisCount: allParticipants.length <= 2 ? 1 : 2,
      childAspectRatio: 16 / 9,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      padding: const EdgeInsets.all(8),
      children: allParticipants,
    );
  }
}
