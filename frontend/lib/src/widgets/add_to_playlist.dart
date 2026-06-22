import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:frontend/src/models/playlist.dart';
import 'package:frontend/src/models/track.dart';
import 'package:http/http.dart' as http;

Future<void> showAddToPlaylistDialog(BuildContext context, TrackModel track) async {
  final response =
      await http.get(Uri.parse('${TrackModel.baseUrl}/playlists'));
  if (response.statusCode != 200) return;

  final List<dynamic> json = jsonDecode(response.body);
  final playlists = json.map((e) => PlaylistModel.fromJson(e)).toList();

  if (!context.mounted) return;

  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1A1A1A),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text('Add to playlist',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(track.title,
              maxLines: 1,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                  overflow: TextOverflow.ellipsis)),
          const SizedBox(height: 16),
          ...playlists.map((p) => ListTile(
                leading: const Icon(Icons.queue_music, color: Colors.white54),
                title: Text(p.name,
                    style: const TextStyle(color: Colors.white)),
                subtitle: Text('${p.trackCount} tracks',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12)),
                onTap: () async {
                  await http.post(
                    Uri.parse(
                        '${TrackModel.baseUrl}/playlists/${p.id}/tracks'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({'track_id': track.id}),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text('Added to ${p.name}')),
                    );
                  }
                },
              )),
        ],
      ),
    ),
  );
}
