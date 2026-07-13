import 'package:flutter/material.dart';

class DailyTaskScreen extends StatelessWidget {
  final String? initialCategory;

  const DailyTaskScreen({Key? key, this.initialCategory}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Daily Tasks', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: const Center(
        child: Text('This feature has been removed.', style: TextStyle(color: Colors.white70, fontSize: 16)),
      ),
    );
  }
}
