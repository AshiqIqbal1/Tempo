import 'dart:math';
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/src/audio/handler.dart';
import 'package:frontend/src/services/service.dart';
import 'package:frontend/src/widgets/queue_view.dart';
import 'package:just_audio/just_audio.dart';

class FullPlayer extends ConsumerWidget {
  const FullPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.read(audioHandlerProvider);
    final mq = MediaQuery.of(context);
    final isLandscape = mq.orientation == Orientation.landscape;
    final sheetHeight = isLandscape ? mq.size.height : mq.size.height * 0.95;

    return StreamBuilder<MediaItem?>(
      stream: handler.mediaItem,
      builder: (context, snapshot) {
        final item = snapshot.data;
        final artUrl = item?.artUri?.toString();

        return ClipRRect(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(isLandscape ? 0 : 12)),
          child: SizedBox(
            height: sheetHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (artUrl != null)
                  CachedNetworkImage(
                    imageUrl: artUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        const ColoredBox(color: Color(0xFF121212)),
                    errorWidget: (_, _, _) =>
                        const ColoredBox(color: Color(0xFF121212)),
                  )
                else
                  const ColoredBox(color: Color(0xFF121212)),
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: const SizedBox.expand(),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: isLandscape
                          ? Alignment.centerLeft
                          : Alignment.topCenter,
                      end: isLandscape
                          ? Alignment.centerRight
                          : Alignment.bottomCenter,
                      colors: const [
                        Color(0x33000000),
                        Color(0xAA000000),
                        Color(0xDD000000),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
                SafeArea(
                  child: OrientationBuilder(
                    builder: (context, orientation) {
                      final isLandscape =
                          orientation == Orientation.landscape;
                      return isLandscape
                          ? _LandscapeContent(
                              handler: handler,
                              item: item,
                              artUrl: artUrl)
                          : _PortraitContent(
                              handler: handler,
                              item: item,
                              artUrl: artUrl);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WaveformTimeline extends StatelessWidget {
  final TempoAudioHandler handler;
  const _WaveformTimeline({required this.handler});

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: handler.player.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final playerDur = handler.player.duration;
        final mediaDur = handler.mediaItem.valueOrNull?.duration;
        final duration = (playerDur != null && playerDur > Duration.zero)
            ? playerDur
            : (mediaDur ?? Duration.zero);
        final progress = duration.inMilliseconds > 0
            ? position.inMilliseconds / duration.inMilliseconds
            : 0.0;
        final remaining = duration - position;

        return Column(
          children: [
            GestureDetector(
              onTapDown: (details) {
                final box = context.findRenderObject() as RenderBox;
                final pct =
                    (details.localPosition.dx / box.size.width).clamp(0.0, 1.0);
                handler
                    .seek(Duration(
                        milliseconds:
                            (pct * duration.inMilliseconds).toInt()));
              },
              onHorizontalDragUpdate: (details) {
                final box = context.findRenderObject() as RenderBox;
                final local = box.globalToLocal(details.globalPosition);
                final pct = (local.dx / box.size.width).clamp(0.0, 1.0);
                handler.seek(Duration(
                    milliseconds: (pct * duration.inMilliseconds).toInt()));
              },
              child: SizedBox(
                height: 48,
                width: double.infinity,
                child: CustomPaint(
                  painter:
                      _WaveformPainter(progress: progress.clamp(0.0, 1.0)),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmt(position),
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                Text('-${_fmt(remaining)}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double progress;
  _WaveformPainter({required this.progress});

  static final _rng = Random(42);
  static final _heights =
      List.generate(60, (_) => 0.15 + _rng.nextDouble() * 0.85);

  @override
  void paint(Canvas canvas, Size size) {
    final barW = size.width / _heights.length;
    final gap = barW * 0.3;
    final w = barW - gap;
    for (int i = 0; i < _heights.length; i++) {
      final x = i * barW + gap / 2;
      final h = _heights[i] * size.height;
      final y = (size.height - h) / 2;
      final filled = i / _heights.length <= progress;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, w, h), const Radius.circular(2)),
        Paint()
          ..color = filled
              ? Colors.white.withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: 0.2),
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => old.progress != progress;
}

class _PlaybackControls extends StatelessWidget {
  final TempoAudioHandler handler;
  const _PlaybackControls({required this.handler});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackState>(
      stream: handler.playbackState,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data?.playing ?? false;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // shuffle
            StreamBuilder<bool>(
              stream: handler.player.shuffleModeEnabledStream,
              builder: (context, snap) {
                final on = snap.data ?? false;
                return IconButton(
                  onPressed: () => handler.toggleShuffle(),
                  icon: Icon(Icons.shuffle,
                      color: on
                          ? Colors.greenAccent
                          : Colors.white.withValues(alpha: 0.5)),
                  iconSize: 22,
                );
              },
            ),
            IconButton(
              onPressed: () => handler.skipToPrevious(),
              icon: const Icon(Icons.skip_previous_rounded),
              color: Colors.white,
              iconSize: 44,
            ),
            GestureDetector(
              onTap: () => isPlaying ? handler.pause() : handler.play(),
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.black,
                  size: 36,
                ),
              ),
            ),
            IconButton(
              onPressed: () => handler.skipToNext(),
              icon: const Icon(Icons.skip_next_rounded),
              color: Colors.white,
              iconSize: 44,
            ),
            // repeat
            StreamBuilder<LoopMode>(
              stream: handler.player.loopModeStream,
              builder: (context, snap) {
                final mode = snap.data ?? LoopMode.off;
                final IconData icon;
                final Color color;
                switch (mode) {
                  case LoopMode.off:
                    icon = Icons.repeat;
                    color = Colors.white.withValues(alpha: 0.5);
                  case LoopMode.all:
                    icon = Icons.repeat;
                    color = Colors.greenAccent;
                  case LoopMode.one:
                    icon = Icons.repeat_one;
                    color = Colors.greenAccent;
                }
                return IconButton(
                  onPressed: () => handler.cycleLoopMode(),
                  icon: Icon(icon, color: color),
                  iconSize: 22,
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _VolumeSlider extends StatelessWidget {
  final TempoAudioHandler handler;
  const _VolumeSlider({required this.handler});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: handler.player.volumeStream,
      builder: (context, snapshot) {
        final volume = snapshot.data ?? 1.0;
        return Row(
          children: [
            Icon(Icons.volume_down,
                color: Colors.white.withValues(alpha: 0.5), size: 18),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 5),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: Colors.white.withValues(alpha: 0.8),
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                  thumbColor: Colors.white,
                ),
                child: Slider(
                  value: volume.clamp(0.0, 1.0),
                  onChanged: (v) => handler.player.setVolume(v),
                ),
              ),
            ),
            Icon(Icons.volume_up,
                color: Colors.white.withValues(alpha: 0.5), size: 18),
          ],
        );
      },
    );
  }
}

Widget _artWidget(String? artUrl) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: artUrl == null
        ? Container(
            color: Colors.white.withValues(alpha: 0.05),
            child:
                const Icon(Icons.music_note, size: 80, color: Colors.white24),
          )
        : CachedNetworkImage(
            imageUrl: artUrl,
            fit: BoxFit.cover,
            placeholder: (_, _) =>
                Container(color: Colors.white.withValues(alpha: 0.05)),
            errorWidget: (_, _, _) => Container(
              color: Colors.white.withValues(alpha: 0.05),
              child: const Icon(Icons.music_note,
                  size: 80, color: Colors.white24),
            ),
          ),
  );
}

Widget _trackInfo(MediaItem? item) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        item?.title ?? '',
        maxLines: 1,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        item?.artist ?? '',
        maxLines: 1,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 14,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

class _PortraitContent extends StatelessWidget {
  final TempoAudioHandler handler;
  final MediaItem? item;
  final String? artUrl;
  const _PortraitContent(
      {required this.handler, required this.item, required this.artUrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.keyboard_arrow_down),
                color: Colors.white,
                iconSize: 28,
              ),
              Text(
                'Now Playing',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 24),
          AspectRatio(aspectRatio: 1, child: _artWidget(artUrl)),
          const SizedBox(height: 28),
          _trackInfo(item),
          const SizedBox(height: 20),
          _WaveformTimeline(handler: handler),
          const SizedBox(height: 28),
          _PlaybackControls(handler: handler),
          const SizedBox(height: 20),
          _VolumeSlider(handler: handler),
          const Spacer(),
          Center(
            child: IconButton(
              icon: Icon(Icons.queue_music,
                  color: Colors.white.withValues(alpha: 0.5)),
              onPressed: () => showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (_) => const QueueSheet(),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _LandscapeContent extends StatelessWidget {
  final TempoAudioHandler handler;
  final MediaItem? item;
  final String? artUrl;
  const _LandscapeContent(
      {required this.handler, required this.item, required this.artUrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // left: album art
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AspectRatio(aspectRatio: 1, child: _artWidget(artUrl)),
            ),
          ),
          const SizedBox(width: 24),
          // right: controls
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _trackInfo(item)),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.keyboard_arrow_down),
                        color: Colors.white.withValues(alpha: 0.7),
                        iconSize: 24,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _WaveformTimeline(handler: handler),
                  const SizedBox(height: 12),
                  _PlaybackControls(handler: handler),
                  const SizedBox(height: 8),
                  _VolumeSlider(handler: handler),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
