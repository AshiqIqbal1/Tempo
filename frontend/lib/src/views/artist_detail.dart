import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/src/models/track.dart';
import 'package:frontend/src/services/service.dart';
import 'package:frontend/src/widgets/add_to_playlist.dart';
import 'package:http/http.dart' as http;

class ArtistDetailView extends ConsumerStatefulWidget {
  final String artist;
  final int trackCount;
  const ArtistDetailView(
      {super.key, required this.artist, required this.trackCount});

  @override
  ConsumerState<ArtistDetailView> createState() => _ArtistDetailViewState();
}

class _ArtistDetailViewState extends ConsumerState<ArtistDetailView> {
  List<TrackModel> _tracks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final response = await http.get(Uri.parse(
          '${TrackModel.baseUrl}/artists/tracks?name=${Uri.encodeComponent(widget.artist)}'));
      if (response.statusCode == 200) {
        final List<dynamic> json = jsonDecode(response.body);
        setState(() {
          _tracks = json.map((e) => TrackModel.fromJson(e)).toList();
          _loading = false;
        });
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final handler = ref.read(audioHandlerProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: const Color(0xFF0A0A0A),
            surfaceTintColor: Colors.transparent,
            pinned: true,
            expandedHeight: 100,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
              title: Text(widget.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              background: const ColoredBox(color: Color(0xFF0A0A0A)),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()))
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 16, 8),
                child: Row(
                  children: [
                    Text('${_tracks.length} tracks',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 13)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => handler.loadQueue(_tracks, 0),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('Play All'),
                      style: TextButton.styleFrom(
                          foregroundColor:
                              Colors.white.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final track = _tracks[index];
                  return StreamBuilder<MediaItem?>(
                    stream: handler.mediaItem,
                    builder: (context, snap) {
                      final isPlaying =
                          snap.data?.id == track.id.toString();
                      return InkWell(
                        onTap: () => handler.loadQueue(_tracks, index),
                        onLongPress: () =>
                            showAddToPlaylistDialog(context, track),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: CachedNetworkImage(
                                    imageUrl: track.thumbnailUrl,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 192,
                                    memCacheHeight: 192,
                                    errorWidget: (_, _, _) => Container(
                                      color: Colors.white
                                          .withValues(alpha: 0.05),
                                      child: const Icon(Icons.music_note,
                                          color: Colors.white24,
                                          size: 20),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(track.title,
                                        maxLines: 1,
                                        style: TextStyle(
                                          color: isPlaying
                                              ? Colors.greenAccent
                                              : Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          overflow: TextOverflow.ellipsis,
                                        )),
                                    Text(track.album,
                                        maxLines: 1,
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.5),
                                          fontSize: 12,
                                          overflow: TextOverflow.ellipsis,
                                        )),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                childCount: _tracks.length,
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }
}
