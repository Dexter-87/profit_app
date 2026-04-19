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

  int selectedTab = 0;

  bool isLoading = true;

  String errorText = '';

  List<List<String>> rawRows = [];

  final List<Map<String, String>> tabs = [

  {

    'title': 'Продажи',

    'url':

        'https://docs.google.com/spreadsheets/d/e/2PACX-1vSQ-klgRv6fa6_m4rGSRge2LwLronSDC_0GqQ6te_OK17hhz6oKWB2YgD0ZSUiiXg/pub?gid=2127661582&single=true&output=csv',

  },

  {

    'title': 'Вложения',

    'url':

        'https://docs.google.com/spreadsheets/d/e/2PACX-1vSQ-klgRv6fa6_m4rGSRge2LwLronSDC_0GqQ6te_OK17hhz6oKWB2YgD0ZSUiiXg/pub?gid=542093589&single=true&output=csv',

  },

  {

    'title': 'Сводка',

    'url':

        'https://docs.google.com/spreadsheets/d/e/2PACX-1vSQ-klgRv6fa6_m4rGSRge2LwLronSDC_0GqQ6te_OK17hhz6oKWB2YgD0ZSUiiXg/pub?gid=1883771878&single=true&output=csv',

  },

  {

    'title': 'План',

    'url':

        'https://docs.google.com/spreadsheets/d/e/2PACX-1vSQ-klgRv6fa6_m4rGSRge2LwLronSDC_0GqQ6te_OK17hhz6oKWB2YgD0ZSUiiXg/pub?gid=1805316772&single=true&output=csv',

  },

  {

    'title': 'Распределение',

    'url':

        'https://docs.google.com/spreadsheets/d/e/2PACX-1vSQ-klgRv6fa6_m4rGSRge2LwLronSDC_0GqQ6te_OK17hhz6oKWB2YgD0ZSUiiXg/pub?gid=193041784&single=true&output=csv',

  },

];


  @override

  void initState() {

    super.initState();

    loadData();

  }

  Future<void> loadData() async {

    setState(() {

      isLoading = true;

      errorText = '';

      rawRows = [];

    });

    try {

      final url = tabs[selectedTab]['url']!;

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {

        setState(() {

          errorText = 'Ошибка загрузки: ${response.statusCode}';

          isLoading = false;

        });

        return;

      }

      final decoded = utf8.decode(response.bodyBytes);

      final rows = const CsvToListConverter(

        shouldParseNumbers: false,

        eol: '\n',

      ).convert(decoded);

      rawRows = rows

          .map((row) => row.map((e) => e.toString().trim()).toList())

          .toList();

      setState(() {

        isLoading = false;

      });

    } catch (e) {

      setState(() {

        errorText = 'Ошибка: $e';

        isLoading = false;

      });

    }

  }

  String normalize(String value) {

    return value

        .toLowerCase()

        .replaceAll('\n', ' ')

        .replaceAll('\r', ' ')

        .replaceAll('ё', 'е')

        .replaceAll(RegExp(r'\s+'), ' ')

        .trim();

  }

  String cell(List<List<String>> rows, int r, int c) {

    if (r < 0 || r >= rows.length) return '';

    if (c < 0 || c >= rows[r].length) return '';

    return rows[r][c].trim();

  }

  double toDouble(String value) {

    final cleaned = value

        .replaceAll('₸', '')

        .replaceAll('%', '')

        .replaceAll('\u00A0', '')

        .replaceAll(' ', '')

        .replaceAll(',', '.')

        .trim();

    return double.tryParse(cleaned) ?? 0;

  }

  String formatMoney(double value) {

    final number = value.round().toString();

    final result = StringBuffer();

    for (int i = 0; i < number.length; i++) {

      final reverseIndex = number.length - i;

      result.write(number[i]);

      if (reverseIndex > 1 && reverseIndex % 3 == 1) {

        result.write(' ');

      }

    }

    return '${result.toString()} ₸';

  }

  String formatPercent(num value) {

    return '${value.toDouble().toStringAsFixed(2)}%';

  }

  int findHeaderRow(List<String> variants) {

    for (int r = 0; r < rawRows.length; r++) {

      final rowText = rawRows[r].map(normalize).join(' | ');

      for (final v in variants) {

        if (rowText.contains(normalize(v))) {

          return r;

        }

      }

    }

    return -1;

  }

  int findColumnIndex(List<String> headerRow, List<String> variants) {

    for (int i = 0; i < headerRow.length; i++) {

      final h = normalize(headerRow[i]);

      for (final v in variants) {

        if (h == normalize(v)) return i;

      }

    }

    return -1;

  }

  Widget buildTabButton(int index) {

    final isActive = selectedTab == index;

    return GestureDetector(

      onTap: () {

        setState(() {

          selectedTab = index;

        });

        loadData();

      },

      child: AnimatedContainer(

        duration: const Duration(milliseconds: 180),

        margin: const EdgeInsets.only(right: 8),

        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),

        decoration: BoxDecoration(

          color: isActive ? const Color(0xFF23C4FF) : const Color(0xFF172033),

          borderRadius: BorderRadius.circular(14),

          border: Border.all(

            color: isActive ? const Color(0xFF7BE0FF) : const Color(0xFF293246),

          ),

          boxShadow: isActive

              ? [

                  BoxShadow(

                    color: const Color(0xFF23C4FF).withOpacity(0.22),

                    blurRadius: 12,

                    spreadRadius: 1,

                  )

                ]

              : [],

        ),

        child: Text(

          tabs[index]['title']!,

          style: TextStyle(

            color: isActive ? Colors.white : const Color(0xFFB7C2D9),

            fontWeight: FontWeight.w700,

            fontSize: 13,

          ),

        ),

      ),

    );

  }

  Widget statCard(

    String title,

    String value,

    IconData icon, {

    Color iconBg = const Color(0xFF1D3048),

    Color iconColor = const Color(0xFF69C8FF),

  }) {

    return Container(

      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(

        color: const Color(0xFF131C2B),

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: const Color(0xFF283246)),

      ),

      child: Row(

        children: [

          Container(

            width: 46,

            height: 46,

            decoration: BoxDecoration(

              color: iconBg,

              borderRadius: BorderRadius.circular(14),

            ),

            child: Icon(icon, color: iconColor),

          ),

          const SizedBox(width: 12),

          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(

                  title,

                  style: const TextStyle(

                    color: Color(0xFF95A4BF),

                    fontSize: 12,

                  ),

                ),

                const SizedBox(height: 4),

                Text(

                  value,

                  style: const TextStyle(

                    color: Colors.white,

                    fontSize: 18,

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

  Widget valueRow(

    String label,

    String value, {

    Color valueColor = Colors.white,

  }) {

    return Padding(

      padding: const EdgeInsets.only(bottom: 10),

      child: Row(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          SizedBox(

            width: 118,

            child: Text(

              label,

              style: const TextStyle(

                color: Color(0xFF95A4BF),

                fontSize: 13,

              ),

            ),

          ),

          Expanded(

            child: Text(

              value.isEmpty ? '-' : value,

              textAlign: TextAlign.right,

              style: TextStyle(

                color: valueColor,

                fontSize: 13,

                fontWeight: FontWeight.w700,

              ),

            ),

          ),

        ],

      ),

    );

  }

  Widget sectionTitle(String text) {

    return Padding(

      padding: const EdgeInsets.only(bottom: 12),

      child: Text(

        text,

        style: const TextStyle(

          color: Colors.white,

          fontSize: 19,

          fontWeight: FontWeight.w800,

        ),

      ),

    );

  }

  Widget panel({required Widget child, EdgeInsets? padding}) {

    return Container(

      margin: const EdgeInsets.only(bottom: 14),

      padding: padding ?? const EdgeInsets.all(14),

      decoration: BoxDecoration(

        color: const Color(0xFF131C2B),

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: const Color(0xFF283246)),

      ),

      child: child,

    );

  }

  Widget buildSalesView() {

    final headerRowIndex =

        findHeaderRow(['дата', 'наименование', 'номер заказа', 'чистая прибыль']);

    if (headerRowIndex == -1) {

      return buildFallbackView();

    }

    final headers = rawRows[headerRowIndex];

    final data = rawRows

        .skip(headerRowIndex + 1)

        .where((r) => r.any((e) => e.trim().isNotEmpty))

        .toList();

    final dateIdx = findColumnIndex(headers, ['Дата']);

    final channelIdx = findColumnIndex(headers, ['Каспий', 'Канал']);

    final nameIdx = findColumnIndex(headers, ['Наименование']);

    final orderIdx = findColumnIndex(headers, ['Номер заказа']);

    final costIdx = findColumnIndex(headers, ['Себестоимость']);

    final rrcIdx = findColumnIndex(headers, ['РРЦ']);

    final commIdx = findColumnIndex(headers, ['Комиссия Kaspi']);

    final profitIdx = findColumnIndex(headers, ['Чистая прибыль']);

    final commentIdx = findColumnIndex(headers, ['Комментарий']);

    final monthIdx = findColumnIndex(headers, ['Месяц']);

    double totalRevenue = 0;

    double totalProfit = 0;

    for (final row in data) {

      totalRevenue += toDouble(cell([row], 0, rrcIdx));

      totalProfit += toDouble(cell([row], 0, profitIdx));

    }

    final avgCheck = data.isEmpty ? 0 : totalRevenue / data.length;

    return ListView(

      padding: const EdgeInsets.all(14),

      children: [

        sectionTitle('Продажи'),

        statCard('Выручка', formatMoney(totalRevenue), Icons.payments_rounded),

        const SizedBox(height: 10),

        statCard(

          'Чистая прибыль',

          formatMoney(totalProfit),

          Icons.trending_up_rounded,

          iconBg: const Color(0xFF143126),

          iconColor: const Color(0xFF5DE39A),

        ),

        const SizedBox(height: 10),

        statCard(

          'Количество продаж',

          data.length.toString(),

          Icons.receipt_long_rounded,

          iconBg: const Color(0xFF302317),

          iconColor: const Color(0xFFFFC76A),

        ),

        const SizedBox(height: 10),

        statCard(

          'Средний чек',

          formatMoney(avgCheck.toDouble()),

          Icons.shopping_cart_checkout_rounded,

          iconBg: const Color(0xFF2B1D43),

          iconColor: const Color(0xFFBC9BFF),

        ),

        const SizedBox(height: 18),

        sectionTitle('Список продаж'),

        ...data.map((row) {

          final profit = toDouble(cell([row], 0, profitIdx));

          return panel(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(

                  cell([row], 0, nameIdx).isEmpty

                      ? 'Без названия'

                      : cell([row], 0, nameIdx),

                  style: const TextStyle(

                    color: Colors.white,

                    fontSize: 15,

                    fontWeight: FontWeight.w800,

                  ),

                ),

                const SizedBox(height: 10),

                Wrap(

                  spacing: 8,

                  runSpacing: 8,

                  children: [

                    smallChip('Дата', cell([row], 0, dateIdx)),

                    smallChip('Канал', cell([row], 0, channelIdx)),

                    smallChip('Заказ', cell([row], 0, orderIdx)),

                    if (monthIdx != -1) smallChip('Месяц', cell([row], 0, monthIdx)),

                  ],

                ),

                const SizedBox(height: 12),

                valueRow('Себестоимость', cell([row], 0, costIdx)),

                valueRow('РРЦ', cell([row], 0, rrcIdx)),

                valueRow('Комиссия', cell([row], 0, commIdx)),

                valueRow(

                  'Прибыль',

                  cell([row], 0, profitIdx),

                  valueColor: profit >= 0

                      ? const Color(0xFF64E39A)

                      : const Color(0xFFFF8F8F),

                ),

                if (commentIdx != -1 &&

                    cell([row], 0, commentIdx).trim().isNotEmpty)

                  valueRow('Комментарий', cell([row], 0, commentIdx)),

              ],

            ),

          );

        }),

      ],

    );

  }

  Widget smallChip(String label, String value) {

    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),

      decoration: BoxDecoration(

        color: const Color(0xFF1B2638),

        borderRadius: BorderRadius.circular(10),

      ),

      child: Text(

        '$label: ${value.isEmpty ? '-' : value}',

        style: const TextStyle(

          color: Color(0xFFD7E0F4),

          fontSize: 12,

          fontWeight: FontWeight.w600,

        ),

      ),

    );

  }

  Widget buildInvestmentsView() {

    final headerIndex = findHeaderRow(['направление', 'вкладчик', 'сумма вложений']);

    if (headerIndex == -1) {

      return buildFallbackView();

    }

    final headers = rawRows[headerIndex];

    final data = rawRows

        .skip(headerIndex + 1)

        .where((r) => r.any((e) => e.trim().isNotEmpty))

        .toList();

    final directionIdx = findColumnIndex(headers, ['Направление']);

    final investorIdx = findColumnIndex(headers, ['Вкладчик']);

    final amountIdx = findColumnIndex(headers, ['Сумма вложений']);

    double total = 0;

    for (final row in data) {

      total += toDouble(cell([row], 0, amountIdx));

    }

    return ListView(

      padding: const EdgeInsets.all(14),

      children: [

        sectionTitle('Вложения'),

        statCard('Общая сумма вложений', formatMoney(total), Icons.account_balance_wallet_rounded),

        const SizedBox(height: 18),

        ...data.map((row) {

          final amount = toDouble(cell([row], 0, amountIdx));

          final share = total == 0 ? 0 : amount / total * 100;

          return panel(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(

                  cell([row], 0, investorIdx),

                  style: const TextStyle(

                    color: Colors.white,

                    fontSize: 16,

                    fontWeight: FontWeight.w800,

                  ),

                ),

                const SizedBox(height: 10),

                valueRow('Направление', cell([row], 0, directionIdx)),

                valueRow('Сумма', formatMoney(amount)),

                valueRow('Доля', formatPercent(share.toDouble())),

              ],

            ),

          );

        }),

      ],

    );

  }

  Widget buildSummaryView() {

    final rows = rawRows.where((r) => r.any((e) => e.trim().isNotEmpty)).toList();

    String findValueByLabel(List<String> labels) {

      for (final row in rows) {

        for (int i = 0; i < row.length - 1; i++) {

          final left = normalize(row[i]);

          for (final label in labels) {

            if (left == normalize(label)) {

              return row[i + 1];

            }

          }

        }

      }

      return '';

    }

    final totalProfit = findValueByLabel(['Общая чистая прибыль', 'Общая прибыль']);

    final myAriston = findValueByLabel(['Моя доля Ariston']);

    final myNonAriston = findValueByLabel(['Моя доля не Ariston (+)']);

    final myIncome = findValueByLabel(['Мой итоговый доход']);

    final alexIncome = findValueByLabel(['Итоговый доход Алексея']);

    final aristonProfit = findValueByLabel(['Прибыль Ariston']);

    final nonAristonProfit = findValueByLabel(['Прибыль НЕ Ariston', 'Прибыль не Ariston']);

    return ListView(

      padding: const EdgeInsets.all(14),

      children: [

        sectionTitle('Сводка'),

        statCard('Общая прибыль', formatMoney(toDouble(totalProfit)), Icons.savings_rounded),

        const SizedBox(height: 10),

        statCard(

          'Мой итоговый доход',

          formatMoney(toDouble(myIncome)),

          Icons.person_rounded,

          iconBg: const Color(0xFF19314A),

          iconColor: const Color(0xFF72C8FF),

        ),

        const SizedBox(height: 10),

        statCard(

          'Доход Алексея',

          formatMoney(toDouble(alexIncome)),

          Icons.groups_rounded,

          iconBg: const Color(0xFF2A223D),

          iconColor: const Color(0xFFC49BFF),

        ),

        const SizedBox(height: 18),

        sectionTitle('Детализация'),

        panel(

          child: Column(

            children: [

              valueRow('Прибыль Ariston', aristonProfit),

              valueRow('Прибыль НЕ Ariston', nonAristonProfit),

              valueRow('Моя доля Ariston', myAriston),

              valueRow('Моя доля не Ariston', myNonAriston),

              valueRow('Мой итоговый доход', myIncome),

              valueRow('Итог Алексея', alexIncome),

            ],

          ),

        ),

      ],

    );

  }

  Widget buildPlanView() {

    final headerIndex = findHeaderRow(['месяц', 'коэффициент', 'план прибыль']);

    if (headerIndex == -1) {

      return buildFallbackView();

    }

    final headers = rawRows[headerIndex];

    final data = rawRows

        .skip(headerIndex + 1)

        .where((r) => r.any((e) => e.trim().isNotEmpty))

        .where((r) => normalize(cell([r], 0, 0)).isNotEmpty)

        .toList();

    final monthIdx = findColumnIndex(headers, ['Месяц']);

    final coeffIdx = findColumnIndex(headers, ['Коэффициент']);

    final planIdx = findColumnIndex(headers, ['План прибыль']);

    final factIdx = findColumnIndex(headers, ['Факт']);

    final devIdx = findColumnIndex(headers, ['Отклонение']);

    final baseIdx = findColumnIndex(headers, ['Базовая прибыль']);

    final perfIdx = findColumnIndex(headers, ['Выполнение %']);

    final qtyIdx = findColumnIndex(headers, ['План продаж шт']);

    final kaspiPlanIdx = findColumnIndex(headers, ['План Kaspi']);

    final factKaspiIdx = findColumnIndex(headers, ['Факт Kaspi']);

    final kaspiPerfIdx = findColumnIndex(headers, ['Выполнение Kaspi']);

    final optPlanIdx = findColumnIndex(headers, ['План ОПТ']);

    final optFactIdx = findColumnIndex(headers, ['Факт ОПТ']);

    final optPerfIdx = findColumnIndex(headers, ['Выполнение ОПТ']);

    final validRows = data.where((row) {

      final month = cell([row], 0, monthIdx);

      return month.isNotEmpty &&

          !normalize(month).contains('доля каспи') &&

          !normalize(month).contains('прибыль с одной продажи');

    }).toList();

    double yearPlan = 0;

    double yearFact = 0;

    for (final row in validRows) {

      yearPlan += toDouble(cell([row], 0, planIdx));

      yearFact += toDouble(cell([row], 0, factIdx));

    }

    final yearPerf = yearPlan == 0 ? 0 : yearFact / yearPlan * 100;

    return ListView(

      padding: const EdgeInsets.all(14),

      children: [

        sectionTitle('План годовой'),

        statCard('План по прибыли', formatMoney(yearPlan), Icons.flag_rounded),

        const SizedBox(height: 10),

        statCard(

          'Факт',

          formatMoney(yearFact),

          Icons.show_chart_rounded,

          iconBg: const Color(0xFF143126),

          iconColor: const Color(0xFF64E39A),

        ),

        const SizedBox(height: 10),

        statCard(

          'Выполнение',

          formatPercent(yearPerf.toDouble()),

          Icons.percent_rounded,

          iconBg: const Color(0xFF2A223D),

          iconColor: const Color(0xFFC49BFF),

        ),

        const SizedBox(height: 18),

        ...validRows.map((row) {

          final plan = toDouble(cell([row], 0, planIdx));

          final fact = toDouble(cell([row], 0, factIdx));

          final percentValue = cell([row], 0, perfIdx).isNotEmpty

              ? toDouble(cell([row], 0, perfIdx))

              : (plan == 0 ? 0 : fact / plan * 100);

          return panel(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(

                  cell([row], 0, monthIdx),

                  style: const TextStyle(

                    color: Colors.white,

                    fontSize: 16,

                    fontWeight: FontWeight.w800,

                  ),

                ),

                const SizedBox(height: 10),

                valueRow('Коэффициент', cell([row], 0, coeffIdx)),

                valueRow('План прибыли', cell([row], 0, planIdx)),

                valueRow('Факт', cell([row], 0, factIdx)),

                if (devIdx != -1) valueRow('Отклонение', cell([row], 0, devIdx)),

                if (baseIdx != -1 &&

                    cell([row], 0, baseIdx).trim().isNotEmpty)

                  valueRow('Базовая прибыль', cell([row], 0, baseIdx)),

                valueRow('Выполнение', formatPercent(percentValue.toDouble())),

                const SizedBox(height: 8),

                const Divider(color: Color(0xFF283246)),

                const SizedBox(height: 8),

                if (qtyIdx != -1) valueRow('План продаж шт', cell([row], 0, qtyIdx)),

                if (kaspiPlanIdx != -1) valueRow('План Kaspi', cell([row], 0, kaspiPlanIdx)),

                if (factKaspiIdx != -1) valueRow('Факт Kaspi', cell([row], 0, factKaspiIdx)),

                if (kaspiPerfIdx != -1) valueRow('Выполнение Kaspi', cell([row], 0, kaspiPerfIdx)),

                if (optPlanIdx != -1) valueRow('План ОПТ', cell([row], 0, optPlanIdx)),

                if (optFactIdx != -1) valueRow('Факт ОПТ', cell([row], 0, optFactIdx)),

                if (optPerfIdx != -1) valueRow('Выполнение ОПТ', cell([row], 0, optPerfIdx)),

              ],

            ),

          );

        }),

      ],

    );

  }

  Widget buildDistributionView() {

    final rows = rawRows.where((r) => r.any((e) => e.trim().isNotEmpty)).toList();

    String findNextToLabel(String label) {

      for (final row in rows) {

        for (int i = 0; i < row.length - 1; i++) {

          if (normalize(row[i]) == normalize(label)) {

            return row[i + 1];

          }

        }

      }

      return '';

    }

    String findValueInRow(String label, int valueColumn) {

      for (final row in rows) {

        if (row.isEmpty) continue;

        if (normalize(row[0]) == normalize(label) && valueColumn < row.length) {

          return row[valueColumn];

        }

      }

      return '';

    }

    final totalProfit = findNextToLabel('Общая прибыль');

    final shareStas = findNextToLabel('Доля Стаса');

    final shareAlex = findNextToLabel('Доля Алексея');

    final profitStas = findNextToLabel('Прибыль Стаса');

    final profitAlex = findNextToLabel('Прибыль Алексея');

    final investStas = findValueInRow('Вложения', 1);

    final investAlex = findValueInRow('Вложения', 2);

    final investShareStas = findValueInRow('Доля вложений', 1);

    final investShareAlex = findValueInRow('Доля вложений', 2);

    final workScoreStas = findValueInRow('Баллы за работу', 1);

    final workScoreAlex = findValueInRow('Баллы за работу', 2);

    final workShareStas = findValueInRow('Доля работы', 1);

    final workShareAlex = findValueInRow('Доля работы', 2);

    final finalShareStas = findValueInRow('Итоговая доля', 1);

    final finalShareAlex = findValueInRow('Итоговая доля', 2);

    final taskHeaderIndex = findHeaderRow(['задача', 'стас', 'алексей', 'вес задачи']);

    List<List<String>> taskRows = [];

    if (taskHeaderIndex != -1) {

      taskRows = rawRows

          .skip(taskHeaderIndex + 1)

          .where((r) => r.any((e) => e.trim().isNotEmpty))

          .where((r) {

            final firstNonEmpty = r.map(normalize).join(' | ');

            return !firstNonEmpty.contains('итого вес задачи') &&

                !firstNonEmpty.contains('режим') &&

                !firstNonEmpty.contains('капитал+работа') &&

                cell([r], 0, 1).trim().isNotEmpty;

          })

          .toList();

    }

    return ListView(

      padding: const EdgeInsets.all(14),

      children: [

        sectionTitle('Распределение прибыли и работы'),

        statCard('Общая прибыль', formatMoney(toDouble(totalProfit)), Icons.account_balance_rounded),

        const SizedBox(height: 10),

        statCard(

          'Прибыль Стаса',

          formatMoney(toDouble(profitStas)),

          Icons.person_rounded,

          iconBg: const Color(0xFF19314A),

          iconColor: const Color(0xFF72C8FF),

        ),

        const SizedBox(height: 10),

        statCard(

          'Прибыль Алексея',

          formatMoney(toDouble(profitAlex)),

          Icons.groups_rounded,

          iconBg: const Color(0xFF2A223D),

          iconColor: const Color(0xFFC49BFF),

        ),

        const SizedBox(height: 18),

        sectionTitle('Итоговые доли'),

        panel(

          child: Column(

            children: [

              valueRow('Доля Стаса', shareStas.isEmpty ? finalShareStas : shareStas),

              valueRow('Доля Алексея', shareAlex.isEmpty ? finalShareAlex : shareAlex),

              valueRow('Прибыль Стаса', profitStas),

              valueRow('Прибыль Алексея', profitAlex),

            ],

          ),

        ),

        sectionTitle('Капитал и работа'),

        panel(

          child: Column(

            children: [

              valueRow('Вложения Стаса', investStas),

              valueRow('Вложения Алексея', investAlex),

              valueRow('Доля вложений Стаса', investShareStas),

              valueRow('Доля вложений Алексея', investShareAlex),

              valueRow('Баллы за работу Стаса', workScoreStas),

              valueRow('Баллы за работу Алексея', workScoreAlex),

              valueRow('Доля работы Стаса', workShareStas),

              valueRow('Доля работы Алексея', workShareAlex),

              valueRow('Итоговая доля Стаса', finalShareStas),

              valueRow('Итоговая доля Алексея', finalShareAlex),

            ],

          ),

        ),

        if (taskRows.isNotEmpty) ...[

          sectionTitle('Задачи и вклад'),

          ...taskRows.map((row) {

            final task = cell([row], 0, 6);

            final stas = cell([row], 0, 7);

            final alex = cell([row], 0, 8);

            final weight = cell([row], 0, 9);

            final note = cell([row], 0, 10);

            return panel(

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Text(

                    task.isEmpty ? 'Задача' : task,

                    style: const TextStyle(

                      color: Colors.white,

                      fontSize: 15,

                      fontWeight: FontWeight.w800,

                    ),

                  ),

                  const SizedBox(height: 10),

                  valueRow('Стас', stas),

                  valueRow('Алексей', alex),

                  valueRow('Вес задачи', weight),

                  if (note.isNotEmpty) valueRow('Пояснение', note),

                ],

              ),

            );

          }),

        ],

      ],

    );

  }

  Widget buildFallbackView() {

    final nonEmpty = rawRows.where((r) => r.any((e) => e.trim().isNotEmpty)).toList();

    return ListView.builder(

      padding: const EdgeInsets.all(14),

      itemCount: nonEmpty.length,

      itemBuilder: (context, index) {

        final row = nonEmpty[index];

        return panel(

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: row

                .where((e) => e.trim().isNotEmpty)

                .map(

                  (e) => Padding(

                    padding: const EdgeInsets.only(bottom: 8),

                    child: Text(

                      e,

                      style: const TextStyle(

                        color: Colors.white,

                        fontSize: 14,

                      ),

                    ),

                  ),

                )

                .toList(),

          ),

        );

      },

    );

  }

  Widget buildCurrentTab() {

    final title = tabs[selectedTab]['title']!;

    switch (title) {

      case 'Продажи':

        return buildSalesView();

      case 'Вложения':

        return buildInvestmentsView();

      case 'Сводка':

        return buildSummaryView();

      case 'План':

        return buildPlanView();

      case 'Распределение':

        return buildDistributionView();

      default:

        return buildFallbackView();

    }

  }

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFF0B1220),

      appBar: AppBar(

        backgroundColor: const Color(0xFF0B1220),

        elevation: 0,

        title: const Text(

          'Аналитика',

          style: TextStyle(

            color: Colors.white,

            fontWeight: FontWeight.w800,

          ),

        ),

        iconTheme: const IconThemeData(color: Colors.white),

      ),

      body: Column(

        children: [

          SizedBox(

            height: 60,

            child: Padding(

              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),

              child: ListView.builder(

                scrollDirection: Axis.horizontal,

                itemCount: tabs.length,

                itemBuilder: (context, index) => buildTabButton(index),

              ),

            ),

          ),

          Expanded(

            child: isLoading

                ? const Center(

                    child: CircularProgressIndicator(

                      color: Color(0xFF23C4FF),

                    ),

                  )

                : errorText.isNotEmpty

                    ? Center(

                        child: Padding(

                          padding: const EdgeInsets.all(20),

                          child: Text(

                            errorText,

                            textAlign: TextAlign.center,

                            style: const TextStyle(color: Colors.white),

                          ),

                        ),

                      )

                    : buildCurrentTab(),

          ),

        ],

      ),

    );

  }

}
