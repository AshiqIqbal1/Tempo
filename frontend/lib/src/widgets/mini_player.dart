import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/src/models/track.dart';
import 'package:frontend/src/services/service.dart';
import 'package:frontend/src/widgets/full_player.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.read(audioHandlerProvider);

    return StreamBuilder<MediaItem?>(
      stream: handler.mediaItem,
      builder: (context, snap) {
        final item = snap.data;
        if (item == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const FullPlayer(),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 16,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    // content row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          // thumbnail
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: CachedNetworkImage(
                                imageUrl:
                                    '${TrackModel.baseUrl}/tracks/${item.id}/art/thumbnail',
                                fit: BoxFit.cover,
                                memCacheWidth: 192,
                                memCacheHeight: 192,
                                errorWidget: (_, _, _) => const ColoredBox(
                                  color: Colors.white12,
                                  child: Icon(Icons.music_note,
                                      color: Colors.white54, size: 24),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // title + artist
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.artist ?? '',
                                  maxLines: 1,
                                  style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.6),
                                    fontSize: 12,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // play/pause + next
                          StreamBuilder<PlaybackState>(
                            stream: handler.playbackState,
                            builder: (context, snap) {
                              final playing = snap.data?.playing ?? false;
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      playing
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                    onPressed: () => playing
                                        ? handler.pause()
                                        : handler.play(),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.skip_next_rounded,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                    onPressed: () => handler.skipToNext(),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    // progress line at bottom
                    Positioned(
                      bottom: 0,
                      left: 12,
                      right: 12,
                      child: RepaintBoundary(
                        child: StreamBuilder<Duration>(
                          stream: handler.player.positionStream,
                          builder: (context, snap) {
                            final position = snap.data ?? Duration.zero;
                            final duration =
                                handler.player.duration ?? Duration.zero;
                            final progress = duration.inMilliseconds > 0
                                ? position.inMilliseconds /
                                    duration.inMilliseconds
                                : 0.0;
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(1),
                              child: LinearProgressIndicator(
                                value: progress.clamp(0.0, 1.0),
                                minHeight: 2,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.1),
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
