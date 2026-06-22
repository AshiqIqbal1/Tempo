import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/src/models/track.dart';
import 'package:frontend/src/services/service.dart';
import 'package:http/http.dart' as http;

class SearchView extends ConsumerStatefulWidget {
  const SearchView({super.key});

  @override
  ConsumerState<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends ConsumerState<SearchView> {
  final _controller = TextEditingController();
  List<TrackModel> _results = [];
  bool _searching = false;
  Timer? _debounce;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 150), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() => _searching = true);
    try {
      final response = await http.get(Uri.parse(
          '${TrackModel.baseUrl}/tracks/search?q=${Uri.encodeComponent(query)}&limit=30'));
      if (response.statusCode == 200) {
        final List<dynamic> json = jsonDecode(response.body);
        setState(() {
          _results = json.map((e) => TrackModel.fromJson(e)).toList();
          _searching = false;
        });
      }
    } catch (_) {
      setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final handler = ref.read(audioHandlerProvider);

    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onQueryChanged,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Search tracks, artists, albums...',
                hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3), fontSize: 16),
                prefixIcon: Icon(Icons.search,
                    color: Colors.white.withValues(alpha: 0.4)),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear,
                            color: Colors.white.withValues(alpha: 0.4)),
                        onPressed: () {
                          _controller.clear();
                          _onQueryChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        if (_searching)
          const Padding(
            padding: EdgeInsets.only(top: 32),
            child: CircularProgressIndicator(),
          )
        else if (_results.isEmpty && _controller.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Text('No results',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4), fontSize: 16)),
          )
        else if (_results.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search,
                      size: 64, color: Colors.white.withValues(alpha: 0.15)),
                  const SizedBox(height: 16),
                  Text('Search your library',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 16)),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: StreamBuilder<MediaItem?>(
              stream: handler.mediaItem,
              builder: (context, mediSnap) {
                final currentId = mediSnap.data?.id;
                return ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final track = _results[index];
                    final isPlaying = currentId == track.id.toString();
                    return _SearchTile(
                      track: track,
                      isPlaying: isPlaying,
                      onTap: () => handler.loadQueue(_results, index),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

class _SearchTile extends StatelessWidget {
  final TrackModel track;
  final bool isPlaying;
  final VoidCallback onTap;

  const _SearchTile({
    required this.track,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                    color: Colors.white.withValues(alpha: 0.05),
                    child: const Icon(Icons.music_note,
                        color: Colors.white24, size: 20),
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
                      color: isPlaying ? Colors.greenAccent : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${track.artist} · ${track.album}',
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
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
  }
}
