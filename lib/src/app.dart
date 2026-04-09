import 'package:flutter/material.dart';

import 'features/viewer/viewer_screen.dart';

class UemsiHtvApp extends StatelessWidget {
  const UemsiHtvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HD Express Camera',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0A84FF)),
        useMaterial3: true,
      ),
      home: const ViewerScreen(),
    );
  }
}

