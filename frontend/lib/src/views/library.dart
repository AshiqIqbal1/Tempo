import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/src/audio/handler.dart';
import 'package:frontend/src/models/track.dart';
import 'package:frontend/src/services/service.dart';
import 'package:frontend/src/views/artist_detail.dart';
import 'package:frontend/src/widgets/add_to_playlist.dart';
import 'package:http/http.dart' as http;

List<TrackModel> _parseTracks(String body) {
  final List<dynamic> json = jsonDecode(body);
  return json.map((e) => TrackModel.fromJson(e)).toList();
}

class Library extends ConsumerStatefulWidget {
  const Library({super.key});

  @override
  ConsumerState<Library> createState() => _LibraryState();
}

class _LibraryState extends ConsumerState<Library> {
  static const _maxTracks = 150;

  final List<TrackModel> _tracks = [];
  late Future<List<TrackModel>> _tracksFuture;

  Future<List<TrackModel>> _fetchRandomTracks() async {
    try {
      final response = await http.get(
        Uri.parse('${TrackModel.baseUrl}/tracks/shuffle?limit=$_maxTracks'),
      );
      if (response.statusCode != 200) return [];
      return compute(_parseTracks, response.body);
    } catch (e) {
      rethrow;
    }
  }

  @override
  void initState() {
    super.initState();
    _tracksFuture = _fetchRandomTracks().then((tracks) {
      setState(() {
        _tracks.addAll(tracks);
      });
      return tracks;
    });
  }


  Future<void> _loadMix(dynamic handler, int count) async {
    try {
      final response = await http.get(
          Uri.parse('${TrackModel.baseUrl}/tracks/shuffle?limit=$count'));
      if (response.statusCode == 200) {
        final List<dynamic> json = jsonDecode(response.body);
        final tracks = json.map((e) => TrackModel.fromJson(e)).toList();
        if (tracks.isNotEmpty) handler.loadQueue(tracks, 0);
      }
    } catch (_) {}
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
                      _tracksFuture = _fetchRandomTracks().then((t) {
                        setState(() => _tracks.addAll(t));
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
                final tracks = await _fetchRandomTracks();
                setState(() {
                  _tracks
                    ..clear()
                    ..addAll(tracks);
                });
              } catch (_) {}
            },
            child: CustomScrollView(
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
                // Today's Mixes
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                        child: Text('Today\'s Mixes',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            )),
                      ),
                      SizedBox(
                        height: 130,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          clipBehavior: Clip.none,
                          children: [
                            _MixCard(
                              title: 'Daily Mix',
                              subtitle: 'Your favourites shuffled',
                              color: const Color(0xFF1DB954),
                              icon: Icons.shuffle,
                              onTap: () => _loadMix(handler, 50),
                            ),
                            const SizedBox(width: 12),
                            _MixCard(
                              title: 'Discovery',
                              subtitle: 'Random deep cuts',
                              color: const Color(0xFF7B68EE),
                              icon: Icons.explore,
                              onTap: () => _loadMix(handler, 30),
                            ),
                            const SizedBox(width: 12),
                            _MixCard(
                              title: 'Long Play',
                              subtitle: '100 track marathon',
                              color: const Color(0xFFE91E63),
                              icon: Icons.all_inclusive,
                              onTap: () => _loadMix(handler, 100),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                // Browse by Artist/Album
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const _ArtistBrowser()),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.person,
                                      color:
                                          Colors.white.withValues(alpha: 0.6),
                                      size: 22),
                                  const SizedBox(width: 10),
                                  const Text('Artists',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const _AlbumBrowser()),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.album,
                                      color:
                                          Colors.white.withValues(alpha: 0.6),
                                      size: 22),
                                  const SizedBox(width: 10),
                                  const Text('Albums',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          '${_tracks.length} tracks',
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
                        onTap: () {
                          const window = 25;
                          final start =
                              (index - window).clamp(0, _tracks.length);
                          final end = (index + window + 1)
                              .clamp(0, _tracks.length);
                          handler.loadQueue(
                              _tracks.sublist(start, end), index - start);
                        },
                      );
                    },
                    childCount: _tracks.length,
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
          onLongPress: () => showAddToPlaylistDialog(context, track),
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

class _MixCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _MixCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.4),
              color.withValues(alpha: 0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtistBrowser extends StatefulWidget {
  const _ArtistBrowser();
  @override
  State<_ArtistBrowser> createState() => _ArtistBrowserState();
}

class _ArtistBrowserState extends State<_ArtistBrowser> {
  List<Map<String, dynamic>> _artists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final response =
          await http.get(Uri.parse('${TrackModel.baseUrl}/artists'));
      if (response.statusCode == 200) {
        final List<dynamic> json = jsonDecode(response.body);
        setState(() {
          _artists = json.cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              title: const Text('Artists',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800)),
              background: const ColoredBox(color: Color(0xFF0A0A0A)),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()))
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final a = _artists[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      child: const Icon(Icons.person,
                          color: Colors.white54, size: 20),
                    ),
                    title: Text(a['artist'] as String,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                    subtitle: Text('${a['track_count']} tracks',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 12)),
                    trailing: Icon(Icons.chevron_right,
                        color: Colors.white.withValues(alpha: 0.3)),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ArtistDetailView(
                          artist: a['artist'] as String,
                          trackCount: a['track_count'] as int,
                        ),
                      ),
                    ),
                  );
                },
                childCount: _artists.length,
              ),
            ),
        ],
      ),
    );
  }
}

class _AlbumBrowser extends StatefulWidget {
  const _AlbumBrowser();
  @override
  State<_AlbumBrowser> createState() => _AlbumBrowserState();
}

class _AlbumBrowserState extends State<_AlbumBrowser> {
  List<Map<String, dynamic>> _albums = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final response =
          await http.get(Uri.parse('${TrackModel.baseUrl}/albums'));
      if (response.statusCode == 200) {
        final List<dynamic> json = jsonDecode(response.body);
        setState(() {
          _albums = json.cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              title: const Text('Albums',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800)),
              background: const ColoredBox(color: Color(0xFF0A0A0A)),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()))
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final a = _albums[index];
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ArtistDetailView(
                            artist: a['artist'] as String,
                            trackCount: a['track_count'] as int,
                          ),
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl:
                                      '${TrackModel.baseUrl}/tracks/${a['first_track_id']}/art/thumbnail',
                                  fit: BoxFit.cover,
                                  memCacheWidth: 256,
                                  memCacheHeight: 256,
                                  errorWidget: (_, _, _) => Container(
                                    color: Colors.white
                                        .withValues(alpha: 0.05),
                                    child: const Center(
                                      child: Icon(Icons.album,
                                          color: Colors.white24, size: 40),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(a['album'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            Text(a['artist'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.4),
                                    fontSize: 11)),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: _albums.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
