import 'package:audio_service/audio_service.dart';
import 'package:frontend/src/models/track.dart';
import 'package:just_audio/just_audio.dart';

class TempoAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  TempoAudioHandler() {
    _listenToPlaybackState();
  }

  final _equalizer = AndroidEqualizer();
  AndroidEqualizer get equalizer => _equalizer;

  late final _player = AudioPlayer(
    audioPipeline: AudioPipeline(
      androidAudioEffects: [_equalizer],
    ),
  );
  AudioPlayer get player => _player;

  final List<TrackModel> _tracks = [];
  List<TrackModel> get tracks => List.unmodifiable(_tracks);

  bool get hasQueue => _tracks.isNotEmpty;

  void _broadcastState() {
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      playing: _player.playing,
      processingState: {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      shuffleMode: _player.shuffleModeEnabled
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
      repeatMode: {
        LoopMode.off: AudioServiceRepeatMode.none,
        LoopMode.one: AudioServiceRepeatMode.one,
        LoopMode.all: AudioServiceRepeatMode.all,
      }[_player.loopMode]!,
    ));
  }

  void _listenToPlaybackState() {
    _player.playbackEventStream.listen((_) => _broadcastState());
    _player.playingStream.listen((_) => _broadcastState());
    _player.processingStateStream.listen((_) => _broadcastState());

    _player.currentIndexStream.listen((index) {
      if (index == null || index >= _tracks.length) return;
      final track = _tracks[index];
      mediaItem.add(MediaItem(
        id: track.id.toString(),
        title: track.title,
        artist: track.artist,
        album: track.album,
        artUri: Uri.parse(track.artUrl),
        duration: track.durationValue,
      ));
    });

    _player.sequenceStateStream.listen((_) {
      queue.add(_tracks
          .map((t) => MediaItem(
                id: t.id.toString(),
                title: t.title,
                artist: t.artist,
                album: t.album,
              ))
          .toList());
    });
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  Future<void> loadQueue(List<TrackModel> tracks, int initialIndex) async {
    _tracks
      ..clear()
      ..addAll(tracks);

    // Broadcast immediately so mini player + notification show up
    final track = tracks[initialIndex];
    mediaItem.add(MediaItem(
      id: track.id.toString(),
      title: track.title,
      artist: track.artist,
      album: track.album,
      artUri: Uri.parse(track.artUrl),
      duration: track.durationValue,
    ));

    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      playing: true,
      processingState: AudioProcessingState.loading,
      updatePosition: Duration.zero,
    ));

    final sources =
        tracks.map((t) => AudioSource.uri(Uri.parse(t.streamUrl))).toList();
    await _player.setAudioSources(sources,
        initialIndex: initialIndex, preload: false);
    _player.play();
  }

  Future<void> appendToQueue(List<TrackModel> newTracks) async {
    _tracks.addAll(newTracks);
    final sources =
        newTracks.map((t) => AudioSource.uri(Uri.parse(t.streamUrl))).toList();
    _player.addAudioSources(sources);
  }

  void toggleShuffle() {
    _player.setShuffleModeEnabled(!_player.shuffleModeEnabled);
  }

  void cycleLoopMode() {
    final modes = [LoopMode.off, LoopMode.all, LoopMode.one];
    final next = (modes.indexOf(_player.loopMode) + 1) % modes.length;
    _player.setLoopMode(modes[next]);
  }

  int? get currentIndex => _player.currentIndex;

  TrackModel? get currentTrack {
    final idx = _player.currentIndex;
    if (idx == null || idx >= _tracks.length) return null;
    return _tracks[idx];
  }

  List<TrackModel> get upcomingTracks {
    final idx = _player.currentIndex;
    if (idx == null || idx >= _tracks.length - 1) return [];
    return _tracks.sublist(idx + 1);
  }

  void skipToIndex(int index) {
    _player.seek(Duration.zero, index: index);
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= _tracks.length) return;
    _tracks.removeAt(index);
    _player.removeAudioSourceAt(index);
  }
}
