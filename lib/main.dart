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

  final ScrollController _dockController = ScrollController();

  final List<_NavItem> _items = const [
    _NavItem('Главная', Icons.home_rounded, Colors.blue),
    _NavItem('Продажи', Icons.shopping_bag_rounded, Colors.cyan),
    _NavItem('Аналитика', Icons.bar_chart_rounded, Colors.purpleAccent),
    _NavItem('Заказ', Icons.add_box_rounded, Colors.greenAccent),
    _NavItem('Модель', Icons.dashboard_rounded, Colors.orangeAccent),
    _NavItem('План', Icons.flag_rounded, Colors.amber),
    _NavItem('Расходы', Icons.receipt_long_rounded, Colors.redAccent),
    _NavItem('Остатки', Icons.inventory_2_rounded, Colors.tealAccent),
    _NavItem('Доп.', Icons.handshake_rounded, Colors.pinkAccent),
  ];

  void _go(int i) {
    setState(() => _index = i);
  }

  Widget _dockButton(_NavItem item, int index) {
    final active = _index == index;

    return GestureDetector(
      onTap: () => _go(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: active ? 104 : 82,
        height: 58,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: active ? item.color.withOpacity(0.20) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? item.color.withOpacity(0.35) : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.icon,
              color: active ? item.color : Colors.white54,
              size: active ? 26 : 24,
            ),
            const SizedBox(height: 4),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? Colors.white : Colors.white54,
                fontSize: 10,
                fontWeight: active ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dockController.dispose();
    super.dispose();
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
          height: 76,
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.card.withOpacity(0.94),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          child: ListView.builder(
            controller: _dockController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _items.length,
            itemBuilder: (context, index) {
              return _dockButton(_items[index], index);
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String title;
  final IconData icon;
  final Color color;

  const _NavItem(this.title, this.icon, this.color);
}