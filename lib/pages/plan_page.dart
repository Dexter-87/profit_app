import 'package:flutter/material.dart';
import 'package:my_app/services/api_service.dart';
import 'package:my_app/theme/app_colors.dart';
import 'package:my_app/widgets/app_ui.dart';

class PlanPage extends StatefulWidget {
  const PlanPage({super.key});

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  bool _loading = true;
  String _error = '';

  List<Map<String, dynamic>> _planRows = [];
  Map<String, dynamic> _analytics = {};
  Map<String, dynamic>? _selectedPlan;

  String _period = 'Месяц';
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _loadAll();
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
    final raw = _toDouble(value).round().toString();
    final buffer = StringBuffer();
    int c = 0;

    for (int i = raw.length - 1; i >= 0; i--) {
      buffer.write(raw[i]);
      c++;
      if (c == 3 && i != 0) {
        buffer.write(' ');
        c = 0;
      }
    }

    return '${buffer.toString().split('').reversed.join()} ₸';
  }

  String _apiDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _uiDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  int _monthNumber(String name) {
    const map = {
      'Январь': 1,
      'Февраль': 2,
      'Март': 3,
      'Апрель': 4,
      'Май': 5,
      'Июнь': 6,
      'Июль': 7,
      'Август': 8,
      'Сентябрь': 9,
      'Октябрь': 10,
      'Ноябрь': 11,
      'Декабрь': 12,
    };
    return map[name] ?? DateTime.now().month;
  }

  String _monthName(int month) {
    const names = [
      '',
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь',
    ];
    return names[month];
  }

  Future<void> _loadAll() async {
    try {
      setState(() {
        _loading = true;
        _error = '';
      });

      final plan = await ApiService.fetchPlan();
      final now = DateTime.now();
      final currentMonth = _monthName(now.month);

      final selected = plan.firstWhere(
            (r) => (r['month'] ?? '').toString().trim() == currentMonth,
        orElse: () => plan.isNotEmpty ? plan.first : <String, dynamic>{},
      );

      _planRows = plan;
      _selectedPlan = selected;

      await _loadAnalytics();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadAnalytics() async {
    final row = _selectedPlan ?? {};
    final month = _monthNumber((row['month'] ?? '').toString());
    const year = 2026;

    DateTime from;
    DateTime to;

    if (_period == 'Месяц') {
      from = DateTime(year, month, 1);
      to = DateTime(year, month + 1, 0);
    } else if (_period == 'Сегодня') {
      final now = DateTime.now();
      from = DateTime(now.year, now.month, now.day);
      to = from;
    } else if (_period == '7 дней') {
      final now = DateTime.now();
      to = DateTime(now.year, now.month, now.day);
      from = to.subtract(const Duration(days: 6));
    } else if (_period == '30 дней') {
      final now = DateTime.now();
      to = DateTime(now.year, now.month, now.day);
      from = to.subtract(const Duration(days: 29));
    } else {
      from = _dateFrom ?? DateTime(year, month, 1);
      to = _dateTo ?? DateTime(year, month + 1, 0);
    }

    final data = await ApiService.fetchAnalytics(
      dateFrom: _apiDate(from),
      dateTo: _apiDate(to),
    );

    setState(() {
      _analytics = data;
      _dateFrom = from;
      _dateTo = to;
      _loading = false;
    });
  }

  Future<void> _selectMonth(Map<String, dynamic> row) async {
    setState(() {
      _selectedPlan = row;
      _period = 'Месяц';
      _loading = true;
    });

    await _loadAnalytics();
  }

  void _setPeriod(String period) {
    setState(() {
      _period = period;
      _loading = true;
    });

    _loadAnalytics();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom
        ? (_dateFrom ?? DateTime.now())
        : (_dateTo ?? DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _period = 'Период';

      if (isFrom) {
        _dateFrom = DateTime(picked.year, picked.month, picked.day);
        if (_dateTo != null && _dateFrom!.isAfter(_dateTo!)) {
          _dateTo = _dateFrom;
        }
      } else {
        _dateTo = DateTime(picked.year, picked.month, picked.day);
        if (_dateFrom != null && _dateTo!.isBefore(_dateFrom!)) {
          _dateFrom = _dateTo;
        }
      }

      _loading = true;
    });

    await _loadAnalytics();
  }

  Widget _monthButton(Map<String, dynamic> row) {
    final month = (row['month'] ?? '').toString();
    final selected = (_selectedPlan?['month'] ?? '') == month;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _selectMonth(row),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: selected ? const Color(0xFF22C55E) : AppColors.card,
            border: Border.all(
              color: selected ? Colors.transparent : AppColors.stroke,
            ),
          ),
          child: Text(
            month,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _periodButton(String title) {
    final selected = _period == title;

    return Expanded(
      child: InkWell(
        onTap: () => _setPeriod(title),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected ? const Color(0xFF22C55E) : AppColors.bg,
            border: Border.all(
              color: selected ? Colors.transparent : AppColors.stroke,
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
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
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: _period == 'Период'
                ? const Color(0xFF22C55E).withOpacity(0.10)
                : AppColors.bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _period == 'Период'
                  ? const Color(0xFF22C55E).withOpacity(0.45)
                  : AppColors.stroke,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _uiDate(date),
                style: const TextStyle(
                  color: AppColors.textMain,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
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
            style: TextStyle(
              color: AppColors.textMain,
              fontSize: 13,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _progress(String title, double fact, double plan) {
    final percent = plan == 0 ? 0.0 : (fact / plan) * 100;
    final value = (percent.clamp(0, 100)) / 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 10,
            backgroundColor: AppColors.stroke,
            color: const Color(0xFF22C55E),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${percent.toStringAsFixed(1)}%',
          style: const TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final row = _selectedPlan ?? {};
    final month = (row['month'] ?? '').toString();

    final planProfit = _toDouble(row['plan_profit']);
    final planKaspi = _toDouble(row['plan_kaspi']);
    final planOpt = _toDouble(row['plan_opt']);

    final factRevenue = _toDouble(_analytics['revenue']);
    final factProfit = _toDouble(_analytics['totalProfit']);
    final factKaspi = _toDouble(_analytics['kaspiProfit']);
    final factOpt = _toDouble(_analytics['optProfit']);
    final expenses = _toDouble(_analytics['expenses']);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text(
          'План',
          style: TextStyle(
            color: AppColors.textMain,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh, color: AppColors.textMain),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
          ? Center(
        child: Text(
          _error,
          style: const TextStyle(color: AppColors.danger),
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
                  const Color(0xFF22C55E).withOpacity(0.25),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.02),
                      const Color(0xFF22C55E).withOpacity(0.08),
                    ],
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Выполнение плана',
                      style: TextStyle(
                        color: AppColors.textMain,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'План / факт по выбранному месяцу или периоду.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _planRows.map(_monthButton).toList(),
                ),
              ),

              const SizedBox(height: 16),

              AppUi.sectionCard(
                title: 'Период факта',
                icon: Icons.date_range_outlined,
                accent: const Color(0xFF4DA3FF),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _periodButton('Месяц'),
                        const SizedBox(width: 8),
                        _periodButton('Сегодня'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _periodButton('7 дней'),
                        const SizedBox(width: 8),
                        _periodButton('30 дней'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _dateBox(
                          label: 'С',
                          date: _dateFrom,
                          onTap: () => _pickDate(isFrom: true),
                        ),
                        const SizedBox(width: 10),
                        _dateBox(
                          label: 'По',
                          date: _dateTo,
                          onTap: () => _pickDate(isFrom: false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _line(
                      'Сейчас считается',
                      '${_uiDate(_dateFrom)} — ${_uiDate(_dateTo)}',
                      bold: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              AppUi.sectionCard(
                title: 'План / факт: $month',
                icon: Icons.flag_outlined,
                accent: const Color(0xFF22C55E),
                child: Column(
                  children: [
                    _line('Факт выручки', _money(factRevenue)),
                    _line('Факт прибыли', _money(factProfit)),
                    _line('План прибыли месяца', _money(planProfit)),
                    _line('Расходы периода', _money(expenses)),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              AppUi.sectionCard(
                title: 'Прогресс',
                icon: Icons.trending_up,
                accent: const Color(0xFF22C55E),
                child: Column(
                  children: [
                    _progress('Прибыль', factProfit, planProfit),
                    const SizedBox(height: 16),
                    _progress('Kaspi', factKaspi, planKaspi),
                    const SizedBox(height: 16),
                    _progress('ОПТ', factOpt, planOpt),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
