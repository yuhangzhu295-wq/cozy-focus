import 'package:flutter/material.dart';

/// Phase 1 entry point — placeholder shell.
/// UI pages will be wired in Phase 2.
void main() {
  runApp(const CozyFocusApp());
}

class CozyFocusApp extends StatelessWidget {
  const CozyFocusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cozy Focus',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6B9E78)),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(child: Text('Cozy Focus — Phase 1 scaffold')),
      ),
    );
  }
}
