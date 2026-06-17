import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

void main() {
  runApp(TempoApp());
}

class TempoApp extends StatefulWidget {
    TempoApp({super.key});

    @override
    State<TempoApp> createState() => _TempoState();
}

class _TempoState extends State<TempoApp> {

    final player = AudioPlayer();
    
    @override
    void initState() {
        super.initState();
        player.setUrl("http://100.113.131.17:8080/stream");
    }

    @override
    void dispose() {
        super.dispose();
        player.dispose();
    }

    @override
    Widget build(BuildContext context) {
        return MaterialApp (
            theme: ThemeData.dark(),
            home: Scaffold(
                body: Center(
                    child: PlayButton(onPressed: () => player.play()),
                ),
            )
        );
    } 
}

class PlayButton extends StatelessWidget {
    final VoidCallback onPressed;
    const PlayButton({super.key, required this.onPressed});

    @override
    Widget build(BuildContext context) {
        return ElevatedButton(
            onPressed: onPressed, 
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyan[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            ),
            child: const Text(
                "PLAY",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5
                ),
            ),
        );
    }
}