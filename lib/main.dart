import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:my_app/theme/app_colors.dart';

import 'package:my_app/pages/home_page.dart';
import 'package:my_app/pages/sales_page.dart';
import 'package:my_app/pages/analytics_page.dart';
import 'package:my_app/pages/create_order_page.dart';
import 'package:my_app/pages/summary_page.dart';
import 'package:my_app/pages/plan_page.dart';
import 'package:my_app/pages/expenses_page.dart';
import 'package:my_app/pages/stock_page.dart';
import 'package:my_app/pages/side_income_page.dart';

void main() {
  runApp(const TechnoOptApp());
}

class TechnoOptApp extends StatelessWidget {
  const TechnoOptApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ru', 'RU'),
      supportedLocales: const [
        Locale('ru', 'RU'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.bg,
      ),
      home: const MainNavigationPage(),
    );
  }
}

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _index = 0;

  void _go(int i) {
    setState(() {
      _index = i;
    });
  }

  Widget _dockIcon(IconData icon, int index, Color color) {
    final active = _index == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => _go(index),
        child: AnimatedScale(
          scale: active ? 1.18 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: Container(
            height: 34,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: active ? color.withOpacity(0.18) : Colors.transparent,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: active ? color : Colors.white54,
              size: active ? 20 : 18,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomePage(),
      const SalesPage(),
      const AnalyticsPage(),
      const CreateOrderPage(),
      const SummaryPage(),
      const PlanPage(),
      const ExpensesPage(),
      const StockPage(),
      const SideIncomePage(),
    ];

    return Scaffold(
      extendBody: false,
      body: pages[_index],
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 54,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.card.withOpacity(0.92),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          child: Row(
            children: [
              _dockIcon(Icons.home_rounded, 0, Colors.blue),
              _dockIcon(Icons.shopping_bag_rounded, 1, Colors.cyan),
              _dockIcon(Icons.bar_chart_rounded, 2, Colors.purpleAccent),
              _dockIcon(Icons.add_box_rounded, 3, Colors.greenAccent),
              _dockIcon(Icons.dashboard_rounded, 4, Colors.orangeAccent),
              _dockIcon(Icons.flag_rounded, 5, Colors.amber),
              _dockIcon(Icons.receipt_long_rounded, 6, Colors.redAccent),
              _dockIcon(Icons.inventory_2_rounded, 7, Colors.tealAccent),
              _dockIcon(Icons.handshake_rounded, 8, Colors.pinkAccent),
            ],
          ),
        ),
      ),
    );
  }
}