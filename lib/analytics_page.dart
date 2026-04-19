import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});
  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}
class _AnalyticsPageState extends State<AnalyticsPage> {
  // ВСТАВЬ СЮДА CSV-ссылку именно на лист APP Distribution
  static const String distributionCsvUrl =
      'PASTE_YOUR_APP_DISTRIBUTION_CSV_URL_HERE';
  bool isLoading = true;
  String? error;
  Map<String, List<String>> rows = {};
  @override
  void initState() {
    super.initState();
    loadDistribution();
  }
  Future<void> loadDistribution() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final uri = Uri.parse(distributionCsvUrl);
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('Ошибка загрузки CSV: ${response.statusCode}');
      }
      final csvText = utf8.decode(response.bodyBytes);
      final csvTable = const CsvToListConverter(
        shouldParseNumbers: false,
        eol: '\n',
      ).convert(csvText);
      final parsed = <String, List<String>>{};
      for (final row in csvTable) {
        if (row.isEmpty) continue;
        final values = row.map((e) => e.toString().trim()).toList();
        final first = values.first.trim().toLowerCase();
        if (first.isEmpty || first == 'metric') continue;
        parsed[first] = values;
      }
      setState(() {
        rows = parsed;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }
  String _normalizeKey(String value) {
    return value.trim().toLowerCase();
  }
  List<String>? _row(String key) => rows[_normalizeKey(key)];
  String _cell(String key, int index, {String fallback = '—'}) {
    final row = _row(key);
    if (row == null) return fallback;
    if (index >= row.length) return fallback;
    final value = row[index].trim();
    return value.isEmpty ? fallback : value;
  }
  double? _toDouble(String value) {
    final clean = value
        .replaceAll('₸', '')
        .replaceAll('%', '')
        .replaceAll(' ', '')
        .replaceAll(',', '.')
        .trim();
    return double.tryParse(clean);
  }
  String _formatMoney(String raw) {
    final n = _toDouble(raw);
    if (n == null) return raw;
    final intValue = n.round();
    final s = intValue.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final reverseIndex = s.length - i;
      buffer.write(s[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write(' ');
      }
    }
    return '${buffer.toString()} ₸';
  }
  String _formatPercent(String raw) {
    final n = _toDouble(raw);
    if (n == null) return raw;
    return '${n.toStringAsFixed(2)}%';
  }
  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF07111F);
    const panel = Color(0xFF0E1B2E);
    const panel2 = Color(0xFF12233B);
    const cyan = Color(0xFF49D6FF);
    const green = Color(0xFF4FE39A);
    const orange = Color(0xFFFFB44D);
    const purple = Color(0xFF8F7CFF);
    const textSoft = Color(0xFF9CB3C9);
    final investmentsStas = _cell('вложения', 1);
    final investmentsAlexey = _cell('вложения', 2);
    final investmentsTotal = _cell('вложения', 3);
    final investShareStas = _cell('доля вложений', 1);
    final investShareAlexey = _cell('доля вложений', 2);
    final workPointsStas = _cell('баллы за работу', 1);
    final workPointsAlexey = _cell('баллы за работу', 2);
    final workShareStas = _cell('доля работы', 1);
    final workShareAlexey = _cell('доля работы', 2);
    final finalShareStas = _cell('итоговая доля', 1);
    final finalShareAlexey = _cell('итоговая доля', 2);
    final profitStas = _cell('прибыль стаса', 1);
    final profitAlexey = _cell('прибыль стаса', 2);
    final totalProfit = _cell('общая прибыль', 1);
    final model = _cell('model', 1, fallback: '—');
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        title: const Text(
          'Аналитика',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: loadDistribution,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: loadDistribution,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: panel,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: cyan.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.analytics_rounded,
                                color: cyan,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Финансовая модель',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Текущий режим: $model',
                                    style: const TextStyle(
                                      color: textSoft,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      _sectionTitle('Главные показатели'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _metricCard(
                              title: 'Общая прибыль',
                              value: _formatMoney(totalProfit),
                              color: cyan,
                              icon: Icons.account_balance_wallet_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _metricCard(
                              title: 'Прибыль Стаса',
                              value: _formatMoney(profitStas),
                              color: green,
                              icon: Icons.person_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _metricCard(
                        title: 'Прибыль Алексея',
                        value: _formatMoney(profitAlexey),
                        color: orange,
                        icon: Icons.groups_rounded,
                      ),
                      const SizedBox(height: 22),
                      _sectionTitle('Вложения'),
                      const SizedBox(height: 10),
                      _dualCard(
                        leftTitle: 'Стас',
                        leftValue: _formatMoney(investmentsStas),
                        leftSubtitle: 'Доля: ${_formatPercent(investShareStas)}',
                        rightTitle: 'Алексей',
                        rightValue: _formatMoney(investmentsAlexey),
                        rightSubtitle: 'Доля: ${_formatPercent(investShareAlexey)}',
                        totalTitle: 'Общие вложения',
                        totalValue: _formatMoney(investmentsTotal),
                        color: cyan,
                      ),
                      const SizedBox(height: 22),
                      _sectionTitle('Работа'),
                      const SizedBox(height: 10),
                      _dualCard(
                        leftTitle: 'Стас',
                        leftValue: '$workPointsStas баллов',
                        leftSubtitle: 'Доля работы: ${_formatPercent(workShareStas)}',
                        rightTitle: 'Алексей',
                        rightValue: '$workPointsAlexey баллов',
                        rightSubtitle: 'Доля работы: ${_formatPercent(workShareAlexey)}',
                        totalTitle: 'Сумма баллов',
                        totalValue: _cell('баллы за работу', 3),
                        color: purple,
                      ),
                      const SizedBox(height: 22),
                      _sectionTitle('Итоговое распределение'),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: panel2,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          children: [
                            _shareBar(
                              label: 'Стас',
                              percentText: _formatPercent(finalShareStas),
                              value: (_toDouble(finalShareStas) ?? 0) / 100,
                              color: green,
                            ),
                            const SizedBox(height: 18),
                            _shareBar(
                              label: 'Алексей',
                              percentText: _formatPercent(finalShareAlexey),
                              value: (_toDouble(finalShareAlexey) ?? 0) / 100,
                              color: orange,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }
  Widget _metricCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1B2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF9CB3C9),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _dualCard({
    required String leftTitle,
    required String leftValue,
    required String leftSubtitle,
    required String rightTitle,
    required String rightValue,
    required String rightSubtitle,
    required String totalTitle,
    required String totalValue,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF12233B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _personBlock(
                  title: leftTitle,
                  value: leftValue,
                  subtitle: leftSubtitle,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _personBlock(
                  title: rightTitle,
                  value: rightValue,
                  subtitle: rightSubtitle,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(Icons.summarize_rounded, color: Colors.white70),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    totalTitle,
                    style: const TextStyle(color: Color(0xFF9CB3C9)),
                  ),
                ),
                Text(
                  totalValue,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _personBlock({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF9CB3C9),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  Widget _shareBar({
    required String label,
    required String percentText,
    required double value,
    required Color color,
  }) {
    final clamped = value.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            Text(
              percentText,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: clamped,
            minHeight: 12,
            backgroundColor: Colors.white.withOpacity(0.08),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
