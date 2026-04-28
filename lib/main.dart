import 'package:flutter/material.dart';
import 'package:my_app/theme/app_colors.dart';

import 'package:my_app/pages/home_page.dart';
import 'package:my_app/pages/sales_page.dart';
import 'package:my_app/pages/analytics_page.dart';
import 'package:my_app/pages/create_order_page.dart';
import 'package:my_app/pages/summary_page.dart';
import 'package:my_app/pages/plan_page.dart';
import 'package:my_app/pages/expenses_page.dart';

void main() {
  runApp(const TechnoOptApp());
}

class TechnoOptApp extends StatelessWidget {
  const TechnoOptApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomePage(), // 0
      const SalesPage(),         // 1
      const AnalyticsPage(),     // 2
      const CreateOrderPage(),   // 3
      const SummaryPage(),       // 4
      const PlanPage(),           // 5
      const ExpensesPage(),      // 6
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: _go,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.card,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.white54,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Главная'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: 'Продажи'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Аналитика'),
          BottomNavigationBarItem(icon: Icon(Icons.add_box), label: 'Заказ'),
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Модель'),
          BottomNavigationBarItem(icon: Icon(Icons.flag), label: 'План'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Расходы'),
        ],
      ),
    );
  }
}
