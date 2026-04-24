import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:my_app/theme/app_colors.dart';
import 'package:my_app/widgets/app_ui.dart';

class PlanPage extends StatefulWidget {
  const PlanPage({super.key});

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  bool isLoading = true;
  String? error;

  Map<String, dynamic> plan = {};
  Map<String, dynamic> analytics = {};

  @override
  void initState() {
    super.initState();
    loadData();
  }

  String _apiDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _ruDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  Future<void> loadData() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final now = DateTime.now();
      final from = DateTime(now.year, now.month, 1);

      final planUrl = Uri.parse('http://localhost:8080/plan');

      final analyticsUrl = Uri.parse(
        'http://localhost:8080/analytics'
            '?date_from=${_apiDate(from)}'
            '&date_to=${_apiDate(now)}',
      );

      final responses = await Future.wait([
        http.get(planUrl),
        http.get(analyticsUrl),
      ]);

      final planResponse = responses[0];
      final analyticsResponse = responses[1];

      if (planResponse.statusCode != 200) {
        throw Exception('Ошибка /plan: ${planResponse.body}');
      }

      if (analyticsResponse.statusCode != 200) {
        throw Exception('Ошибка /analytics: ${analyticsResponse.body}');
      }

      setState(() {
        plan = jsonDecode(planResponse.body);
        analytics = jsonDecode(analyticsResponse.body);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  double _numFrom(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value == null) return 0;
    if (value is num) return value.toDouble();

    return double.tryParse(
      value.toString().replaceAll(' ', '').replaceAll(',', '.'),
    ) ??
        0;
  }

  String _money(num value) {
    return '${value.round().toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ',
    )} ₸';
  }

  Widget _scenarioCard({
    required String title,
    required String subtitle,
    required List<Color> accentColors,
    required IconData icon,
  }) {
    return Container(
      decoration: AppUi.cardDecoration(
        radius: 24,
        borderColor: accentColors.first.withOpacity(0.22),
        shadows: [
          BoxShadow(
            color: accentColors.first.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: accentColors),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textMain,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _planFactCard({
    required String title,
    required String fact,
    required String planText,
    required double progress,
    required List<Color> accentColors,
  }) {
    return AppUi.sectionCard(
      title: title,
      icon: Icons.flag_outlined,
      accent: accentColors.first,
      child: AppUi.progressBlock(
        title: 'Факт / План',
        currentLabel: fact,
        totalLabel: planText,
        progress: progress.clamp(0.0, 1.0),
        accentColors: accentColors,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1);

    final month = plan['month']?.toString() ?? '';

    // ПЛАН — из app_plan
    final planProfit = _numFrom(plan, 'plan_profit');
    final planKaspi = _numFrom(plan, 'plan_kaspi');
    final planOpt = _numFrom(plan, 'plan_opt');

    // ФАКТ — из реальных продаж /analytics
    final factRevenue = _numFrom(analytics, 'revenue');
    final factProfit = _numFrom(analytics, 'totalProfit');
    final factKaspi = _numFrom(analytics, 'kaspiProfit');
    final factOpt = _numFrom(analytics, 'optProfit');

    // Пока план выручки отдельной колонкой нет — оставляем 10 млн.
    // Позже добавим колонку plan_revenue в app_plan и заменим.
    const planRevenue = 10000000.0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text(
          'План',
          style: TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.w800,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            onPressed: loadData,
            icon: const Icon(Icons.refresh, color: AppColors.textMain),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            error!,
            style: const TextStyle(
              color: AppColors.textMain,
              fontSize: 14,
            ),
          ),
        ),
      )
          : ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppUi.cardDecoration(
              radius: 28,
              borderColor: const Color(0xFFF59E0B).withOpacity(0.22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.02),
                  const Color(0xFFF59E0B).withOpacity(0.08),
                ],
              ),
              shadows: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withOpacity(0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'План и модель\n$month',
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Факт считается из продаж: ${_ruDate(from)} — ${_ruDate(now)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: AppUi.metricCard(
                  icon: Icons.payments_outlined,
                  title: 'Факт выручки',
                  value: _money(factRevenue),
                  accentColors: const [
                    Color(0xFF4DA3FF),
                    Color(0xFF2D7DFF),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppUi.metricCard(
                  icon: Icons.trending_up_outlined,
                  title: 'План прибыли',
                  value: _money(planProfit),
                  accentColors: const [
                    Color(0xFF22C55E),
                    Color(0xFF16A34A),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: AppUi.metricCard(
                  icon: Icons.wb_sunny_outlined,
                  title: 'Пик спроса',
                  value: 'Апр–Май',
                  accentColors: const [
                    Color(0xFFF59E0B),
                    Color(0xFFD97706),
                  ],
                  compact: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppUi.metricCard(
                  icon: Icons.calendar_month_outlined,
                  title: 'Второй пик',
                  value: 'Авг–Сен',
                  accentColors: const [
                    Color(0xFF8B5CF6),
                    Color(0xFF6D28D9),
                  ],
                  compact: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _planFactCard(
            title: 'План / факт по выручке',
            fact: _money(factRevenue),
            planText: _money(planRevenue),
            progress: planRevenue == 0 ? 0 : factRevenue / planRevenue,
            accentColors: const [
              Color(0xFF4DA3FF),
              Color(0xFF2D7DFF),
            ],
          ),
          const SizedBox(height: 12),

          _planFactCard(
            title: 'План / факт по прибыли',
            fact: _money(factProfit),
            planText: _money(planProfit),
            progress: planProfit == 0 ? 0 : factProfit / planProfit,
            accentColors: const [
              Color(0xFF22C55E),
              Color(0xFF16A34A),
            ],
          ),
          const SizedBox(height: 16),

          AppUi.sectionCard(
            title: 'План по каналам',
            icon: Icons.view_week_outlined,
            accent: const Color(0xFF4DA3FF),
            child: Column(
              children: [
                _planFactCard(
                  title: 'Kaspi',
                  fact: _money(factKaspi),
                  planText: _money(planKaspi),
                  progress:
                  planKaspi == 0 ? 0 : factKaspi / planKaspi,
                  accentColors: const [
                    Color(0xFF06B6D4),
                    Color(0xFF0891B2),
                  ],
                ),
                const SizedBox(height: 12),
                _planFactCard(
                  title: 'ОПТ',
                  fact: _money(factOpt),
                  planText: _money(planOpt),
                  progress: planOpt == 0 ? 0 : factOpt / planOpt,
                  accentColors: const [
                    Color(0xFFF59E0B),
                    Color(0xFFD97706),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          AppUi.sectionCard(
            title: 'Сценарии',
            icon: Icons.account_tree_outlined,
            accent: const Color(0xFF8B5CF6),
            child: Column(
              children: [
                _scenarioCard(
                  title: 'Текущая модель',
                  subtitle:
                  'Текущая схема распределения прибыли между Стасом и Алексеем.',
                  accentColors: const [
                    Color(0xFF8B5CF6),
                    Color(0xFF6D28D9),
                  ],
                  icon: Icons.balance_outlined,
                ),
                const SizedBox(height: 12),
                _scenarioCard(
                  title: 'Капитал + работа',
                  subtitle:
                  'Модель, где отдельно учитываются вложения и операционная работа.',
                  accentColors: const [
                    Color(0xFF22C55E),
                    Color(0xFF16A34A),
                  ],
                  icon: Icons.handshake_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          AppUi.infoBlock(
            title: 'Логика экрана',
            icon: Icons.info_outline,
            accent: const Color(0xFF4DA3FF),
            items: const [
              'План берется из листа app_plan',
              'Факт берется из реальных продаж через analytics',
              'Период факта: с 1 числа текущего месяца по сегодня',
              'План выручки пока временно 10 000 000 ₸',
            ],
          ),
        ],
      ),
    );
  }
}
