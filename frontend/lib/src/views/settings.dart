import 'package:flutter/material.dart';
import 'package:frontend/src/models/track.dart';
import 'package:frontend/src/widgets/equalizer.dart';
import 'package:http/http.dart' as http;

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: const Color(0xFF0A0A0A),
          surfaceTintColor: Colors.transparent,
          pinned: true,
          expandedHeight: 100,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
            title: const Text(
              'Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            background: const ColoredBox(color: Color(0xFF0A0A0A)),
          ),
        ),
        SliverToBoxAdapter(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.equalizer, color: Colors.white70),
                title: const Text('Equalizer',
                    style: TextStyle(color: Colors.white)),
                subtitle: Text('Adjust sound frequencies',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12)),
                trailing: Icon(Icons.chevron_right,
                    color: Colors.white.withValues(alpha: 0.3)),
                onTap: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const EqualizerSheet(),
                ),
              ),
              _ScanTile(),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScanTile extends StatefulWidget {
  @override
  State<_ScanTile> createState() => _ScanTileState();
}

class _ScanTileState extends State<_ScanTile> {
  bool _scanning = false;

  Future<void> _triggerScan() async {
    setState(() => _scanning = true);
    try {
      await http.post(Uri.parse('${TrackModel.baseUrl}/scan'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scan started — pull to refresh library')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not reach server')),
        );
      }
    }
    setState(() => _scanning = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _scanning
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.refresh, color: Colors.white70),
      title: const Text('Rescan Library',
          style: TextStyle(color: Colors.white)),
      subtitle: Text('Scan for new music files',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
      trailing: Icon(Icons.chevron_right,
          color: Colors.white.withValues(alpha: 0.3)),
      onTap: _scanning ? null : _triggerScan,
    );
  }
}
