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
  bool _isLoading = true;
  String _error = '';

  List<Map<String, dynamic>> _planRows = [];
  List<Map<String, dynamic>> _distributionRows = [];

  Map<String, dynamic> _monthAnalytics = {};
  Map<String, dynamic>? _selectedPlan;

  String _selectedModel = 'Текущая модель';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();

    final cleaned = value
        .toString()
        .replaceAll('₸', '')
        .replaceAll('%', '')
        .replaceAll(' ', '')
        .replaceAll(',', '.')
        .trim();

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

  String _apiDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  dynamic _distValue(String metric, String column) {
    final row = _distributionRows.firstWhere(
          (r) => (r['metric'] ?? '').toString().trim() == metric,
      orElse: () => <String, dynamic>{},
    );

    return row[column] ?? 0;
  }

  Future<void> _loadAll() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      final plan = await ApiService.fetchPlan();
      final distribution = await ApiService.fetchDistribution();

      final now = DateTime.now();
      final currentMonthName = _monthName(now.month);

      final selected = plan.firstWhere(
            (row) => (row['month'] ?? '').toString().trim() == currentMonthName,
        orElse: () => plan.isNotEmpty ? plan.first : <String, dynamic>{},
      );

      setState(() {
        _planRows = plan;
        _distributionRows = distribution;
        _selectedPlan = selected;
      });

      await _loadMonthAnalytics(selected);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMonthAnalytics(Map<String, dynamic> planRow) async {
    final monthName = (planRow['month'] ?? '').toString();
    final month = _monthNumber(monthName);
    const year = 2026;

    final from = DateTime(year, month, 1);
    final to = DateTime(year, month + 1, 0);

    final data = await ApiService.fetchAnalytics(
      dateFrom: _apiDate(from),
      dateTo: _apiDate(to),
    );

    setState(() {
      _monthAnalytics = data;
      _isLoading = false;
    });
  }

  Future<void> _selectMonth(Map<String, dynamic> row) async {
    setState(() {
      _selectedPlan = row;
      _isLoading = true;
    });

    await _loadMonthAnalytics(row);
  }

  double _progress(double fact, double plan) {
    if (plan <= 0) return 0;
    return (fact / plan).clamp(0.0, 1.0).toDouble();
  }

  Widget _smallLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
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

  Widget _progressBlock({
    required String title,
    required double fact,
    required double plan,
    required List<Color> colors,
  }) {
    return AppUi.progressBlock(
      title: title,
      currentLabel: _formatMoney(fact),
      totalLabel: _formatMoney(plan),
      progress: _progress(fact, plan),
      accentColors: colors,
    );
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: selected
                ? const LinearGradient(
              colors: [Color(0xFF4DA3FF), Color(0xFF2D7DFF)],
            )
                : null,
            color: selected ? null : AppColors.card,
            border: Border.all(
              color: selected ? Colors.transparent : AppColors.stroke,
            ),
          ),
          child: Text(
            month,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _modelButton(String title) {
    final selected = _selectedModel == title;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          setState(() {
            _selectedModel = title;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: selected
                ? const LinearGradient(
              colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
            )
                : null,
            color: selected ? null : AppColors.bg,
            border: Border.all(
              color: selected ? Colors.transparent : AppColors.stroke,
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final row = _selectedPlan ?? {};
    final month = (row['month'] ?? '').toString();

    final planProfit = _toDouble(row['plan_profit']);
    final planKaspi = _toDouble(row['plan_kaspi']);
    final planOpt = _toDouble(row['plan_opt']);

    final factRevenue = _toDouble(_monthAnalytics['revenue']);
    final factTotalProfit = _toDouble(_monthAnalytics['totalProfit']);
    final factMyNet = _toDouble(_monthAnalytics['myNet']);
    final factAlexNet = _toDouble(_monthAnalytics['alexNet']);
    final factKaspiRevenue = _toDouble(_monthAnalytics['kaspiRevenue']);
    final factOptRevenue = _toDouble(_monthAnalytics['optRevenue']);
    final expenses = _toDouble(_monthAnalytics['expenses']);

    final stasCapital = _toDouble(_distValue('Вложения', 'stas'));
    final alexCapital = _toDouble(_distValue('Вложения', 'alexey'));
    final totalCapital = _toDouble(_distValue('Вложения', 'total'));

    final stasCapitalShare = _toDouble(_distValue('Доля вложений', 'stas'));
    final alexCapitalShare = _toDouble(_distValue('Доля вложений', 'alexey'));

    final stasWorkPoints = _toDouble(_distValue('Баллы за работу', 'stas'));
    final alexWorkPoints = _toDouble(_distValue('Баллы за работу', 'alexey'));

    final stasWorkShare = _toDouble(_distValue('Доля работы', 'stas'));
    final alexWorkShare = _toDouble(_distValue('Доля работы', 'alexey'));

    final capitalWeight = _toDouble(_distValue('Вес вложений', 'total'));
    final workWeight = _toDouble(_distValue('Вес работы', 'total'));

    final stasFinalShare = _toDouble(_distValue('Итоговая доля', 'stas'));
    final alexFinalShare = _toDouble(_distValue('Итоговая доля', 'alexey'));

    final capitalWorkStas = factTotalProfit * stasFinalShare;
    final capitalWorkAlex = factTotalProfit * alexFinalShare;

    final resultStas =
    _selectedModel == 'Текущая модель' ? factMyNet : capitalWorkStas;
    final resultAlex =
    _selectedModel == 'Текущая модель' ? factAlexNet : capitalWorkAlex;

    final modelNote = _selectedModel == 'Текущая модель'
        ? 'Текущая модель: Ariston и продажи с плюсом делятся 50/50, остальные продажи уходят Алексею. Расходы делятся пополам.'
        : 'Капитал + работа: прибыль месяца распределяется по итоговой доле из app_distribution. Расходы в этой модели пока не вычитаются отдельно, если нужно — следующим шагом добавим.';

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
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.danger),
          ),
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadAll,
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppUi.cardDecoration(
                radius: 28,
                borderColor: const Color(0xFF8B5CF6).withOpacity(0.25),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.02),
                    const Color(0xFF8B5CF6).withOpacity(0.08),
                  ],
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'План продаж',
                    style: TextStyle(
                      color: AppColors.textMain,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Помесячный план, факт продаж и распределение прибыли по моделям.',
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

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _planRows.map(_monthButton).toList(),
              ),
            ),

            const SizedBox(height: 16),

            AppUi.sectionCard(
              title: 'План / факт: $month',
              icon: Icons.flag_outlined,
              accent: const Color(0xFF4DA3FF),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _progressBlock(
                    title: 'Прибыль месяца',
                    fact: factTotalProfit,
                    plan: planProfit,
                    colors: const [
                      Color(0xFF4DA3FF),
                      Color(0xFF2D7DFF),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _smallLine('Факт выручки', _formatMoney(factRevenue)),
                  _smallLine('Факт прибыли', _formatMoney(factTotalProfit)),
                  _smallLine('План прибыли', _formatMoney(planProfit)),
                  _smallLine('Расходы месяца', _formatMoney(expenses)),
                ],
              ),
            ),

            const SizedBox(height: 16),

            AppUi.sectionCard(
              title: 'Каналы: Kaspi / ОПТ',
              icon: Icons.account_tree_outlined,
              accent: const Color(0xFFF59E0B),
              child: Column(
                children: [
                  _progressBlock(
                    title: 'Kaspi',
                    fact: factKaspiRevenue,
                    plan: planKaspi,
                    colors: const [
                      Color(0xFF06B6D4),
                      Color(0xFF0891B2),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _progressBlock(
                    title: 'ОПТ',
                    fact: factOptRevenue,
                    plan: planOpt,
                    colors: const [
                      Color(0xFFF59E0B),
                      Color(0xFFD97706),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            AppUi.sectionCard(
              title: 'Сценарий распределения',
              icon: Icons.compare_arrows_outlined,
              accent: const Color(0xFF22C55E),
              child: Row(
                children: [
                  _modelButton('Текущая модель'),
                  const SizedBox(width: 10),
                  _modelButton('Капитал + работа'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            AppUi.sectionCard(
              title: 'Распределение по модели',
              icon: Icons.account_tree_outlined,
              accent: const Color(0xFF22C55E),
              child: Column(
                children: [
                  _smallLine('Стас', _formatMoney(resultStas)),
                  _smallLine('Алексей', _formatMoney(resultAlex)),
                  const Divider(color: AppColors.stroke, height: 22),
                  Text(
                    modelNote,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            AppUi.sectionCard(
              title: 'Параметры капитал + работа',
              icon: Icons.account_balance_wallet_outlined,
              accent: const Color(0xFF8B5CF6),
              child: Column(
                children: [
                  _smallLine('Вложения Стас', _formatMoney(stasCapital)),
                  _smallLine('Вложения Алексей', _formatMoney(alexCapital)),
                  _smallLine('Всего вложений', _formatMoney(totalCapital)),
                  const Divider(color: AppColors.stroke, height: 22),
                  _smallLine('Доля вложений Стас', _formatPercent(stasCapitalShare * 100)),
                  _smallLine('Доля вложений Алексей', _formatPercent(alexCapitalShare * 100)),
                  _smallLine('Баллы работы Стас', stasWorkPoints.toStringAsFixed(0)),
                  _smallLine('Баллы работы Алексей', alexWorkPoints.toStringAsFixed(0)),
                  _smallLine('Доля работы Стас', _formatPercent(stasWorkShare * 100)),
                  _smallLine('Доля работы Алексей', _formatPercent(alexWorkShare * 100)),
                  const Divider(color: AppColors.stroke, height: 22),
                  _smallLine('Вес капитала', _formatPercent(capitalWeight * 100)),
                  _smallLine('Вес работы', _formatPercent(workWeight * 100)),
                  _smallLine('Итоговая доля Стас', _formatPercent(stasFinalShare * 100)),
                  _smallLine('Итоговая доля Алексей', _formatPercent(alexFinalShare * 100)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
