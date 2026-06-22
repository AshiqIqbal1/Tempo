const _baseUrl = 'http://100.80.35.106:8081';

class TrackModel {
  static String get baseUrl => _baseUrl;
  final int id;
  final String title;
  final String artist;
  final String album;
  final String path;
  final double duration;

  const TrackModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.path,
    required this.duration,
  });

  factory TrackModel.fromJson(Map<String, dynamic> json) => TrackModel(
        id: json['id'] as int,
        title: json['title'] as String,
        artist: json['artist'] as String,
        album: json['album'] as String,
        path: json['path'] as String,
        duration: (json['duration'] as num?)?.toDouble() ?? 0,
      );

  Duration get durationValue => Duration(milliseconds: (duration * 1000).toInt());

  String get streamUrl => '$_baseUrl/tracks/$id/stream';
  String get artUrl => '$_baseUrl/tracks/$id/art';
  String get thumbnailUrl => '$_baseUrl/tracks/$id/art/thumbnail';
}
