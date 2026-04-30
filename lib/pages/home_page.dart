import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:my_app/theme/app_colors.dart';
import 'package:my_app/widgets/app_ui.dart';

import 'sales_page.dart';
import 'analytics_page.dart';
import 'create_order_page.dart';
import 'expenses_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _analytics;

  String _period = 'Все';
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _setAll(load: false);
    _loadAnalytics();
  }

  String get _baseUrl {
    if (kIsWeb) return 'http://localhost:8080';
    return 'http://10.0.2.2:8080';
  }

  String _apiDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _uiDate(DateTime? date) {
    if (date == null) return 'Не выбрано';
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final params = <String, String>{};

      if (_dateFrom != null) {
        params['date_from'] = _apiDate(_dateFrom!);
      }

      if (_dateTo != null) {
        params['date_to'] = _apiDate(_dateTo!);
      }

      final uri = Uri.parse('$_baseUrl/analytics').replace(
        queryParameters: params.isEmpty ? null : params,
      );

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('Ошибка ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      setState(() {
        _analytics = data;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Не удалось загрузить данные';
        _loading = false;
      });
    }
  }

  void _setToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    setState(() {
      _period = 'Сегодня';
      _dateFrom = today;
      _dateTo = today;
    });

    _loadAnalytics();
  }

  void _setLastDays(int days) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    setState(() {
      _period = '$days дней';
      _dateFrom = today.subtract(Duration(days: days - 1));
      _dateTo = today;
    });

    _loadAnalytics();
  }

  void _setAll({bool load = true}) {
    setState(() {
      _period = 'Все';
      _dateFrom = null;
      _dateTo = null;
    });

    if (load) _loadAnalytics();
  }

  Future<void> _pickFromDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFrom ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _period = 'Период';
      _dateFrom = DateTime(picked.year, picked.month, picked.day);

      if (_dateTo != null && _dateFrom!.isAfter(_dateTo!)) {
        _dateTo = _dateFrom;
      }
    });

    _loadAnalytics();
  }

  Future<void> _pickToDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _dateTo ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _period = 'Период';
      _dateTo = DateTime(picked.year, picked.month, picked.day);

      if (_dateFrom != null && _dateTo!.isBefore(_dateFrom!)) {
        _dateFrom = _dateTo;
      }
    });

    _loadAnalytics();
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
          .replaceAll(',', '.')
          .trim(),
    ) ??
        0;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  String _formatMoney(dynamic value) {
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

  String _formatPercent(dynamic value) {
    return '${_toDouble(value).toStringAsFixed(1)}%';
  }

  String _periodText() {
    if (_dateFrom == null && _dateTo == null) return 'Весь период';
    return '${_uiDate(_dateFrom)} — ${_uiDate(_dateTo)}';
  }

  String _channelLeaderText() {
    final kaspiProfit = _toDouble(_analytics?['kaspiProfit']);
    final optProfit = _toDouble(_analytics?['optProfit']);

    if (kaspiProfit == 0 && optProfit == 0) {
      return 'Данные по каналам пока недоступны.';
    }

    if (kaspiProfit >= optProfit) {
      return 'Сейчас Каспий даёт больше прибыли, чем ОПТ.';
    }

    return 'Сейчас ОПТ даёт больше прибыли, чем Каспий.';
  }

  String _topProductText() {
    final topProducts = (_analytics?['topProducts'] as List?) ?? [];
    if (topProducts.isEmpty) {
      return 'Топовый товар появится после загрузки аналитики.';
    }

    final first = topProducts.first;
    if (first is Map<String, dynamic>) {
      final name = first['name']?.toString() ?? 'Без названия';
      final profit = _formatMoney(first['profit']);
      return 'Лидер по прибыли сейчас: $name — $profit.';
    }

    return 'Топовый товар появится после загрузки аналитики.';
  }

  String _partnerText() {
    final myNet = _formatMoney(_analytics?['myNet']);
    final alexNet = _formatMoney(_analytics?['alexNet']);
    return 'На руки за период: Стас — $myNet, Алексей — $alexNet.';
  }

  List<Map<String, dynamic>> _topProductsList() {
    final raw = (_analytics?['topProducts'] as List?) ?? [];

    return raw
        .whereType<Map<String, dynamic>>()
        .map((e) => {
      'name': e['name']?.toString() ?? 'Без названия',
      'profit': _toDouble(e['profit']),
    })
        .toList();
  }

  List<Map<String, dynamic>> _dailyProfitList() {
    final raw = (_analytics?['dailyProfit'] as List?) ?? [];

    return raw
        .whereType<Map<String, dynamic>>()
        .map((e) => {
      'date': e['date']?.toString() ?? '',
      'profit': _toDouble(e['profit']),
    })
        .toList();
  }

  Widget _periodButton(String title, VoidCallback onTap) {
    final active = _period == title;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF4DA3FF).withOpacity(0.22)
                : AppColors.bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active
                  ? const Color(0xFF4DA3FF).withOpacity(0.55)
                  : AppColors.stroke,
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              color: active ? AppColors.textMain : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateBox({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.stroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _uiDate(date),
                style: const TextStyle(
                  color: AppColors.textMain,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterCard() {
    return AppUi.sectionCard(
      title: 'Период',
      icon: Icons.date_range_rounded,
      accent: const Color(0xFF4DA3FF),
      child: Column(
        children: [
          Row(
            children: [
              _periodButton('Сегодня', _setToday),
              const SizedBox(width: 8),
              _periodButton('7 дней', () => _setLastDays(7)),
              const SizedBox(width: 8),
              _periodButton('30 дней', () => _setLastDays(30)),
              const SizedBox(width: 8),
              _periodButton('Все', _setAll),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _dateBox(
                label: 'С',
                date: _dateFrom,
                onTap: _pickFromDate,
              ),
              const SizedBox(width: 12),
              _dateBox(
                label: 'По',
                date: _dateTo,
                onTap: _pickToDate,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Сейчас считается: ${_periodText()}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
    required Widget page,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => page),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: AppUi.cardDecoration(
            radius: 22,
            borderColor: colors.first.withOpacity(0.22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.02),
                colors.first.withOpacity(0.08),
              ],
            ),
            shadows: [
              BoxShadow(
                color: colors.first.withOpacity(0.12),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textMain,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _insightCard({
    required String title,
    required String text,
    required IconData icon,
    required List<Color> colors,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: AppUi.cardDecoration(
        radius: 20,
        borderColor: colors.first.withOpacity(0.20),
        shadows: [
          BoxShadow(
            color: colors.first.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 19),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  text,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniSummaryRow({
    required String label,
    required String value,
    required Color accent,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textMain,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallChart() {
    final list = _dailyProfitList();
    final visible = list.length > 14 ? list.sublist(list.length - 14) : list;

    if (visible.isEmpty) {
      return const Text(
        'Нет данных для графика',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
      );
    }

    double max = 0;
    for (final item in visible) {
      final value = _toDouble(item['profit']);
      if (value > max) max = value;
    }

    return SizedBox(
      height: 110,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: visible.map((item) {
          final value = _toDouble(item['profit']);
          final date = item['date']?.toString() ?? '';
          final shortDate = date.length >= 5 ? date.substring(0, 5) : date;
          final double h = max == 0 ? 10.0 : ((value / max) * 70).toDouble();

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: 70,
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: h,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF4DA3FF),
                            Color(0xFF2D7DFF),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    shortDate,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _top5Compact() {
    final list = _topProductsList();

    if (list.isEmpty) {
      return const Text(
        'Нет данных по товарам',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
      );
    }

    final visible = list.length > 5 ? list.sublist(0, 5) : list;

    return Column(
      children: List.generate(visible.length, (index) {
        final item = visible[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item['name']?.toString() ?? 'Без названия',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _formatMoney(item['profit']),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _partnerCompact() {
    return Column(
      children: [
        _miniSummaryRow(
          label: 'Стас чистыми',
          value: _formatMoney(_analytics?['myNet']),
          accent: const Color(0xFFF59E0B),
        ),
        _miniSummaryRow(
          label: 'Алексей чистыми',
          value: _formatMoney(_analytics?['alexNet']),
          accent: const Color(0xFF8B5CF6),
        ),
        _miniSummaryRow(
          label: 'Общая прибыль',
          value: _formatMoney(_analytics?['totalProfit']),
          accent: const Color(0xFF22C55E),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalProfit = _toDouble(_analytics?['totalProfit']);
    final expensesValue = _toDouble(_analytics?['expenses']);
    final cleanProfit = totalProfit - expensesValue;

    final periodProfit = _formatMoney(totalProfit);
    final periodNet = _formatMoney(cleanProfit);

    final kaspiProfit = _formatMoney(_analytics?['kaspiProfit']);
    final optProfit = _formatMoney(_analytics?['optProfit']);
    final count = _toInt(_analytics?['salesCount'] ?? 0).toString();
    final avgCheck = _formatMoney(_analytics?['avgCheck']);
    final margin = _formatPercent(_analytics?['margin']);
    final expenses = _formatMoney(expensesValue);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text(
          'Главная',
          style: TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadAnalytics,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textMain),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 44,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.textMain,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Проверь, что backend запущен на 8080.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadAnalytics,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      )
          : Center(
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
                  const Color(0xFF4DA3FF).withOpacity(0.22),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.02),
                      const Color(0xFF4DA3FF).withOpacity(0.08),
                    ],
                  ),
                  shadows: [
                    BoxShadow(
                      color:
                      const Color(0xFF4DA3FF).withOpacity(0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TechnoOpt',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Управление бизнесом',
                      style: TextStyle(
                        color: AppColors.textMain,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Прибыль, расходы, каналы и быстрый доступ к основным разделам.',
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
              _filterCard(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AppUi.metricCard(
                      icon: Icons.payments_outlined,
                      title: 'Прибыль',
                      value: periodProfit,
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
                      icon: Icons.trending_up_outlined,
                      title: 'Чистая',
                      value: periodNet,
                      accentColors: const [
                        Color(0xFF22C55E),
                        Color(0xFF16A34A),
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
                      icon: Icons.storefront_outlined,
                      title: 'Каспий',
                      value: kaspiProfit,
                      accentColors: const [
                        Color(0xFF8B5CF6),
                        Color(0xFF6D28D9),
                      ],
                      compact: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppUi.metricCard(
                      icon: Icons.local_shipping_outlined,
                      title: 'ОПТ',
                      value: optProfit,
                      accentColors: const [
                        Color(0xFFF59E0B),
                        Color(0xFFD97706),
                      ],
                      compact: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppUi.sectionCard(
                title: 'Быстрые действия',
                icon: Icons.flash_on_rounded,
                accent: const Color(0xFF22C55E),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _quickActionCard(
                          context: context,
                          title: 'Новый заказ',
                          subtitle: 'Создать накладную',
                          icon: Icons.add_box_outlined,
                          colors: const [
                            Color(0xFF22C55E),
                            Color(0xFF16A34A),
                          ],
                          page: const CreateOrderPage(),
                        ),
                        const SizedBox(width: 12),
                        _quickActionCard(
                          context: context,
                          title: 'Расход',
                          subtitle: 'Добавить расход',
                          icon: Icons.receipt_long_outlined,
                          colors: const [
                            Color(0xFFEF4444),
                            Color(0xFFDC2626),
                          ],
                          page: const ExpensesPage(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _quickActionCard(
                          context: context,
                          title: 'Продажи',
                          subtitle: 'Список и фильтры',
                          icon: Icons.shopping_bag_outlined,
                          colors: const [
                            Color(0xFF4DA3FF),
                            Color(0xFF2D7DFF),
                          ],
                          page: const SalesPage(),
                        ),
                        const SizedBox(width: 12),
                        _quickActionCard(
                          context: context,
                          title: 'Аналитика',
                          subtitle: 'Показатели',
                          icon: Icons.bar_chart_outlined,
                          colors: const [
                            Color(0xFF8B5CF6),
                            Color(0xFF6D28D9),
                          ],
                          page: const AnalyticsPage(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppUi.sectionCard(
                title: 'Короткая сводка',
                icon: Icons.grid_view_rounded,
                accent: const Color(0xFFF59E0B),
                child: Column(
                  children: [
                    _miniSummaryRow(
                      label: 'Период',
                      value: _periodText(),
                      accent: const Color(0xFF06B6D4),
                    ),
                    _miniSummaryRow(
                      label: 'Продаж',
                      value: count,
                      accent: const Color(0xFF4DA3FF),
                    ),
                    _miniSummaryRow(
                      label: 'Средний чек',
                      value: avgCheck,
                      accent: const Color(0xFF22C55E),
                    ),
                    _miniSummaryRow(
                      label: 'Маржинальность',
                      value: margin,
                      accent: const Color(0xFF8B5CF6),
                    ),
                    _miniSummaryRow(
                      label: 'Расходы',
                      value: expenses,
                      accent: const Color(0xFFEF4444),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppUi.sectionCard(
                title: 'Инсайты',
                icon: Icons.auto_awesome_rounded,
                accent: const Color(0xFF06B6D4),
                child: Column(
                  children: [
                    _insightCard(
                      title: 'Каналы',
                      text: _channelLeaderText(),
                      icon: Icons.compare_arrows_rounded,
                      colors: const [
                        Color(0xFF06B6D4),
                        Color(0xFF0891B2),
                      ],
                    ),
                    _insightCard(
                      title: 'Товар',
                      text: _topProductText(),
                      icon: Icons.workspace_premium_outlined,
                      colors: const [
                        Color(0xFFF59E0B),
                        Color(0xFFD97706),
                      ],
                    ),
                    _insightCard(
                      title: 'Партнёр',
                      text: _partnerText(),
                      icon: Icons.groups_outlined,
                      colors: const [
                        Color(0xFF8B5CF6),
                        Color(0xFF6D28D9),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppUi.sectionCard(
                title: 'График прибыли',
                icon: Icons.show_chart_rounded,
                accent: const Color(0xFF4DA3FF),
                child: _smallChart(),
              ),
              const SizedBox(height: 16),
              AppUi.sectionCard(
                title: 'Топ-5 товаров',
                icon: Icons.workspace_premium_outlined,
                accent: const Color(0xFFF59E0B),
                child: _top5Compact(),
              ),
              const SizedBox(height: 16),
              AppUi.sectionCard(
                title: 'Для партнёра',
                icon: Icons.groups_rounded,
                accent: const Color(0xFF8B5CF6),
                child: _partnerCompact(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
