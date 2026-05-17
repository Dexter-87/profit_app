import 'package:flutter/material.dart';
import 'package:my_app/services/api_service.dart';
import 'package:my_app/theme/app_colors.dart';
import 'package:my_app/widgets/app_ui.dart';

class SideIncomePage extends StatefulWidget {
  const SideIncomePage({super.key});

  @override
  State<SideIncomePage> createState() => _SideIncomePageState();
}

class _SideIncomePageState extends State<SideIncomePage> {
  bool _loading = true;
  String _error = '';

  List<Map<String, dynamic>> _items = [];

  final TextEditingController _typeCtrl = TextEditingController();
  final TextEditingController _descriptionCtrl = TextEditingController();
  final TextEditingController _incomeCtrl = TextEditingController();
  final TextEditingController _expenseCtrl = TextEditingController();
  final TextEditingController _commentCtrl = TextEditingController();

  String _paidBy = 'Стас';

  int? _editingRowIndex;
  String _editingDate = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _typeCtrl.dispose();
    _descriptionCtrl.dispose();
    _incomeCtrl.dispose();
    _expenseCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();

    return double.tryParse(
      value
          .toString()
          .replaceAll('₸', '')
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

  String _money(dynamic value) {
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

  String _todayRu() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}.'
        '${now.month.toString().padLeft(2, '0')}.'
        '${now.year}';
  }

  double _cleanProfit() {
    return _toDouble(_incomeCtrl.text) - _toDouble(_expenseCtrl.text);
  }

  double _refundStas() {
    final expense = _toDouble(_expenseCtrl.text);
    if (_paidBy == 'Стас') return expense;
    if (_paidBy == 'Общий') return expense / 2;
    return 0;
  }

  double _refundAlexey() {
    final expense = _toDouble(_expenseCtrl.text);
    if (_paidBy == 'Алексей') return expense;
    if (_paidBy == 'Общий') return expense / 2;
    return 0;
  }

  double _totalStas() {
    return _cleanProfit() / 2 + _refundStas();
  }

  double _totalAlexey() {
    return _cleanProfit() / 2 + _refundAlexey();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final data = await ApiService.getSideIncome();

      final rows = data.map((e) => Map<String, dynamic>.from(e)).where((row) {
        final income = _toDouble(row['Доход']);
        final expense = _toDouble(row['Расход']);
        final description = (row['Описание'] ?? '').toString().trim();
        final type = (row['Тип'] ?? '').toString().trim();

        return income != 0 ||
            expense != 0 ||
            description.isNotEmpty ||
            type.isNotEmpty;
      }).toList();

      setState(() {
        _items = rows;
      });
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки доп. доходов';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _clearForm() {
    _typeCtrl.clear();
    _descriptionCtrl.clear();
    _incomeCtrl.clear();
    _expenseCtrl.clear();
    _commentCtrl.clear();

    setState(() {
      _paidBy = 'Стас';
      _editingRowIndex = null;
      _editingDate = '';
    });
  }

  void _startEdit(Map<String, dynamic> item) {
    setState(() {
      _editingRowIndex = _toInt(item['rowIndex']);
      _editingDate = item['Дата']?.toString() ?? _todayRu();

      _typeCtrl.text = item['Тип']?.toString() ?? '';
      _descriptionCtrl.text = item['Описание']?.toString() ?? '';
      _incomeCtrl.text = _toDouble(item['Доход']).toStringAsFixed(0);
      _expenseCtrl.text = _toDouble(item['Расход']).toStringAsFixed(0);
      _commentCtrl.text = item['Комментарий']?.toString() ?? '';

      final paidBy = item['Оплатил расход']?.toString().trim() ?? '';
      _paidBy = paidBy.isNotEmpty ? paidBy : 'Стас';
    });
  }

