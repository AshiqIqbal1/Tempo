import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/src/models/track.dart';
import 'package:frontend/src/services/service.dart';

class QueueSheet extends ConsumerWidget {
  const QueueSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.read(audioHandlerProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              children: [
                const Text('Queue',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${handler.upcomingTracks.length} upcoming',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 13)),
              ],
            ),
          ),
          // Now playing
          if (handler.currentTrack case final current?)
            _QueueTile(
              track: current,
              isPlaying: true,
              onTap: () {},
              onDismiss: null,
            ),
          Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Next up',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
          ),
          // Upcoming
          Expanded(
            child: ListView.builder(
              itemCount: handler.upcomingTracks.length,
              itemBuilder: (context, index) {
                final track = handler.upcomingTracks[index];
                final queueIndex = (handler.currentIndex ?? 0) + 1 + index;
                return _QueueTile(
                  track: track,
                  isPlaying: false,
                  onTap: () {
                    handler.skipToIndex(queueIndex);
                    Navigator.pop(context);
                  },
                  onDismiss: () => handler.removeFromQueue(queueIndex),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueTile extends StatelessWidget {
  final TrackModel track;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback? onDismiss;

  const _QueueTile({
    required this.track,
    required this.isPlaying,
    required this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final child = InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            if (isPlaying)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child:
                    Icon(Icons.equalizer, color: Colors.greenAccent, size: 18),
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 44,
                height: 44,
                child: CachedNetworkImage(
                  imageUrl: track.thumbnailUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 88,
                  memCacheHeight: 88,
                  errorWidget: (_, _, _) => Container(
                    color: Colors.white.withValues(alpha: 0.05),
                    child: const Icon(Icons.music_note,
                        color: Colors.white24, size: 18),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(track.title,
                      maxLines: 1,
                      style: TextStyle(
                        color:
                            isPlaying ? Colors.greenAccent : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        overflow: TextOverflow.ellipsis,
                      )),
                  Text(track.artist,
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12,
                        overflow: TextOverflow.ellipsis,
                      )),
                ],
              ),
            ),
            if (!isPlaying)
              Icon(Icons.drag_handle,
                  color: Colors.white.withValues(alpha: 0.2), size: 20),
          ],
        ),
      ),
    );

    if (onDismiss != null) {
      return Dismissible(
        key: ValueKey('queue_${track.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: Colors.red.withValues(alpha: 0.3),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        onDismissed: (_) => onDismiss?.call(),
        child: child,
      );
    }
    return child;
  }
}
