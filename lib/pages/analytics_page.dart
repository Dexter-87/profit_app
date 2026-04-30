import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:my_app/theme/app_colors.dart';
import 'package:my_app/widgets/app_ui.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  bool _isLoading = true;
  String _error = '';

  Map<String, dynamic> _data = {};

  String _selectedPeriod = '30 дней';
  DateTime? _dateFrom;
  DateTime? _dateTo;

  final double revenuePlan = 10000000;
  final double profitPlan = 800000;

  @override
  void initState() {
    super.initState();
    _applyPresetPeriod('30 дней', load: false);
    _loadAnalytics();
  }

  String _formatApiDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadAnalytics() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      final result = await ApiService.fetchAnalytics(
        dateFrom: _formatApiDate(_dateFrom),
        dateTo: _formatApiDate(_dateTo),
      );

      setState(() {
        _data = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyPresetPeriod(String period, {bool load = true}) {
    final now = DateTime.now();

    setState(() {
      _selectedPeriod = period;

      if (period == 'Сегодня') {
        _dateFrom = DateTime(now.year, now.month, now.day);
        _dateTo = DateTime(now.year, now.month, now.day);
      } else if (period == '7 дней') {
        _dateFrom = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 6));
        _dateTo = DateTime(now.year, now.month, now.day);
      } else if (period == '30 дней') {
        _dateFrom = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 29));
        _dateTo = DateTime(now.year, now.month, now.day);
      } else {
        _dateFrom = null;
        _dateTo = null;
      }
    });

    if (load) _loadAnalytics();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_dateFrom ?? now) : (_dateTo ?? now),
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _selectedPeriod = 'Свои даты';
        if (isFrom) {
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
      });
      _loadAnalytics();
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();

    final cleaned = value.toString().replaceAll(' ', '').replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0;
  }

  String _formatMoney(dynamic value) {
    final number = _toDouble(value).round().toString();
    final buffer = StringBuffer();
    int counter = 0;

    for (int i = number.length - 1; i >= 0; i--) {
      buffer.write(number[i]);
      counter++;
      if (counter == 3 && i != 0) {
        buffer.write(' ');
        counter = 0;
      }
    }

    return '${buffer.toString().split('').reversed.join()} ₸';
  }

  String _formatPercent(dynamic value) {
    return '${_toDouble(value).toStringAsFixed(1)}%';
  }

  String _formatDisplayDate(DateTime? date) {
    if (date == null) return 'Не выбрано';
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  Widget _bullet(String text, {Color accent = AppColors.primary}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              color: accent,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _channelMiniCard({
    required String title,
    required String revenue,
    required String profit,
    required String count,
    required List<Color> accentColors,
  }) {
    final accent = accentColors.first;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppUi.cardDecoration(
        color: AppColors.bg,
        radius: 20,
        borderColor: accent.withOpacity(0.22),
        shadows: const [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppUi.iconBadge(
                icon: title == 'Каспий'
                    ? Icons.storefront_outlined
                    : Icons.local_shipping_outlined,
                accent: accent,
                size: 36,
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textMain,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _miniStat('Выручка', revenue),
          _miniStat('Прибыль', profit),
          _miniStat('Продаж', count),
        ],
      ),
    );
  }

  Widget _statRow(String left, String right, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              left,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            right,
            style: TextStyle(
              color: AppColors.textMain,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final revenue = _toDouble(_data['revenue']);
    final totalProfit = _toDouble(_data['totalProfit']);
    final myProfit = _toDouble(_data['myProfit']);
    final alexProfit = _toDouble(_data['alexProfit']);
    final expenses = _toDouble(_data['expenses']);
    final myNet = _toDouble(_data['myNet']);
    final alexNet = _toDouble(_data['alexNet']);
    final salesCount = (_data['salesCount'] ?? 0).toString();
    final avgCheck = _toDouble(_data['avgCheck']);
    final avgProfit = _toDouble(_data['avgProfit']);
    final margin = _toDouble(_data['margin']);

    final kaspiRevenue = _toDouble(_data['kaspiRevenue']);
    final kaspiProfit = _toDouble(_data['kaspiProfit']);
    final kaspiCount = (_data['kaspiCount'] ?? 0).toString();

    final optRevenue = _toDouble(_data['optRevenue']);
    final optProfit = _toDouble(_data['optProfit']);
    final optCount = (_data['optCount'] ?? 0).toString();

    final topProducts = (_data['topProducts'] as List?) ?? [];
    final dailyProfit = (_data['dailyProfit'] as List?) ?? [];

    final revenueProgress =
    revenuePlan == 0 ? 0.0 : (revenue / revenuePlan).clamp(0.0, 1.0);
    final profitProgress =
    profitPlan == 0 ? 0.0 : (myNet / profitPlan).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text(
          'Аналитика',
          style: TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadAnalytics,
            icon: const Icon(Icons.refresh, color: AppColors.textMain),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      )
          : _error.isNotEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _error,
            style: const TextStyle(color: AppColors.danger),
            textAlign: TextAlign.center,
          ),
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadAnalytics,
        color: AppColors.primary,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppUi.cardDecoration(
                    radius: 28,
                    borderColor:
                    const Color(0xFF8B5CF6).withOpacity(0.22),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.02),
                        const Color(0xFF8B5CF6).withOpacity(0.08),
                      ],
                    ),
                    shadows: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6)
                            .withOpacity(0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Финансовая аналитика',
                        style: TextStyle(
                          color: AppColors.textMain,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Прибыль, каналы, распределение доходов и выполнение плана.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: AppUi.cardDecoration(radius: 22),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              AppUi.periodButton(
                                title: 'Сегодня',
                                selected:
                                _selectedPeriod == 'Сегодня',
                                onTap: () =>
                                    _applyPresetPeriod('Сегодня'),
                              ),
                              const SizedBox(width: 8),
                              AppUi.periodButton(
                                title: '7 дней',
                                selected:
                                _selectedPeriod == '7 дней',
                                onTap: () =>
                                    _applyPresetPeriod('7 дней'),
                                accentColors: const [
                                  Color(0xFF8B5CF6),
                                  Color(0xFF6D28D9),
                                ],
                              ),
                              const SizedBox(width: 8),
                              AppUi.periodButton(
                                title: '30 дней',
                                selected:
                                _selectedPeriod == '30 дней',
                                onTap: () =>
                                    _applyPresetPeriod('30 дней'),
                                accentColors: const [
                                  Color(0xFF22C55E),
                                  Color(0xFF16A34A),
                                ],
                              ),
                              const SizedBox(width: 8),
                              AppUi.periodButton(
                                title: 'Всё',
                                selected: _selectedPeriod == 'Всё',
                                onTap: () =>
                                    _applyPresetPeriod('Всё'),
                                accentColors: const [
                                  Color(0xFFF59E0B),
                                  Color(0xFFD97706),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                borderRadius:
                                BorderRadius.circular(18),
                                onTap: () =>
                                    _pickDate(isFrom: true),
                                child: AppUi.dateBox(
                                  title: 'С',
                                  value:
                                  _formatDisplayDate(_dateFrom),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: InkWell(
                                borderRadius:
                                BorderRadius.circular(18),
                                onTap: () =>
                                    _pickDate(isFrom: false),
                                child: AppUi.dateBox(
                                  title: 'По',
                                  value: _formatDisplayDate(_dateTo),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AppUi.metricCard(
                        icon: Icons.payments_outlined,
                        title: 'Выручка',
                        value: _formatMoney(revenue),
                        accentColors: const [
                          Color(0xFF4DA3FF),
                          Color(0xFF2D7DFF),
                        ],
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppUi.metricCard(
                        icon: Icons.bar_chart_outlined,
                        title: 'Прибыль',
                        value: _formatMoney(totalProfit),
                        accentColors: const [
                          Color(0xFF8B5CF6),
                          Color(0xFF6D28D9),
                        ],
                        compact: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppUi.metricCard(
                        icon: Icons.person_outline,
                        title: 'Стас',
                        value: _formatMoney(myNet),
                        accentColors: const [
                          Color(0xFF22C55E),
                          Color(0xFF16A34A),
                        ],
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppUi.metricCard(
                        icon: Icons.groups_outlined,
                        title: 'Алексей',
                        value: _formatMoney(alexNet),
                        accentColors: const [
                          Color(0xFFF59E0B),
                          Color(0xFFD97706),
                        ],
                        compact: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AppUi.metricCard(
                  icon: Icons.receipt_long_outlined,
                  title: 'Расходы',
                  value: _formatMoney(expenses),
                  accentColors: const [
                    Color(0xFF06B6D4),
                    Color(0xFF0891B2),
                  ],
                  compact: true,
                ),
                const SizedBox(height: 16),
                AppUi.sectionCard(
                  title: 'Ключевые показатели',
                  icon: Icons.grid_view_rounded,
                  accent: const Color(0xFF4DA3FF),
                  child: Column(
                    children: [
                      _statRow('Продаж', salesCount),
                      _statRow('Средний чек', _formatMoney(avgCheck)),
                      _statRow(
                        'Средняя прибыль',
                        _formatMoney(avgProfit),
                      ),
                      _statRow(
                        'Маржинальность',
                        _formatPercent(margin),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppUi.sectionCard(
                  title: 'Каналы',
                  icon: Icons.account_tree_outlined,
                  accent: const Color(0xFF22C55E),
                  child: Row(
                    children: [
                      Expanded(
                        child: _channelMiniCard(
                          title: 'Каспий',
                          revenue: _formatMoney(kaspiRevenue),
                          profit: _formatMoney(kaspiProfit),
                          count: kaspiCount,
                          accentColors: const [
                            Color(0xFF06B6D4),
                            Color(0xFF0891B2),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _channelMiniCard(
                          title: 'ОПТ',
                          revenue: _formatMoney(optRevenue),
                          profit: _formatMoney(optProfit),
                          count: optCount,
                          accentColors: const [
                            Color(0xFFF59E0B),
                            Color(0xFFD97706),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppUi.sectionCard(
                  title: 'План / факт',
                  icon: Icons.flag_outlined,
                  accent: const Color(0xFF8B5CF6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppUi.progressBlock(
                        title: 'План выручки',
                        currentLabel: _formatMoney(revenue),
                        totalLabel: _formatMoney(revenuePlan),
                        progress: revenueProgress,
                        accentColors: const [
                          Color(0xFF4DA3FF),
                          Color(0xFF2D7DFF),
                        ],
                      ),
                      const SizedBox(height: 16),
                      AppUi.progressBlock(
                        title: 'План чистой прибыли Стаса',
                        currentLabel: _formatMoney(myNet),
                        totalLabel: _formatMoney(profitPlan),
                        progress: profitProgress,
                        accentColors: const [
                          Color(0xFF22C55E),
                          Color(0xFF16A34A),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppUi.sectionCard(
                  title: 'Логика распределения',
                  icon: Icons.rule_outlined,
                  accent: const Color(0xFFF59E0B),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _bullet(
                        'Ariston — прибыль делится 50/50',
                        accent: const Color(0xFFF59E0B),
                      ),
                      _bullet(
                        'Не Ariston + в комментарии — прибыль делится 50/50',
                        accent: const Color(0xFFF59E0B),
                      ),
                      _bullet(
                        'Остальные продажи — прибыль уходит Алексею',
                        accent: const Color(0xFFF59E0B),
                      ),
                      _bullet(
                        'Расходы делятся 50/50 и вычитаются отдельно',
                        accent: const Color(0xFFF59E0B),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppUi.sectionCard(
                  title: 'Распределение прибыли',
                  icon: Icons.pie_chart_outline,
                  accent: const Color(0xFF22C55E),
                  child: Column(
                    children: [
                      _statRow(
                        'Стас до расходов',
                        _formatMoney(myProfit),
                      ),
                      _statRow(
                        'Алексей до расходов',
                        _formatMoney(alexProfit),
                      ),
                      _statRow(
                        'Половина расходов каждому',
                        _formatMoney(expenses / 2),
                      ),
                      const Divider(
                        color: AppColors.stroke,
                        height: 24,
                      ),
                      _statRow(
                        'Стас чистыми',
                        _formatMoney(myNet),
                        bold: true,
                      ),
                      _statRow(
                        'Алексей чистыми',
                        _formatMoney(alexNet),
                        bold: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppUi.sectionCard(
                  title: 'Топ-5 товаров по прибыли',
                  icon: Icons.workspace_premium_outlined,
                  accent: const Color(0xFF8B5CF6),
                  child: topProducts.isEmpty
                      ? AppUi.emptyBlock('Нет данных')
                      : Column(
                    children: List.generate(
                      topProducts.length,
                          (index) {
                        final item = Map<String, dynamic>.from(
                          topProducts[index],
                        );
                        return AppUi.rankingRow(
                          index: index + 1,
                          title: (item['name'] ?? 'Без названия')
                              .toString(),
                          value: _formatMoney(item['profit']),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AppUi.sectionCard(
                  title: 'Прибыль по дням',
                  icon: Icons.calendar_month_outlined,
                  accent: const Color(0xFF06B6D4),
                  child: dailyProfit.isEmpty
                      ? AppUi.emptyBlock('Нет данных')
                      : Column(
                    children: List.generate(
                      dailyProfit.length,
                          (index) {
                        final item = Map<String, dynamic>.from(
                          dailyProfit[index],
                        );
                        return AppUi.dayProfitRow(
                          date: (item['date'] ?? '').toString(),
                          value: _formatMoney(item['profit']),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
