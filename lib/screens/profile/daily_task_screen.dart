import 'package:flutter/material.dart';
import './progression_center_screen.dart';

class DailyTaskScreen extends StatelessWidget {
  final String? initialCategory;

  const DailyTaskScreen({Key? key, this.initialCategory}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const ProgressionCenterScreen();
  }
}
