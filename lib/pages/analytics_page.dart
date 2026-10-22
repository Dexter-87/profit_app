import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:my_app/theme/app_colors.dart';
import 'package:my_app/widgets/app_ui.dart';
import 'package:url_launcher/url_launcher.dart';

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


  // Отдельный отчёт. Существующие расчёты прибыли не затрагиваются.
  static final DateTime _vanyaStart = DateTime(2026, 10, 20);
  static const Map<String, int> _vanyaPrices = {
    'EDISSON ER 100 V': 46853,
    'EDISSON ER 50 V': 34783,
    'EDISSON ER 80 V': 40463,
    'EDISSON ES 30 V': 29813,
    'ETALON ER 100 V': 47563,
    'ETALON ER 50 V': 36913,
    'ETALON ER 80 H': 42593,
    'ETALON ER 80 V': 41883,
    'ETALON ES 30 V': 33363,
    'ETALON ES 50 V': 39043,
  };

  DateTime? _vanyaParseDate(dynamic raw) {
    final v = (raw ?? '').toString().trim();
    if (v.isEmpty) return null;
    final parts = v.split('.');
    if (parts.length == 3) {
      final d = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final y = int.tryParse(parts[2]);
      if (d != null && m != null && y != null) {
        final result = DateTime(y, m, d);
        if (result.day == d && result.month == m && result.year == y) return result;
      }
    }
    return DateTime.tryParse(v);
  }

  String? _vanyaMatch(String raw) {
    final normalized = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), ' ').trim();
    for (final model in _vanyaPrices.keys) {
      final escaped = RegExp.escape(model);
      if (RegExp('(^| )' + escaped + r'( |$)').hasMatch(normalized)) return model;
    }
    return null;
  }

  Future<void> _openVanyaReport() async {
    final from = _dateFrom ?? _vanyaStart;
    final to = _dateTo ?? DateTime.now();
    if (to.isBefore(from)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Проверьте даты отчёта')),
      );
      return;
    }
    showDialog<void>(context: context, barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final rows = await ApiService.fetchSales();
      final sums = <String, int>{};
      var included = 0;
      var ignoredWithoutDate = 0;
      for (final row in rows) {
        final product = (row['Наименование'] ?? row['Товар'] ?? row['product'] ?? '').toString();
        final model = _vanyaMatch(product);
        if (model == null) continue;
        final date = _vanyaParseDate(row['Дата'] ?? row['date']);
        if (date == null) { ignoredWithoutDate++; continue; }
        if (date.isBefore(_vanyaStart) || date.isBefore(from) || date.isAfter(to)) continue;
        // Если API вернул дату создания, исключаем созданные до запуска отчёта записи.
        final createdRaw = row['created_at'] ?? row['createdAt'];
        if (createdRaw != null) {
          final created = DateTime.tryParse(createdRaw.toString());
          if (created != null && created.isBefore(_vanyaStart)) continue;
        }
        sums.update(model, (value) => value + 1, ifAbsent: () => 1);
        included++;
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      final totalCents = sums.entries.fold<int>(0,
        (total, e) => total + (e.value * _vanyaPrices[e.key]! * 20));
      // Цены целые, поэтому 2% = (цена × 20) / 1000.
      final total = totalCents / 1000.0;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: AppColors.bg,
          insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 700),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF1666CB), Color(0xFF348FF0)]),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.receipt_long_outlined, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('TechnoOpt', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      const Text('Доп. выплата за Edisson / Etalon', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    ])),
                    IconButton(onPressed: () => Navigator.pop(dialogContext), icon: const Icon(Icons.close, color: Colors.white)),
                  ]),
                ),
                Flexible(child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Период: ${_formatDisplayDate(from)} — ${_formatDisplayDate(to)}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: AppUi.cardDecoration(color: AppColors.bg, radius: 16,
                        borderColor: AppColors.stroke, shadows: const []),
                      child: Wrap(spacing: 30, runSpacing: 14, children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Продано', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          const SizedBox(height: 5),
                          Text('$included шт.', style: const TextStyle(color: AppColors.textMain, fontSize: 22, fontWeight: FontWeight.w800)),
                        ]),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('К выплате Ване', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          const SizedBox(height: 5),
                          Text(_formatMoney(total), style: const TextStyle(color: Color(0xFF35B5F5), fontSize: 22, fontWeight: FontWeight.w900)),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 18),
                    const Text('Расшифровка по моделям', style: TextStyle(color: AppColors.textMain, fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    if (sums.isEmpty)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Text('Новых продаж Edisson и Etalon за этот период нет.',
                        style: TextStyle(color: AppColors.textSecondary))),
                    ...sums.entries.map((e) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                      decoration: AppUi.cardDecoration(color: AppColors.bg, radius: 14,
                        borderColor: AppColors.stroke.withOpacity(0.75), shadows: const []),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(e.key, style: const TextStyle(color: AppColors.textMain, fontSize: 13, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('${e.value} шт. × ${_formatMoney(_vanyaPrices[e.key])} × 2%',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ])),
                        const SizedBox(width: 10),
                        Text(_formatMoney(e.value * _vanyaPrices[e.key]! * 0.02),
                          style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w800, fontSize: 13)),
                      ]),
                    )),
                    if (ignoredWithoutDate > 0)
                      Text('Не учтено без даты: $ignoredWithoutDate', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 12),
                    const Text('Учитываются только новые продажи с 20.10.2026. Сумма вносится в общие расходы вручную. Данные приложения не изменяются.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ]),
                )),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Align(alignment: Alignment.centerRight,
                    child: TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Закрыть'))),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось загрузить продажи: $e')));
    }
  }

  final double defaultRevenuePlan = 10000000;
  final double defaultProfitPlan = 800000;

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
    final today = DateTime(now.year, now.month, now.day);

    setState(() {
      _selectedPeriod = period;

      if (period == 'Сегодня') {
        _dateFrom = today;
        _dateTo = today;
      } else if (period == '7 дней') {
        _dateFrom = today.subtract(const Duration(days: 6));
        _dateTo = today;
      } else if (period == '30 дней') {
        _dateFrom = today.subtract(const Duration(days: 29));
        _dateTo = today;
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

    final cleaned = value
        .toString()
        .replaceAll('₸', '')
        .replaceAll('%', '')
        .replaceAll(' ', '')
        .replaceAll(',', '.');

    return double.tryParse(cleaned) ?? 0;
  }

  String _formatMoney(dynamic value) {
    final number = _toDouble(value).round().toString();
    final isNegative = number.startsWith('-');
    final cleanNumber = number.replaceAll('-', '');

    final buffer = StringBuffer();
    int counter = 0;

    for (int i = cleanNumber.length - 1; i >= 0; i--) {
      buffer.write(cleanNumber[i]);
      counter++;

      if (counter == 3 && i != 0) {
        buffer.write(' ');
        counter = 0;
      }
    }

    final result = buffer.toString().split('').reversed.join();
    return '${isNegative ? '-' : ''}$result ₸';
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

  List<dynamic> _safeList(dynamic value) {
    if (value is List) return value;
    return [];
  }

  void _openPdfReport(String endpoint) {
    final from = _formatApiDate(_dateFrom);
    final to = _formatApiDate(_dateTo);
    final cache = DateTime.now().millisecondsSinceEpoch;

    final url =
        '${ApiService.baseUrl}/$endpoint/pdf?dateFrom=$from&dateTo=$to&v=$cache';

    debugPrint('PDF URL: $url');

    launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  }

  Widget _pdfButton({
    required String title,
    required IconData icon,
    required String endpoint,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _openPdfReport(endpoint),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AppUi.cardDecoration(
          color: AppColors.bg,
          radius: 18,
          borderColor: AppColors.stroke.withOpacity(0.75),
          shadows: const [],
        ),
        child: Row(
          children: [
            AppUi.iconBadge(
              icon: icon,
              accent: const Color(0xFF06B6D4),
              size: 36,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.textMain,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
            const Icon(
              Icons.open_in_new,
              color: AppColors.textSecondary,
              size: 18,
            ),
          ],
        ),
      ),
    );
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

  Widget _brandRow(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: AppUi.cardDecoration(
        color: AppColors.bg,
        radius: 18,
        borderColor: AppColors.stroke.withOpacity(0.75),
        shadows: const [],
      ),
      child: Column(
        children: [
          _statRow(
            (item['brand'] ?? 'Другое').toString(),
            '${(item['count'] ?? 0).toString()} шт',
            bold: true,
          ),
          _statRow('Выручка', _formatMoney(item['revenue'])),
          _statRow('Прибыль', _formatMoney(item['profit'])),
          _statRow('Стас', _formatMoney(item['myProfit'])),
          _statRow('Алексей', _formatMoney(item['alexProfit'])),
        ],
      ),
    );
  }

  Widget _clientRow(Map<String, dynamic> item, int index, double totalProfit) {
    final rawClient = (item['client'] ?? '').toString().trim();
    final channel = (item['channel'] ?? '').toString().trim();

    final client = rawClient.isNotEmpty
        ? rawClient
        : (channel == 'Каспий' || channel == 'Каспи')
            ? 'Kaspi'
            : 'Физ.лицо';
    final revenue = _toDouble(item['revenue']);
    final profit = _toDouble(item['profit']);
    final count = (item['count'] ?? 0).toString();
    final share = totalProfit == 0 ? 0 : (profit / totalProfit) * 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: AppUi.cardDecoration(
        color: AppColors.bg,
        radius: 18,
        borderColor: const Color(0xFF4DA3FF).withOpacity(0.25),
        shadows: const [],
      ),
      child: Column(
        children: [
          Row(
            children: [
              AppUi.iconBadge(
                icon: Icons.person_outline,
                accent: const Color(0xFF4DA3FF),
                size: 34,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$index. $client',
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                _formatPercent(share),
                style: const TextStyle(
                  color: Color(0xFF22C55E),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _statRow('Выручка', _formatMoney(revenue)),
          _statRow('Прибыль', _formatMoney(profit), bold: true),
          _statRow('Продаж', count),
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
    final kaspiCommissions = _toDouble(_data['kaspiCommissions']);
    final kaspiTotalVisibleExpenses =
        _toDouble(_data['kaspiTotalVisibleExpenses']);

    final optRevenue = _toDouble(_data['optRevenue']);
    final optProfit = _toDouble(_data['optProfit']);
    final optCount = (_data['optCount'] ?? 0).toString();

    final revenuePlan = _toDouble(_data['revenuePlan']) > 0
        ? _toDouble(_data['revenuePlan'])
        : defaultRevenuePlan;

    final stasPlan = _toDouble(_data['stasPlan']) > 0
        ? _toDouble(_data['stasPlan'])
        : defaultProfitPlan;

    final alexPlan = _toDouble(_data['alexPlan']) > 0
        ? _toDouble(_data['alexPlan'])
        : defaultProfitPlan;

    final topProducts = _safeList(_data['topProducts']);
    final dailyProfit = _safeList(_data['dailyProfit']);
    final brands = _safeList(_data['brands']);
    final clients = _safeList(_data['clients']);
    final insights = _safeList(_data['insights']);

    final revenueProgress =
        revenuePlan == 0 ? 0.0 : (revenue / revenuePlan).clamp(0.0, 1.0);

    final stasProgress =
        stasPlan == 0 ? 0.0 : (myNet / stasPlan).clamp(0.0, 1.0);

    final alexProgress =
        alexPlan == 0 ? 0.0 : (alexNet / alexPlan).clamp(0.0, 1.0);

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
                                  'Прибыль, каналы, бренды, распределение доходов и выполнение плана.',
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
                                        ),
                                        const SizedBox(width: 8),
                                        AppUi.periodButton(
                                          title: '30 дней',
                                          selected:
                                              _selectedPeriod == '30 дней',
                                          onTap: () =>
                                              _applyPresetPeriod('30 дней'),
                                        ),
                                        const SizedBox(width: 8),
                                        AppUi.periodButton(
                                          title: 'Всё',
                                          selected: _selectedPeriod == 'Всё',
                                          onTap: () =>
                                              _applyPresetPeriod('Всё'),
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

                          AppUi.sectionCard(
                            title: 'PDF отчёты',
                            icon: Icons.picture_as_pdf_outlined,
                            accent: const Color(0xFF06B6D4),
                            child: Column(
                              children: [
                                _pdfButton(
                                  title: 'Общий отчёт бизнеса',
                                  icon: Icons.analytics_outlined,
                                  endpoint: 'business-report',
                                ),
                                const SizedBox(height: 10),
                                _pdfButton(
                                  title: 'Отчёт по клиентам',
                                  icon: Icons.people_alt_outlined,
                                  endpoint: 'clients-report',
                                ),
                                const SizedBox(height: 10),
                                _pdfButton(
                                  title: 'Отчёт по брендам',
                                  icon: Icons.sell_outlined,
                                  endpoint: 'brands-report',
                                ),
                                const SizedBox(height: 10),
                                _pdfButton(
                                  title: 'Доп. выплата за Edisson / Etalon',
                                  icon: Icons.receipt_long_outlined,
                                  endpoint: 'vanya-discount-report',
                                ),
                                const SizedBox(height: 10),
                                _pdfButton(
                                  title: 'Отчёт по расходам',
                                  icon: Icons.receipt_long_outlined,
                                  endpoint: 'expenses-report',
                                ),
                                const SizedBox(height: 10),

                                _pdfButton(
                                  title: 'Отчёт по поставщикам',
                                  icon: Icons.local_shipping_outlined,
                                  endpoint: 'supplier-report',
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

if (insights.isNotEmpty) ...[
  AppUi.sectionCard(
    title: 'Бизнес-инсайты',
    icon: Icons.auto_awesome_outlined,
    accent: const Color(0xFF8B5CF6),
    child: Column(
      children: List.generate(
        insights.length,
        (index) {
          final item =
              Map<String, dynamic>.from(
            insights[index] as Map,
          );

          final text =
              (item['text'] ?? '').toString();

          final icon =
              (item['icon'] ?? '📊').toString();

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: AppUi.cardDecoration(
              color: AppColors.bg,
              radius: 18,
              borderColor:
                  AppColors.stroke.withOpacity(0.7),
              shadows: const [],
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  icon,
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: AppColors.textMain,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  ),

  const SizedBox(height: 16),
],

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
                            title: 'Расходы Каспий',
                            icon: Icons.account_balance_wallet_outlined,
                            accent: const Color(0xFF06B6D4),
                            child: Column(
                              children: [
                                _statRow(
                                  'Удержания Kaspi',
                                  _formatMoney(kaspiCommissions),
                                ),
                                _statRow(
                                  'Всего расходов канала',
                                  _formatMoney(kaspiTotalVisibleExpenses),
                                  bold: true,
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
                                  title: 'План прибыли общий',
                                  currentLabel: _formatMoney(myNet + alexNet),
                                  totalLabel: _formatMoney(stasPlan + alexPlan),
                                  progress: (stasPlan + alexPlan) == 0
                                      ? 0.0
                                      : ((myNet + alexNet) / (stasPlan + alexPlan))
                                          .clamp(0.0, 1.0),
                                  accentColors: const [
                                    Color(0xFF4DA3FF),
                                    Color(0xFF2D7DFF),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                AppUi.progressBlock(
                                  title: 'План чистой прибыли Стаса',
                                  currentLabel: _formatMoney(myNet),
                                  totalLabel: _formatMoney(stasPlan),
                                  progress: stasProgress,
                                  accentColors: const [
                                    Color(0xFF22C55E),
                                    Color(0xFF16A34A),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                AppUi.progressBlock(
                                  title: 'План чистой прибыли Алексея',
                                  currentLabel: _formatMoney(alexNet),
                                  totalLabel: _formatMoney(alexPlan),
                                  progress: alexProgress,
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
                            title: 'Топ клиентов',
                            icon: Icons.people_alt_outlined,
                            accent: const Color(0xFF4DA3FF),
                            child: clients.isEmpty
                                ? AppUi.emptyBlock('Нет данных по клиентам')
                                : Column(
                                    children: List.generate(
                                      clients.length,
                                      (index) {
                                        final item =
                                            Map<String, dynamic>.from(
                                          clients[index] as Map,
                                        );

                                        return _clientRow(
                                          item,
                                          index + 1,
                                          totalProfit,
                                        );
                                      },
                                    ),
                                  ),
                          ),

                          const SizedBox(height: 16),

                          AppUi.sectionCard(
                            title: 'Бренды',
                            icon: Icons.sell_outlined,
                            accent: const Color(0xFF06B6D4),
                            child: brands.isEmpty
                                ? AppUi.emptyBlock('Нет данных по брендам')
                                : Column(
                                    children: List.generate(
                                      brands.length,
                                      (index) {
                                        final item =
                                            Map<String, dynamic>.from(
                                          brands[index] as Map,
                                        );
                                        return _brandRow(item);
                                      },
                                    ),
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
                                  'Капитал + работа — прибыль распределяется по итоговой доле из весов капитала и работы.',
                                  accent: const Color(0xFFF59E0B),
                                ),
                                _bullet(
                                  'Расходы учитываются в чистой прибыли и распределяются по итоговой доле модели.',
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
                                  'Стас',
                                  _formatMoney(myNet),
                                  bold: true,
                                ),
                                _statRow(
                                  'Алексей',
                                  _formatMoney(alexNet),
                                  bold: true,
                                ),
                                const Divider(
                                  color: AppColors.stroke,
                                  height: 24,
                                ),
                                _statRow(
                                  'Общая чистая прибыль',
                                  _formatMoney(myNet + alexNet),
                                  bold: true,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          AppUi.sectionCard(
                            title: 'Доп. доходы 50/50',
                            icon: Icons.handshake_outlined,
                            accent: const Color(0xFF06B6D4),
                            child: Column(
                              children: [
                                _statRow(
                                  'Доход',
                                  _formatMoney(_data['sideIncomeTotal']),
                                ),
                                _statRow(
                                  'Расход',
                                  _formatMoney(_data['sideIncomeExpense']),
                                ),
                                _statRow(
                                  'Чистая прибыль',
                                  _formatMoney(_data['sideIncomeProfit']),
                                  bold: true,
                                ),
                                const Divider(
                                  color: AppColors.stroke,
                                  height: 24,
                                ),
                                _statRow(
                                  'Стас',
                                  _formatMoney(_data['sideIncomeStas']),
                                  bold: true,
                                ),
                                _statRow(
                                  'Алексей',
                                  _formatMoney(_data['sideIncomeAlexey']),
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
                                        final item =
                                            Map<String, dynamic>.from(
                                          topProducts[index] as Map,
                                        );

                                        return AppUi.rankingRow(
                                          index: index + 1,
                                          title: (item['name'] ??
                                                  'Без названия')
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
                                        final item =
                                            Map<String, dynamic>.from(
                                          dailyProfit[index] as Map,
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