import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'sales_page.dart';
import 'analytics_page.dart';
import 'create_order_page.dart';
import 'expenses_page.dart';
import 'stock_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _analytics;

  final Color _bg = const Color(0xFF05070C);
  final Color _text = const Color(0xFFF8FAFC);
  final Color _muted = const Color(0xFF8B93A7);

  final Color _blue = const Color(0xFF4DA3FF);
  final Color _green = const Color(0xFF4ADE80);
  final Color _orange = const Color(0xFFFFB86B);
  final Color _purple = const Color(0xFF9B8CFF);
  final Color _red = const Color(0xFFFF6B6B);

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  String get _baseUrl => 'https://profit-app-7u44.onrender.com';

  Future<void> _loadAnalytics() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response =
          await http.get(Uri.parse('$_baseUrl/analytics'));

      if (response.statusCode != 200) {
        throw Exception();
      }

      final data = jsonDecode(response.body);

      setState(() {
        _analytics = data;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Ошибка загрузки';
      });
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;

    if (value is num) return value.toDouble();

    return double.tryParse(
          value
              .toString()
              .replaceAll('₸', '')
              .replaceAll('%', '')
              .replaceAll(' ', '')
              .replaceAll(',', '.'),
        ) ??
        0;
  }

  String _money(dynamic value) {
    final number = _toDouble(value).round();

    final raw = number.toString();
    final buffer = StringBuffer();

    int counter = 0;

    for (int i = raw.length - 1; i >= 0; i--) {
      buffer.write(raw[i]);
      counter++;

      if (counter % 3 == 0 && i != 0) {
        buffer.write(' ');
      }
    }

    return '${buffer.toString().split('').reversed.join()} ₸';
  }

  String _short(dynamic value) {
    final n = _toDouble(value);

    if (n.abs() >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(1)}M ₸';
    }

    if (n.abs() >= 1000) {
      return '${(n / 1000).toStringAsFixed(0)}K ₸';
    }

    return '${n.round()} ₸';
  }

  Widget _glass({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
    double radius = 28,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _background() {
    return Positioned.fill(
      child: Stack(
        children: [
          Container(color: _bg),
          Positioned(
            top: -150,
            left: -120,
            child: _glow(320, _blue.withOpacity(0.18)),
          ),
          Positioned(
            bottom: -180,
            right: -140,
            child: _glow(360, _purple.withOpacity(0.14)),
          ),
        ],
      ),
    );
  }

  Widget _glow(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 100,
          sigmaY: 100,
        ),
        child: const SizedBox(),
      ),
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => page,
      ),
    );
  }

  Widget _mainButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.25),
              Colors.white.withOpacity(0.05),
            ],
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: _text,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: _muted,
              size: 16,
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  Widget _smallButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 86,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.20),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: color,
                size: 24,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: _text,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statRow(
    String title,
    String value,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: _muted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: _text,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _body(BuildContext context) {
    final totalProfit = _toDouble(_analytics?['totalProfit']);
    final expenses = _toDouble(_analytics?['expenses']);
    final clean = totalProfit - expenses;

    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      color: _blue,
      backgroundColor: _bg,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: [_blue, _purple],
                    ),
                  ),
                  child: const Icon(
                    Icons.dashboard_customize_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TechnoOpt',
                        style: TextStyle(
                          color: _text,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'главная панель бизнеса',
                            style: TextStyle(
                              color: _muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            'Период: текущий месяц',
                            style: TextStyle(
                              color: _blue.withOpacity(0.9),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

            const SizedBox(height: 18),

            _glass(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Чистая прибыль',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _money(clean),
                    style: TextStyle(
                      color: _text,
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'после всех расходов',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 22),

                  _statRow(
                    'Валовая прибыль',
                    _short(totalProfit),
                    _blue,
                  ),

                  const SizedBox(height: 14),

                  _statRow(
                    'Расходы',
                    _short(expenses),
                    _orange,
                  ),

                  const SizedBox(height: 14),

                  _statRow(
                    'Маржа',
                    '${_toDouble(_analytics?['margin']).toStringAsFixed(1)}%',
                    _green,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            _mainButton(
              title: 'Новый заказ',
              icon: Icons.add_rounded,
              color: _green,
              onTap: () {
                _open(
                  context,
                  const CreateOrderPage(),
                );
              },
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                _smallButton(
                  title: 'Продажи',
                  icon: Icons.shopping_bag_rounded,
                  color: _blue,
                  onTap: () {
                    _open(
                      context,
                      const SalesPage(),
                    );
                  },
                ),
                const SizedBox(width: 12),
                _smallButton(
                  title: 'Аналитика',
                  icon: Icons.bar_chart_rounded,
                  color: _purple,
                  onTap: () {
                    _open(
                      context,
                      const AnalyticsPage(),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                _smallButton(
                  title: 'Расходы',
                  icon: Icons.receipt_long_rounded,
                  color: _red,
                  onTap: () {
                    _open(
                      context,
                      const ExpensesPage(),
                    );
                  },
                ),
                const SizedBox(width: 12),
                _smallButton(
                  title: 'Остатки',
                  icon: Icons.inventory_2_rounded,
                  color: _orange,
                  onTap: () {
                    _open(
                      context,
                      const StockPage(),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 18),

            _glass(
              child: Column(
                children: [
                  _statRow(
                    'Каспий',
                    _short(_analytics?['kaspiProfit']),
                    _purple,
                  ),
                  const SizedBox(height: 14),
                  _statRow(
                    'ОПТ',
                    _short(_analytics?['optProfit']),
                    _green,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          _background(),
          SafeArea(
            bottom: false,
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                      color: _blue,
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: _text,
                          ),
                        ),
                      )
                    : _body(context),
          ),
        ],
      ),
    );
  }
}