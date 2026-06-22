import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/src/services/service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Preset EQ profiles: name → [band gains in dB]
// 5-band: 60Hz, 230Hz, 910Hz, 3.6kHz, 14kHz
const _presets = <String, List<double>>{
  'Flat': [0, 0, 0, 0, 0],
  'Bass Boost': [6, 4, 0, 0, 0],
  'Treble Boost': [0, 0, 0, 4, 6],
  'Rock': [5, 3, -1, 3, 5],
  'Pop': [-1, 2, 5, 2, -1],
  'Jazz': [4, 2, -1, 2, 4],
  'Classical': [4, 2, 0, 2, 4],
  'Hip Hop': [5, 4, 0, 1, 3],
  'R&B': [3, 5, 2, -1, 3],
  'Electronic': [5, 3, 0, 2, 5],
  'Vocal': [-2, 0, 4, 3, -1],
};

class EqualizerSheet extends ConsumerStatefulWidget {
  const EqualizerSheet({super.key});

  @override
  ConsumerState<EqualizerSheet> createState() => _EqualizerSheetState();
}

class _EqualizerSheetState extends ConsumerState<EqualizerSheet> {
  bool _enabled = false;
  String _activePreset = 'Flat';
  List<double> _gains = [0, 0, 0, 0, 0];
  AndroidEqualizerParameters? _params;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final eq = ref.read(audioHandlerProvider).equalizer;
    final prefs = await SharedPreferences.getInstance();
    _activePreset = prefs.getString('eq_preset') ?? 'Flat';
    _enabled = prefs.getBool('eq_enabled') ?? false;

    try {
      _params = await eq.parameters.timeout(const Duration(seconds: 3));
    } catch (_) {
      // no audio session yet — will apply when track plays
    }

    if (_enabled) {
      await eq.setEnabled(true);
    }

    // Load saved gains
    final saved = prefs.getStringList('eq_gains');
    if (saved != null && saved.length == 5) {
      _gains = saved.map((s) => double.tryParse(s) ?? 0).toList();
    } else {
      _gains = List.of(_presets[_activePreset] ?? [0, 0, 0, 0, 0]);
    }

    _applyGains();
    if (mounted) setState(() => _ready = true);
  }

  void _applyGains() {
    final params = _params;
    if (params == null) return;
    final bands = params.bands;
    for (int i = 0; i < bands.length && i < _gains.length; i++) {
      bands[i].setGain(_gains[i]);
    }
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('eq_enabled', _enabled);
    prefs.setString('eq_preset', _activePreset);
    prefs.setStringList('eq_gains', _gains.map((g) => g.toString()).toList());
  }

  void _selectPreset(String name) {
    final gains = _presets[name];
    if (gains == null) return;
    setState(() {
      _activePreset = name;
      _gains = List.of(gains);
    });
    _applyGains();
    _saveState();
  }

  @override
  Widget build(BuildContext context) {
    final eq = ref.read(audioHandlerProvider).equalizer;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
          // header + toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Equalizer',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              Switch(
                value: _enabled,
                activeTrackColor: Colors.greenAccent,
                onChanged: (v) {
                  eq.setEnabled(v);
                  setState(() => _enabled = v);
                  _saveState();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          // presets
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _presets.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final name = _presets.keys.elementAt(i);
                final active = name == _activePreset;
                return GestureDetector(
                  onTap: () => _selectPreset(name),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.greenAccent.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: active
                          ? Border.all(color: Colors.greenAccent, width: 1)
                          : null,
                    ),
                    child: Text(
                      name,
                      style: TextStyle(
                        color: active ? Colors.greenAccent : Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // bands
          if (!_ready)
            const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()))
          else
            SizedBox(
              height: 220,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List.generate(_gains.length, (i) {
                  final freq = [60, 230, 910, 3600, 14000];
                  return Expanded(
                    child: _BandSlider(
                      gain: _gains[i],
                      freqHz: i < freq.length ? freq[i] : 0,
                      enabled: _enabled,
                      onChanged: (v) {
                        setState(() {
                          _gains[i] = v;
                          _activePreset = 'Custom';
                        });
                        _params?.bands[i].setGain(v);
                        _saveState();
                      },
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _BandSlider extends StatelessWidget {
  final double gain;
  final int freqHz;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const _BandSlider({
    required this.gain,
    required this.freqHz,
    required this.enabled,
    required this.onChanged,
  });

  String _formatFreq(int hz) {
    if (hz >= 1000) {
      return '${(hz / 1000).toStringAsFixed(hz >= 10000 ? 0 : 1)}k';
    }
    return '$hz';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${gain > 0 ? '+' : ''}${gain.toStringAsFixed(0)}',
          style: TextStyle(
            color: enabled
                ? Colors.white.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.3),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
                activeTrackColor: enabled
                    ? Colors.greenAccent
                    : Colors.white.withValues(alpha: 0.3),
                inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
                thumbColor: enabled
                    ? Colors.greenAccent
                    : Colors.white.withValues(alpha: 0.4),
              ),
              child: Slider(
                value: gain,
                min: -15,
                max: 15,
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ),
        ),
        Text(
          _formatFreq(freqHz),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
