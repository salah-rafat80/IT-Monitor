import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monitoring Settings')),
      body: const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(child: Text('Monitoring Settings & Data Import Ready')),
      ),
    );
  }
}