  Future<void> _save() async {
    final income = _toDouble(_incomeCtrl.text);
    final expense = _toDouble(_expenseCtrl.text);

    if (_descriptionCtrl.text.trim().isEmpty && income == 0 && expense == 0) {
      return;
    }

    try {
      if (_editingRowIndex != null) {
        await ApiService.updateSideIncome(
          rowIndex: _editingRowIndex!,
          date: _editingDate.isNotEmpty ? _editingDate : _todayRu(),
          type: _typeCtrl.text.trim(),
          description: _descriptionCtrl.text.trim(),
          income: income,
          expense: expense,
          comment: _commentCtrl.text.trim(),
          paidBy: _paidBy,
        );
      } else {
        await ApiService.addSideIncome(
          date: _todayRu(),
          type: _typeCtrl.text.trim(),
          description: _descriptionCtrl.text.trim(),
          income: income,
          expense: expense,
          comment: _commentCtrl.text.trim(),
          paidBy: _paidBy,
        );
      }

      _clearForm();
      await _load();
    } catch (e) {
      setState(() {
        _error = _editingRowIndex == null
            ? 'Ошибка добавления доп. дохода'
            : 'Ошибка обновления доп. дохода';
      });
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final rowIndex = _toInt(item['rowIndex']);
    if (rowIndex < 2) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1B2230),
          title: const Text(
            'Удалить доп. доход?',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            item['Описание']?.toString() ?? '',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Удалить',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await ApiService.deleteSideIncome(rowIndex: rowIndex);
      await _load();
    } catch (e) {
      setState(() {
        _error = 'Ошибка удаления доп. дохода';
      });
    }
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(color: AppColors.textMain),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: AppColors.bg,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF06B6D4)),
        ),
      ),
    );
  }

  Widget _paidBySelector() {
    final options = ['Стас', 'Алексей', 'Общий'];

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        children: options.map((option) {
          final active = _paidBy == option;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _paidBy = option;
                });
              },
              child: Container(
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFF06B6D4).withOpacity(0.22)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active
                        ? const Color(0xFF06B6D4)
                        : Colors.transparent,
                  ),
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    color: active ? AppColors.textMain : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _actionButton({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required List<Color> colors,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemCard(Map<String, dynamic> item) {
    final profit = _toDouble(item['Чистая прибыль']);

    final paidBy = (item['Оплатил расход'] ??
        item['Кто оплатил'] ??
        item['Оплатил'] ??
        '')
        .toString();

    final refundStas = _toDouble(
      item['Возврат Стас'] ?? item['Возврат Стасу'] ?? 0,
    );

    final refundAlexey = _toDouble(
      item['Возврат Алексей'] ?? item['Возврат Алексею'] ?? 0,
    );

    final totalStas = _toDouble(
      item['Итого Стас'] ?? item['Всего Стас'] ?? 0,
    );

    final totalAlexey = _toDouble(
      item['Итого Алексей'] ?? item['Всего Алексей'] ?? 0,
    );


    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: AppUi.cardDecoration(
        radius: 20,
        borderColor: Colors.white.withOpacity(0.10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item['Описание']?.toString() ?? 'Без описания',
            style: const TextStyle(
              color: AppColors.textMain,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            '${item['Дата'] ?? ''} • ${item['Тип'] ?? ''}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            'Доход: ${_money(item['Доход'])}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),

          Text(
            'Расход: ${_money(item['Расход'])}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),

          Text(
            'Чистая: ${_money(profit)}',
            style: const TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Оплатил расход: ${paidBy.isEmpty ? 'Не указано' : paidBy}',
            style: const TextStyle(
              color: AppColors.textSecondary,
            ),
          ),

          Text(
            'Возврат: Стас ${_money(refundStas)} / Алексей ${_money(refundAlexey)}',
            style: const TextStyle(
              color: AppColors.textSecondary,
            ),
          ),

          Text(
            'Итого: Стас ${_money(totalStas)} / Алексей ${_money(totalAlexey)}',
            style: const TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.w900,
            ),
          ),

          if ((item['Комментарий'] ?? '').toString().trim().isNotEmpty) ...[
            const SizedBox(height: 8),

            Text(
              item['Комментарий'].toString(),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
              ),
            ),
          ],

          const SizedBox(height: 12),

          Row(
            children: [
              _actionButton(
                title: 'Изменить',
                icon: Icons.edit_outlined,
                onTap: () => _startEdit(item),
                colors: const [
                  Color(0xFF4DA3FF),
                  Color(0xFF2D7DFF),
                ],
              ),

              const SizedBox(width: 10),

              _actionButton(
                title: 'Удалить',
                icon: Icons.delete_outline,
                onTap: () => _delete(item),
                colors: const [
                  Color(0xFFEF4444),
                  Color(0xFFDC2626),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    double totalIncome = 0;
    double totalExpense = 0;
    double totalProfit = 0;
    double totalRefundStas = 0;
    double totalRefundAlexey = 0;
    double totalStas = 0;
    double totalAlexey = 0;

    for (final item in _items) {
      final profit = _toDouble(item['Чистая прибыль']);
      final refundStas = _toDouble(item['Возврат Стас']);
      final refundAlexey = _toDouble(item['Возврат Алексей']);

      final itemTotalStas =
      item['Итого Стас'] != null && item['Итого Стас'].toString().isNotEmpty
          ? _toDouble(item['Итого Стас'])
          : profit / 2 + refundStas;

      final itemTotalAlexey = item['Итого Алексей'] != null &&
          item['Итого Алексей'].toString().isNotEmpty
          ? _toDouble(item['Итого Алексей'])
          : profit / 2 + refundAlexey;

      totalIncome += _toDouble(item['Доход']);
      totalExpense += _toDouble(item['Расход']);
      totalProfit += profit;
      totalRefundStas += refundStas;
      totalRefundAlexey += refundAlexey;
      totalStas += itemTotalStas;
      totalAlexey += itemTotalAlexey;
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          elevation: 0,
          title: const Text(
            'Доп. доходы',
            style: TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                children: [
                  AppUi.sectionCard(
                    title: 'Итоги 50/50',
                    icon: Icons.handshake_outlined,
                    accent: const Color(0xFF06B6D4),
                    child: Column(
                      children: [
                        _summaryRow('Доход', _money(totalIncome)),
                        _summaryRow('Расход', _money(totalExpense)),
                        _summaryRow('Чистая прибыль', _money(totalProfit)),
                        _summaryRow('Возврат Стасу', _money(totalRefundStas)),
                        _summaryRow(
                          'Возврат Алексею',
                          _money(totalRefundAlexey),
                        ),
                        _summaryRow('Итого Стас', _money(totalStas)),
                        _summaryRow('Итого Алексей', _money(totalAlexey)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  AppUi.sectionCard(
                    title: _editingRowIndex == null
                        ? 'Добавить доп. доход'
                        : 'Редактировать доп. доход',
                    icon: _editingRowIndex == null
                        ? Icons.add_circle_outline
                        : Icons.edit_outlined,
                    accent: _editingRowIndex == null
                        ? const Color(0xFF22C55E)
                        : const Color(0xFF4DA3FF),
                    child: Column(
                      children: [
                        _field(controller: _typeCtrl, label: 'Тип'),

                        const SizedBox(height: 10),

                        _field(
                          controller: _descriptionCtrl,
                          label: 'Описание',
                        ),

                        const SizedBox(height: 10),

                        _field(
                          controller: _incomeCtrl,
                          label: 'Доход',
                          keyboardType: TextInputType.number,
                        ),

                        const SizedBox(height: 10),

                        _field(
                          controller: _expenseCtrl,
                          label: 'Расход',
                          keyboardType: TextInputType.number,
                        ),

                        const SizedBox(height: 10),

                        _paidBySelector(),

                        const SizedBox(height: 10),

                        _summaryRow(
                          'Чистая прибыль',
                          _money(_cleanProfit()),
                        ),

                        _summaryRow(
                          'Возврат Стасу',
                          _money(_refundStas()),
                        ),

                        _summaryRow(
                          'Возврат Алексею',
                          _money(_refundAlexey()),
                        ),

                        _summaryRow(
                          'Итого Стас',
                          _money(_totalStas()),
                        ),

                        _summaryRow(
                          'Итого Алексей',
                          _money(_totalAlexey()),
                        ),

                        const SizedBox(height: 10),

                        _field(
                          controller: _commentCtrl,
                          label: 'Комментарий',
                        ),

                        const SizedBox(height: 14),

                        Row(
                          children: [
                            _actionButton(
                              title: _editingRowIndex == null
                                  ? 'Добавить'
                                  : 'Сохранить',
                              icon: _editingRowIndex == null
                                  ? Icons.add_rounded
                                  : Icons.save_outlined,
                              onTap: _save,
                              colors: const [
                                Color(0xFF06B6D4),
                                Color(0xFF0891B2),
                              ],
                            ),

                            if (_editingRowIndex != null) ...[
                              const SizedBox(width: 10),

                              _actionButton(
                                title: 'Отмена',
                                icon: Icons.close_rounded,
                                onTap: _clearForm,
                                colors: const [
                                  Color(0xFF64748B),
                                  Color(0xFF475569),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (_loading)
                    const Center(
                      child: CircularProgressIndicator(),
                    )
                  else if (_error.isNotEmpty)
                    Text(
                      _error,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else if (_items.isEmpty)
                    const Text(
                      'Пока нет доп. доходов',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    )
                  else
                    ..._items.map(_itemCard),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    }

    Widget _summaryRow(String label, String value) {
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
              style: const TextStyle(
                color: AppColors.textMain,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
    }
    }