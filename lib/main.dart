import 'package:flutter/material.dart';
import 'analytics_page.dart';
void main() {
  runApp(const ProfitApp());
}
class ProfitApp extends StatelessWidget {
  const ProfitApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Profit App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF07111F),
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF49D6FF),
          brightness: Brightness.dark,
          background: const Color(0xFF07111F),
        ),
        useMaterial3: true,
      ),
      home: const AnalyticsPage(),
    );
  }
}