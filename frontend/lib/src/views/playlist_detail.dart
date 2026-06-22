import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/src/audio/handler.dart';
import 'package:frontend/src/models/playlist.dart';
import 'package:frontend/src/models/track.dart';
import 'package:frontend/src/services/service.dart';
import 'package:http/http.dart' as http;

class PlaylistDetailView extends ConsumerStatefulWidget {
  final PlaylistModel playlist;
  const PlaylistDetailView({super.key, required this.playlist});

  @override
  ConsumerState<PlaylistDetailView> createState() =>
      _PlaylistDetailViewState();
}

class _PlaylistDetailViewState extends ConsumerState<PlaylistDetailView> {
  static const _pageSize = 20;
  final List<TrackModel> _tracks = [];
  int _offset = 0;
  bool _hasMore = true;
  bool _loading = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchTracks();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _fetchTracks() async {
    try {
      final response = await http.get(Uri.parse(
          '${TrackModel.baseUrl}/playlists/${widget.playlist.id}/tracks?limit=$_pageSize&offset=0'));
      if (response.statusCode == 200) {
        final List<dynamic> json = jsonDecode(response.body);
        final tracks = json.map((e) => TrackModel.fromJson(e)).toList();
        setState(() {
          _tracks.addAll(tracks);
          _offset = tracks.length;
          _hasMore = tracks.length == _pageSize;
          _loading = false;
        });
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final response = await http.get(Uri.parse(
          '${TrackModel.baseUrl}/playlists/${widget.playlist.id}/tracks?limit=$_pageSize&offset=$_offset'));
      if (response.statusCode == 200) {
        final List<dynamic> json = jsonDecode(response.body);
        final newTracks = json.map((e) => TrackModel.fromJson(e)).toList();
        setState(() {
          _tracks.addAll(newTracks);
          _offset += newTracks.length;
          _hasMore = newTracks.length == _pageSize;
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final handler = ref.read(audioHandlerProvider);

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
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
              title: Text(
                widget.playlist.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              background: const ColoredBox(color: Color(0xFF0A0A0A)),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_tracks.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text('No tracks in this playlist',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4))),
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 16, 8),
                child: Row(
                  children: [
                    Text(
                      '${widget.playlist.trackCount} tracks',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => handler.loadQueue(_tracks, 0),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('Play All'),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index >= _tracks.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final track = _tracks[index];
                  return _PlaylistTrackTile(
                    track: track,
                    index: index,
                    handler: handler,
                    onTap: () => handler.loadQueue(_tracks, index),
                  );
                },
                childCount: _tracks.length + (_hasMore ? 1 : 0),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }
}

class _PlaylistTrackTile extends StatelessWidget {
  final TrackModel track;
  final int index;
  final TempoAudioHandler handler;
  final VoidCallback onTap;

  const _PlaylistTrackTile({
    required this.track,
    required this.index,
    required this.handler,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: handler.mediaItem,
      builder: (context, snap) {
        final isPlaying = snap.data?.id == track.id.toString();
        return InkWell(
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: isPlaying
                      ? const Icon(Icons.equalizer_rounded,
                          color: Colors.greenAccent, size: 18)
                      : Text(
                          '${index + 1}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color:
                                Colors.white.withValues(alpha: 0.25),
                            fontSize: 13,
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: CachedNetworkImage(
                      imageUrl: track.thumbnailUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 256,
                      memCacheHeight: 256,
                      errorWidget: (_, _, _) => Container(
                        color: Colors.white.withValues(alpha: 0.05),
                        child: const Icon(Icons.music_note,
                            color: Colors.white24, size: 24),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        style: TextStyle(
                          color: isPlaying
                              ? Colors.greenAccent
                              : Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track.artist,
                        maxLines: 1,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 13,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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
