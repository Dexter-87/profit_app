import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:my_app/services/api_service.dart';
import 'package:my_app/theme/app_colors.dart';
import 'package:my_app/widgets/app_ui.dart';
import 'package:my_app/widgets/gradient_button.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  static const String baseUrl = 'http://localhost:8080';

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  String _selectedType = 'Стас';
  bool _isSaving = false;

  String _selectedPeriod = '30 дней';
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _applyPresetPeriod('30 дней', load: false);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  double _toDouble(String value) {
    return double.tryParse(
      value
          .replaceAll('₸', '')
          .replaceAll(' ', '')
          .replaceAll(',', '.')
          .trim(),
    ) ??
        0;
  }

  String _formatApiDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDisplayDate(DateTime? date) {
    if (date == null) return 'Не выбрано';

    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
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
    }
  }

  void _downloadPdfReport() {
    final from = _formatApiDate(_dateFrom);
    final to = _formatApiDate(_dateTo);

    final url = '$baseUrl/expenses-report/pdf?dateFrom=$from&dateTo=$to';

    html.window.open(url, '_blank');
  }

  Future<void> _saveExpense() async {
    final amount = _toDouble(_amountController.text);
    final comment = _commentController.text.trim();

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите сумму расхода')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ApiService.addExpense(
        amount: amount,
        owner: _selectedType,
        type: _selectedType,
        comment: comment,
      );

      _amountController.clear();
      _commentController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Расход сохранён')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  List<Color> get _accentColors {
    switch (_selectedType) {
      case 'Алексей':
        return const [Color(0xFFF59E0B), Color(0xFFD97706)];
      case 'Стас':
        return const [Color(0xFF4DA3FF), Color(0xFF2D7DFF)];
      case 'Общий 50/50':
        return const [Color(0xFF8B5CF6), Color(0xFF6D28D9)];
      case 'Общий по модели':
        return const [Color(0xFF22C55E), Color(0xFF16A34A)];
      default:
        return const [Color(0xFF4DA3FF), Color(0xFF2D7DFF)];
    }
  }

  Widget _choice(String title) {
    final selected = _selectedType == title;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          setState(() {
            _selectedType = title;
          });
        },
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected ? LinearGradient(colors: _accentColors) : null,
            color: selected ? null : AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? Colors.transparent : AppColors.stroke,
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textMain,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: AppUi.cardDecoration(
        color: AppColors.bg,
        radius: 20,
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(
          color: AppColors.textMain,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textSecondary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  String get _hint {
    switch (_selectedType) {
      case 'Стас':
        return 'Расход уйдет только в Стаса';
      case 'Алексей':
        return 'Расход уйдет только в Алексея';
      case 'Общий 50/50':
        return 'Расход делится 50/50';
      case 'Общий по модели':
        return 'Расход делится по долям модели';
      default:
        return '';
    }
  }

  Widget _periodBlock() {
    return Container(
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
                    selected: _selectedPeriod == 'Сегодня',
                    onTap: () => _applyPresetPeriod('Сегодня'),
                  ),
                  const SizedBox(width: 8),
                  AppUi.periodButton(
                    title: '7 дней',
                    selected: _selectedPeriod == '7 дней',
                    onTap: () => _applyPresetPeriod('7 дней'),
                  ),
                  const SizedBox(width: 8),
                  AppUi.periodButton(
                    title: '30 дней',
                    selected: _selectedPeriod == '30 дней',
                    onTap: () => _applyPresetPeriod('30 дней'),
                  ),
                  const SizedBox(width: 8),
                  AppUi.periodButton(
                    title: 'Всё',
                    selected: _selectedPeriod == 'Всё',
                    onTap: () => _applyPresetPeriod('Всё'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _pickDate(isFrom: true),
                    child: AppUi.dateBox(
                      title: 'С',
                      value: _formatDisplayDate(_dateFrom),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _pickDate(isFrom: false),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text(
          'Расходы',
          style: TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppUi.cardDecoration(
                    radius: 28,
                    borderColor: _accentColors.first.withOpacity(0.25),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Добавить расход',
                        style: TextStyle(
                          color: AppColors.textMain,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Выбери тип расхода, добавь сумму и сформируй PDF-отчёт за период.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                AppUi.sectionCard(
                  title: 'Период отчёта',
                  icon: Icons.calendar_month_outlined,
                  accent: const Color(0xFF06B6D4),
                  child: _periodBlock(),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: GradientButton(
                    text: 'PDF ОТЧЁТ ПО РАСХОДАМ',
                    icon: Icons.picture_as_pdf_outlined,
                    onTap: _downloadPdfReport,
                  ),
                ),

                const SizedBox(height: 16),

                AppUi.sectionCard(
                  title: 'Тип расхода',
                  icon: Icons.tune,
                  accent: _accentColors.first,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _choice('Стас'),
                          const SizedBox(width: 8),
                          _choice('Алексей'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _choice('Общий 50/50'),
                          const SizedBox(width: 8),
                          _choice('Общий по модели'),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                AppUi.sectionCard(
                  title: 'Сумма',
                  icon: Icons.payments_outlined,
                  accent: _accentColors.first,
                  child: _input(
                    controller: _amountController,
                    hint: 'Введите сумму',
                    keyboardType: TextInputType.number,
                  ),
                ),

                const SizedBox(height: 16),

                AppUi.sectionCard(
                  title: 'Комментарий',
                  icon: Icons.notes,
                  accent: _accentColors.first,
                  child: _input(
                    controller: _commentController,
                    hint: 'Например: доставка, реклама',
                  ),
                ),

                const SizedBox(height: 16),

                AppUi.sectionCard(
                  title: 'Как будет считаться',
                  icon: Icons.info_outline,
                  accent: _accentColors.first,
                  child: Text(
                    _hint,
                    style: const TextStyle(
                      color: AppColors.textMain,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: GradientButton(
                    text: _isSaving ? 'СОХРАНЯЮ...' : 'СОХРАНИТЬ РАСХОД',
                    icon: Icons.save,
                    onTap: () {
                      if (_isSaving) return;
                      _saveExpense();
                    },
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
