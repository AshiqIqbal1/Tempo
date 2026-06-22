import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/src/models/playlist.dart';
import 'package:frontend/src/models/track.dart';
import 'package:frontend/src/views/playlist_detail.dart';
import 'package:http/http.dart' as http;

class PlaylistsView extends ConsumerStatefulWidget {
  const PlaylistsView({super.key});

  @override
  ConsumerState<PlaylistsView> createState() => _PlaylistsViewState();
}

class _PlaylistsViewState extends ConsumerState<PlaylistsView> {
  List<PlaylistModel> _playlists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchPlaylists();
  }

  Future<void> _fetchPlaylists() async {
    try {
      final response =
          await http.get(Uri.parse('${TrackModel.baseUrl}/playlists'));
      if (response.statusCode == 200) {
        final List<dynamic> json = jsonDecode(response.body);
        setState(() {
          _playlists =
              json.map((e) => PlaylistModel.fromJson(e)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Playlist fetch error: $e');
      setState(() => _loading = false);
    }
  }

  void _showCreateDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('New Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Playlist name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await http.post(
                Uri.parse('${TrackModel.baseUrl}/playlists'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'name': controller.text.trim()}),
              );
              _fetchPlaylists();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: const Color(0xFF1A1A1A),
      onRefresh: _fetchPlaylists,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: const Color(0xFF0A0A0A),
            surfaceTintColor: Colors.transparent,
            pinned: true,
            expandedHeight: 100,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: const Text(
                'Playlists',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              background: const ColoredBox(color: Color(0xFF0A0A0A)),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: _showCreateDialog,
              ),
              const SizedBox(width: 8),
            ],
          ),
          if (_playlists.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.queue_music,
                        color: Colors.white.withValues(alpha: 0.2), size: 64),
                    const SizedBox(height: 16),
                    Text('No playlists yet',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4))),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: _showCreateDialog,
                      child: const Text('Create one'),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final playlist = _playlists[index];
                  return InkWell(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PlaylistDetailView(playlist: playlist),
                        ),
                      );
                      _fetchPlaylists();
                    },
                    onLongPress: () => _showDeleteDialog(playlist),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.queue_music,
                                color: Colors.white54, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  playlist.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${playlist.trackCount} tracks',
                                  style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.5),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              color: Colors.white.withValues(alpha: 0.3)),
                        ],
                      ),
                    ),
                  );
                },
                childCount: _playlists.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }

  void _showDeleteDialog(PlaylistModel playlist) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete playlist?'),
        content: Text('Delete "${playlist.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await http.delete(
                  Uri.parse('${TrackModel.baseUrl}/playlists/${playlist.id}'));
              _fetchPlaylists();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
