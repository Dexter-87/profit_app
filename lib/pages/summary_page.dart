import 'package:flutter/material.dart';
import 'package:my_app/services/api_service.dart';
import 'package:my_app/theme/app_colors.dart';
import 'package:my_app/widgets/app_ui.dart';

class SummaryPage extends StatefulWidget {
  const SummaryPage({super.key});

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  bool _loading = true;
  String _error = '';

  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic> _analytics = {};

  String _selectedModel = 'Текущая';

  String _period = '30 дней';
  DateTime? _dateFrom;
  DateTime? _dateTo;

  final TextEditingController stasCapitalCtrl = TextEditingController();
  final TextEditingController alexCapitalCtrl = TextEditingController();
  final TextEditingController stasWorkCtrl = TextEditingController();
  final TextEditingController alexWorkCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _setLastDays(30, load: false);
    _loadModel();
  }

  @override
  void dispose() {
    stasCapitalCtrl.dispose();
    alexCapitalCtrl.dispose();
    stasWorkCtrl.dispose();
    alexWorkCtrl.dispose();
    super.dispose();
  }

  String _apiDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _uiDate(DateTime? date) {
    if (date == null) return 'Не выбрано';
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  String _periodText() {
    if (_dateFrom == null && _dateTo == null) return 'Весь период';
    return '${_uiDate(_dateFrom)} — ${_uiDate(_dateTo)}';
  }

  Future<void> _loadModel() async {
    try {
      setState(() {
        _loading = true;
        _error = '';
      });

      final distribution = await ApiService.fetchDistribution();

      final analytics = await ApiService.fetchAnalytics(
        dateFrom: _dateFrom == null ? null : _apiDate(_dateFrom!),
        dateTo: _dateTo == null ? null : _apiDate(_dateTo!),
      );

      setState(() {
        _rows = distribution;
        _analytics = analytics;

        stasCapitalCtrl.text = _cleanInput(_value('Вложения', 'stas'));
        alexCapitalCtrl.text = _cleanInput(_value('Вложения', 'alexey'));
        stasWorkCtrl.text = _cleanInput(_value('Баллы за работу', 'stas'));
        alexWorkCtrl.text = _cleanInput(_value('Баллы за работу', 'alexey'));

        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _setToday({bool load = true}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    setState(() {
      _period = 'Сегодня';
      _dateFrom = today;
      _dateTo = today;
    });

    if (load) _loadModel();
  }

  void _setLastDays(int days, {bool load = true}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    setState(() {
      _period = '$days дней';
      _dateFrom = today.subtract(Duration(days: days - 1));
      _dateTo = today;
    });

    if (load) _loadModel();
  }

  void _setAll({bool load = true}) {
    setState(() {
      _period = 'Все';
      _dateFrom = null;
      _dateTo = null;
    });

    if (load) _loadModel();
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

    _loadModel();
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

    _loadModel();
  }

  String _cleanInput(dynamic value) {
    final n = _toDouble(value);
    if (n % 1 == 0) return n.toStringAsFixed(0);
    return n.toString();
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
    return '${_toDouble(value).toStringAsFixed(2)}%';
  }

  dynamic _value(String metric, String column) {
    final row = _rows.firstWhere(
          (r) => (r['metric'] ?? '').toString().trim() == metric,
      orElse: () => <String, dynamic>{},
    );
    return row[column] ?? 0;
  }

  double get _netProfit {
    final net = _toDouble(_analytics['netProfit']);
    if (net != 0) return net;
    return _toDouble(_analytics['totalProfit']) -
        _toDouble(_analytics['expenses']);
  }

  Future<void> _saveModel() async {
    try {
      final stasCapital = _toDouble(stasCapitalCtrl.text);
      final alexCapital = _toDouble(alexCapitalCtrl.text);
      final totalCapital = stasCapital + alexCapital;

      final stasWork = _toDouble(stasWorkCtrl.text);
      final alexWork = _toDouble(alexWorkCtrl.text);
      final totalWork = stasWork + alexWork;

      final stasCapitalShare =
      totalCapital == 0 ? 0 : (stasCapital / totalCapital) * 100;
      final alexCapitalShare =
      totalCapital == 0 ? 0 : (alexCapital / totalCapital) * 100;

      final stasWorkShare = totalWork == 0 ? 0 : (stasWork / totalWork) * 100;
      final alexWorkShare = totalWork == 0 ? 0 : (alexWork / totalWork) * 100;

      final capitalWeight = _toDouble(_value('Вес вложений', 'total')) == 0
          ? 50
          : _toDouble(_value('Вес вложений', 'total'));

      final workWeight = _toDouble(_value('Вес работы', 'total')) == 0
          ? 50
          : _toDouble(_value('Вес работы', 'total'));

      final stasFinal =
          (stasCapitalShare * capitalWeight / 100) +
              (stasWorkShare * workWeight / 100);

      final alexFinal =
          (alexCapitalShare * capitalWeight / 100) +
              (alexWorkShare * workWeight / 100);

      final rows = [
        {
          'metric': 'Вложения',
          'stas': stasCapital,
          'alexey': alexCapital,
          'total': totalCapital,
          'model': '',
        },
        {
          'metric': 'Доля вложений',
          'stas': stasCapitalShare,
          'alexey': alexCapitalShare,
          'total': 100,
          'model': '',
        },
        {
          'metric': 'Баллы за работу',
          'stas': stasWork,
          'alexey': alexWork,
          'total': totalWork,
          'model': '',
        },
        {
          'metric': 'Доля работы',
          'stas': stasWorkShare,
          'alexey': alexWorkShare,
          'total': 100,
          'model': '',
        },
        {
          'metric': 'Вес вложений',
          'stas': '',
          'alexey': '',
          'total': capitalWeight,
          'model': '',
        },
        {
          'metric': 'Вес работы',
          'stas': '',
          'alexey': '',
          'total': workWeight,
          'model': '',
        },
        {
          'metric': 'Итоговая доля',
          'stas': stasFinal,
          'alexey': alexFinal,
          'total': 100,
          'model': '',
        },
      ];

      await ApiService.saveDistribution(rows);
      await _loadModel();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Модель сохранена')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Widget _input(String label, TextEditingController controller) {
    return Expanded(
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(
          color: AppColors.textMain,
          fontWeight: FontWeight.w800,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          filled: true,
          fillColor: AppColors.bg,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.stroke),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF22C55E), width: 1.5),
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
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _periodButton(String title, VoidCallback onTap) {
    final selected = _period == title;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF22C55E).withOpacity(0.22)
                : AppColors.bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? const Color(0xFF22C55E).withOpacity(0.55)
                  : AppColors.stroke,
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              color: selected ? AppColors.textMain : AppColors.textSecondary,
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
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
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

  Widget _periodCard() {
    return AppUi.sectionCard(
      title: 'Период модели',
      icon: Icons.date_range_outlined,
      accent: const Color(0xFF22C55E),
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

  @override
  Widget build(BuildContext context) {
    final stasInvest = _toDouble(_value('Вложения', 'stas'));
    final alexInvest = _toDouble(_value('Вложения', 'alexey'));
    final totalInvest = _toDouble(_value('Вложения', 'total'));

    final stasCapitalShare = _toDouble(_value('Доля вложений', 'stas'));
    final alexCapitalShare = _toDouble(_value('Доля вложений', 'alexey'));

    final stasWorkPoints = _toDouble(_value('Баллы за работу', 'stas'));
    final alexWorkPoints = _toDouble(_value('Баллы за работу', 'alexey'));

    final stasWorkShare = _toDouble(_value('Доля работы', 'stas'));
    final alexWorkShare = _toDouble(_value('Доля работы', 'alexey'));

    final capitalWeight = _toDouble(_value('Вес вложений', 'total'));
    final workWeight = _toDouble(_value('Вес работы', 'total'));

    final stasFinalShare = _toDouble(_value('Итоговая доля', 'stas'));
    final alexFinalShare = _toDouble(_value('Итоговая доля', 'alexey'));

    final myNet = _toDouble(_analytics['myNet']);
    final alexNet = _toDouble(_analytics['alexNet']);

    final capitalWorkStas = _netProfit * (stasFinalShare / 100);
    final capitalWorkAlex = _netProfit * (alexFinalShare / 100);

    double resultStas;
    double resultAlex;
    double resultStasShare;
    double resultAlexShare;
    String note;

    if (_selectedModel == 'Текущая') {
      resultStas = myNet;
      resultAlex = alexNet;
      final total = resultStas + resultAlex;
      resultStasShare = total == 0 ? 0 : (resultStas / total) * 100;
      resultAlexShare = total == 0 ? 0 : (resultAlex / total) * 100;
      note =
      'Текущая: Ariston и продажи с плюсом делятся 50/50, остальные продажи уходят Алексею. Расходы делятся пополам.';
    } else {
      resultStas = capitalWorkStas;
      resultAlex = capitalWorkAlex;
      resultStasShare = stasFinalShare;
      resultAlexShare = alexFinalShare;
      note =
      'Капитал + работа: чистая прибыль распределяется по итоговой доле из весов капитала и работы.';
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text(
          'Модель',
          style: TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadModel,
            icon: const Icon(Icons.refresh, color: AppColors.textMain),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
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
                      'Модель распределения',
                      style: TextStyle(
                        color: AppColors.textMain,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Здесь задаются вложения, работа, период и сценарий распределения прибыли.',
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

              _periodCard(),

              const SizedBox(height: 16),

              AppUi.sectionCard(
                title: 'Редактирование',
                icon: Icons.edit_outlined,
                accent: const Color(0xFF22C55E),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _input('Стас вложения', stasCapitalCtrl),
                        const SizedBox(width: 10),
                        _input('Алексей вложения', alexCapitalCtrl),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _input('Стас работа', stasWorkCtrl),
                        const SizedBox(width: 10),
                        _input('Алексей работа', alexWorkCtrl),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveModel,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          backgroundColor: const Color(0xFF22C55E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'СОХРАНИТЬ МОДЕЛЬ',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
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
                    _modelButton('Текущая'),
                    const SizedBox(width: 8),
                    _modelButton('Капитал + работа'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              AppUi.sectionCard(
                title: 'Распределение по модели',
                icon: Icons.account_tree_outlined,
                accent: const Color(0xFF4DA3FF),
                child: Column(
                  children: [
                    _line('Период', _periodText()),
                    const Divider(color: AppColors.stroke, height: 24),
                    _line('Стас', _formatMoney(resultStas), bold: true),
                    _line(
                        'Алексей', _formatMoney(resultAlex),
                        bold: true),
                    _line('Доля Стаса',
                        _formatPercent(resultStasShare)),
                    _line('Доля Алексея',
                        _formatPercent(resultAlexShare)),
                    _line(
                      'Общая чистая прибыль',
                      _formatMoney(_netProfit),
                      bold: true,
                    ),
                    const Divider(color: AppColors.stroke, height: 24),
                    Text(
                      note,
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
                title: 'Параметры модели',
                icon: Icons.tune_rounded,
                accent: const Color(0xFF8B5CF6),
                child: Column(
                  children: [
                    _line('Вложения Стас', _formatMoney(stasInvest)),
                    _line('Вложения Алексей',
                        _formatMoney(alexInvest)),
                    _line('Всего вложений', _formatMoney(totalInvest)),
                    const Divider(color: AppColors.stroke, height: 24),
                    _line('Доля вложений Стас',
                        _formatPercent(stasCapitalShare)),
                    _line('Доля вложений Алексей',
                        _formatPercent(alexCapitalShare)),
                    _line('Баллы работы Стас',
                        stasWorkPoints.toStringAsFixed(0)),
                    _line('Баллы работы Алексей',
                        alexWorkPoints.toStringAsFixed(0)),
                    _line('Доля работы Стас',
                        _formatPercent(stasWorkShare)),
                    _line('Доля работы Алексей',
                        _formatPercent(alexWorkShare)),
                    const Divider(color: AppColors.stroke, height: 24),
                    _line('Вес капитала',
                        _formatPercent(capitalWeight)),
                    _line('Вес работы', _formatPercent(workWeight)),
                    _line('Итоговая доля Стас',
                        _formatPercent(stasFinalShare)),
                    _line('Итоговая доля Алексей',
                        _formatPercent(alexFinalShare)),
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
