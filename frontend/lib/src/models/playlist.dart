class PlaylistModel {
  final int id;
  final String name;
  final int trackCount;

  const PlaylistModel({
    required this.id,
    required this.name,
    required this.trackCount,
  });

  factory PlaylistModel.fromJson(Map<String, dynamic> json) => PlaylistModel(
        id: json['id'] as int,
        name: json['name'] as String,
        trackCount: json['track_count'] as int,
      );
}
