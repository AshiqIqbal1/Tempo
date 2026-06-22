import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/src/audio/handler.dart';
import 'package:frontend/src/models/track.dart';
import 'package:frontend/src/services/service.dart';
import 'package:http/http.dart' as http;

class Library extends ConsumerStatefulWidget {
  const Library({super.key});

  @override
  ConsumerState<Library> createState() => _LibraryState();
}

class _LibraryState extends ConsumerState<Library> {
  static const _pageSize = 20;

  final List<TrackModel> _tracks = [];
  int _offset = 0;
  bool _hasMore = true;
  late Future<List<TrackModel>> _tracksFuture;
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

  Future<List<TrackModel>> _fetchTracks({
    required int offset,
    required int limit,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
            '${TrackModel.baseUrl}/tracks?offset=$offset&limit=$limit'),
      );
      if (response.statusCode != 200) return [];
      final List<dynamic> json = jsonDecode(response.body);
      return json.map((e) => TrackModel.fromJson(e)).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  void initState() {
    super.initState();
    _tracksFuture = _fetchTracks(offset: 0, limit: _pageSize).then((tracks) {
      setState(() {
        _tracks.addAll(tracks);
        _offset = tracks.length;
        _hasMore = tracks.length == _pageSize;
      });
      return tracks;
    });
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

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final newTracks = await _fetchTracks(offset: _offset, limit: _pageSize);
      final handler = ref.read(audioHandlerProvider);
      if (handler.hasQueue) {
        handler.appendToQueue(newTracks);
      }
      setState(() {
        _tracks.addAll(newTracks);
        _offset += newTracks.length;
        _hasMore = newTracks.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() => _isLoadingMore = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load more: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final handler = ref.read(audioHandlerProvider);

    return Scaffold(
      body: FutureBuilder(
        future: _tracksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      color: Colors.white24, size: 56),
                  const SizedBox(height: 16),
                  Text('Could not load library',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 16)),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () => setState(() {
                      _tracks.clear();
                      _offset = 0;
                      _hasMore = true;
                      _tracksFuture =
                          _fetchTracks(offset: 0, limit: _pageSize).then((t) {
                        setState(() {
                          _tracks.addAll(t);
                          _offset = t.length;
                          _hasMore = t.length == _pageSize;
                        });
                        return t;
                      });
                    }),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: Colors.white,
            backgroundColor: const Color(0xFF1A1A1A),
            onRefresh: () async {
              try {
                final tracks =
                    await _fetchTracks(offset: 0, limit: _pageSize);
                setState(() {
                  _tracks
                    ..clear()
                    ..addAll(tracks);
                  _offset = tracks.length;
                  _hasMore = tracks.length == _pageSize;
                });
              } catch (_) {}
            },
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverAppBar(
                  backgroundColor: const Color(0xFF0A0A0A),
                  surfaceTintColor: Colors.transparent,
                  pinned: true,
                  expandedHeight: 100,
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding:
                        const EdgeInsets.only(left: 20, bottom: 16),
                    title: const Text(
                      'Library',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    background:
                        const ColoredBox(color: Color(0xFF0A0A0A)),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          '${_tracks.length}${_hasMore ? '+' : ''} tracks',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        if (_tracks.isNotEmpty)
                          TextButton.icon(
                            onPressed: () async {
                              try {
                                final response = await http.get(Uri.parse(
                                    '${TrackModel.baseUrl}/tracks/shuffle?limit=500'));
                                if (response.statusCode == 200) {
                                  final List<dynamic> json =
                                      jsonDecode(response.body);
                                  final shuffled = json
                                      .map((e) => TrackModel.fromJson(e))
                                      .toList();
                                  if (shuffled.isNotEmpty) {
                                    handler.loadQueue(shuffled, 0);
                                  }
                                }
                              } catch (_) {
                                handler.loadQueue(_tracks, 0);
                                handler.toggleShuffle();
                              }
                            },
                            icon: const Icon(Icons.shuffle, size: 18),
                            label: const Text('Shuffle'),
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
                          child:
                              Center(child: CircularProgressIndicator()),
                        );
                      }
                      final track = _tracks[index];
                      return _TrackTile(
                        track: track,
                        index: index,
                        handler: handler,
                        onTap: () => handler.loadQueue(_tracks, index),
                      );
                    },
                    childCount: _tracks.length + (_hasMore ? 1 : 0),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TrackTile extends StatelessWidget {
  final TrackModel track;
  final int index;
  final TempoAudioHandler handler;
  final VoidCallback onTap;
  const _TrackTile({
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
          splashColor: Colors.white.withValues(alpha: 0.05),
          highlightColor: Colors.white.withValues(alpha: 0.03),
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
                            color: Colors.white.withValues(alpha: 0.25),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
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
                      placeholder: (_, _) => Container(
                          color: Colors.white.withValues(alpha: 0.05)),
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
