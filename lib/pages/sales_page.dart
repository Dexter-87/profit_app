import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:my_app/theme/app_colors.dart';
import 'package:my_app/widgets/app_ui.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  bool _loading = true;
  String _error = '';

  List<Map<String, dynamic>> _allSales = [];
  List<Map<String, dynamic>> _filteredSales = [];

  final TextEditingController _searchController = TextEditingController();

  String _selectedChannel = 'Все';
  String _selectedPeriod = '30 дней';
  DateTime? _dateFrom;
  DateTime? _dateTo;

  final Set<int> _deletingRows = {};

  @override
  void initState() {
    super.initState();
    _loadSales();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSales() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final sales = await ApiService.fetchSales();

      setState(() {
        _allSales = sales;
      });

      _applyPresetPeriod(_selectedPeriod, refresh: false);
      _applyFilters();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _deleteSale(Map<String, dynamic> row) async {
    final rowIndexRaw = row['__index'];
    final rowIndex = rowIndexRaw is int
        ? rowIndexRaw
        : int.tryParse(rowIndexRaw.toString()) ?? 0;

    if (rowIndex <= 0) {
      _showMessage('Не найден номер строки для удаления');
      return;
    }

    final product = (row['Наименование'] ?? row['Товар'] ?? 'Без названия').toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text(
            'Удалить продажу?',
            style: TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            product,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
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
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _deletingRows.add(rowIndex);
    });

    try {
      await ApiService.deleteSale(rowIndex);
      _showMessage('Продажа удалена');
      await _loadSales();
    } catch (e) {
      _showMessage('Ошибка удаления: $e');
    } finally {
      if (mounted) {
        setState(() {
          _deletingRows.remove(rowIndex);
        });
      }
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;

    var value = raw.toString().trim();
    if (value.isEmpty) return null;

    value = value.replaceAll("'", '').trim();

    try {
      // Google Sheets serial date: например 46146
      final serial = double.tryParse(value.replaceAll(',', '.'));
      if (serial != null && serial > 30000 && serial < 60000) {
        final baseDate = DateTime(1899, 12, 30);
        return baseDate.add(Duration(days: serial.floor()));
      }

      // dd.mm.yyyy
      if (value.contains('.')) {
        final parts = value.split('.');
        if (parts.length == 3) {
          final day = int.tryParse(parts[0]) ?? 1;
          final month = int.tryParse(parts[1]) ?? 1;
          final year = int.tryParse(parts[2]) ?? 2000;
          return DateTime(year, month, day);
        }
      }

      // yyyy-mm-dd
      if (value.contains('-')) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }

      // yyyy/mm/dd или mm/dd/yyyy
      if (value.contains('/')) {
        final parts = value.split('/');
        if (parts.length == 3) {
          if (parts[0].length == 4) {
            final year = int.tryParse(parts[0]) ?? 2000;
            final month = int.tryParse(parts[1]) ?? 1;
            final day = int.tryParse(parts[2]) ?? 1;
            return DateTime(year, month, day);
          } else {
            final month = int.tryParse(parts[0]) ?? 1;
            final day = int.tryParse(parts[1]) ?? 1;
            final year = int.tryParse(parts[2]) ?? 2000;
            return DateTime(year, month, day);
          }
        }
      }

      return DateTime.tryParse(value);
    } catch (_) {
      return null;
    }
  }


  double _toDouble(dynamic value) {
    if (value == null) return 0;
    final cleaned = value
        .toString()
        .replaceAll('₸', '')
        .replaceAll(' ', '')
        .replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0;
  }

  String _detectChannel(Map<String, dynamic> row) {
    final channel = (row['Канал'] ?? '').toString().trim();
    if (channel.isNotEmpty) return channel;

    final orderNumber = (row['Номер заказа'] ?? '').toString().trim();
    final kaspiMarker = _toDouble(row['Каспий_маркер']);
    final commission = _toDouble(row['Комиссия Kaspi']);

    if (commission > 0 || orderNumber.isNotEmpty || kaspiMarker > 0) {
      return 'Каспий';
    }

    return 'ОПТ';
  }

  double _profit(Map<String, dynamic> row) {
    final profitFromSheet = _toDouble(row['Чистая прибыль']);
    if (profitFromSheet != 0) return profitFromSheet;

    final rrc = _toDouble(row['РРЦ']);
    final cost = _toDouble(row['Себестоимость']);
    final commission = _toDouble(row['Комиссия Kaspi']);
    return rrc - cost - commission;
  }

  void _applyPresetPeriod(String period, {bool refresh = true}) {
    final now = DateTime.now();

    if (period == 'Сегодня') {
      _dateFrom = DateTime(now.year, now.month, now.day);
      _dateTo = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (period == '7 дней') {
      _dateFrom =
          DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      _dateTo = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (period == '30 дней') {
      _dateFrom =
          DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
      _dateTo = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else {
      _dateFrom = null;
      _dateTo = null;
    }

    if (refresh) {
      _applyFilters();
    }
  }

  void _applyFilters() {
    final search = _searchController.text.toLowerCase().trim();

    final filtered = _allSales.where((row) {
      final date = _parseDate(row['Дата']);
      final channel = _detectChannel(row);
      final product = (row['Наименование'] ?? row['Товар'] ?? '').toString();
      final brand = (row['Бренд'] ?? '').toString();
      final order = (row['Номер заказа'] ?? '').toString();
      final client = (row['Клиент'] ?? '').toString();

      if (_selectedChannel != 'Все' && channel != _selectedChannel) {
        return false;
      }

      if (_dateFrom != null) {
        if (date == null) return false;
        final from = DateTime(_dateFrom!.year, _dateFrom!.month, _dateFrom!.day);
        final current = DateTime(date.year, date.month, date.day);
        if (current.isBefore(from)) return false;
      }

      if (_dateTo != null) {
        if (date == null) return false;
        final to = DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day);
        final current = DateTime(date.year, date.month, date.day);
        if (current.isAfter(to)) return false;
      }

      if (search.isNotEmpty) {
        final haystack = '$product $brand $order $channel $client'.toLowerCase();
        if (!haystack.contains(search)) return false;
      }

      return true;
    }).toList();

    filtered.sort((a, b) {
      final da = _parseDate(a['Дата']) ?? DateTime(2000);
      final db = _parseDate(b['Дата']) ?? DateTime(2000);
      return db.compareTo(da);
    });

    setState(() {
      _filteredSales = filtered;
    });
  }

  String _formatMoney(double value) {
    final rounded = value.round().toString();
    final isNegative = rounded.startsWith('-');
    final cleanNumber = rounded.replaceAll('-', '');

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
    return '${isNegative ? '-' : ''}$result';
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final initialDate = isFrom ? (_dateFrom ?? now) : (_dateTo ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          _dateFrom = picked;
          _selectedPeriod = 'Свои даты';
        } else {
          _dateTo = picked;
          _selectedPeriod = 'Свои даты';
        }
      });
      _applyFilters();
    }
  }

  Widget _buildSaleCard(Map<String, dynamic> row) {
    final product =
    (row['Наименование'] ??
        row['Товар'] ??
        row['productName'] ??
        row['product'] ??
        row['name'] ??
        '')
        .toString()
        .trim();
    final displayProduct = product.isEmpty ? 'Без названия' : product;
    final brand = (row['Бренд'] ?? '').toString();
    final client = (row['Клиент'] ?? '').toString();
    final date = (row['Дата'] ?? '').toString();
    final channel = _detectChannel(row);
    final order = (row['Номер заказа'] ?? '').toString();
    final rrc = _toDouble(row['РРЦ']);
    final cost = _toDouble(row['Себестоимость']);
    final commission = _toDouble(row['Комиссия Kaspi']);
    final profit = _profit(row);

    final rowIndexRaw = row['__index'];
    final rowIndex = rowIndexRaw is int
        ? rowIndexRaw
        : int.tryParse(rowIndexRaw.toString()) ?? 0;

    final isDeleting = _deletingRows.contains(rowIndex);

    final accent = channel == 'Каспий'
        ? const Color(0xFF4DA3FF)
        : const Color(0xFF22C55E);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppUi.cardDecoration(
        radius: 24,
        borderColor: accent.withOpacity(0.22),
        shadows: [
          BoxShadow(
            color: accent.withOpacity(0.10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppUi.iconBadge(
                  icon: channel == 'Каспий'
                      ? Icons.shopping_bag_outlined
                      : Icons.local_shipping_outlined,
                  accent: accent,
                  size: 42,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayProduct,
                        style: const TextStyle(
                          color: AppColors.textMain,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (brand.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          brand,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (client.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Клиент: $client',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                isDeleting
                    ? const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.danger,
                  ),
                )
                    : IconButton(
                  onPressed: () => _deleteSale(row),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppUi.chip(date.isEmpty ? 'Без даты' : date, accent: accent),
                AppUi.chip(channel, accent: accent),
                if (order.isNotEmpty) AppUi.chip('Заказ: $order', accent: accent),
              ],
            ),
            const SizedBox(height: 14),
            AppUi.infoRow('РРЦ', '${_formatMoney(rrc)} ₸'),
            AppUi.infoRow('Себестоимость', '${_formatMoney(cost)} ₸'),
            AppUi.infoRow('Комиссия', '${_formatMoney(commission)} ₸'),
            const Divider(color: AppColors.stroke, height: 22),
            AppUi.infoRow(
              'Прибыль',
              '${_formatMoney(profit)} ₸',
              valueColor: profit >= 0 ? AppColors.success : AppColors.danger,
              bold: true,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalRevenue =
    _filteredSales.fold<double>(0, (sum, row) => sum + _toDouble(row['РРЦ']));
    final totalProfit =
    _filteredSales.fold<double>(0, (sum, row) => sum + _profit(row));

    final kaspiCount =
        _filteredSales.where((row) => _detectChannel(row) == 'Каспий').length;
    final optCount =
        _filteredSales.where((row) => _detectChannel(row) == 'ОПТ').length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text(
          'Продажи',
          style: TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadSales,
            icon: const Icon(Icons.refresh, color: AppColors.textMain),
          ),
        ],
      ),
      body: _loading
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
        onRefresh: _loadSales,
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
                    borderColor: AppColors.primary.withOpacity(0.22),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.02),
                        AppColors.primary.withOpacity(0.07),
                      ],
                    ),
                    shadows: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Список продаж',
                        style: TextStyle(
                          color: AppColors.textMain,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Поиск, фильтры, каналы и прибыль по каждой продаже.',
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
                Row(
                  children: [
                    Expanded(
                      child: AppUi.metricCard(
                        icon: Icons.shopping_bag_outlined,
                        title: 'Продаж',
                        value: _filteredSales.length.toString(),
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
                        icon: Icons.trending_up,
                        title: 'Прибыль',
                        value: '${_formatMoney(totalProfit)} ₸',
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
                AppUi.metricCard(
                  icon: Icons.payments_outlined,
                  title: 'Выручка',
                  value: '${_formatMoney(totalRevenue)} ₸',
                  accentColors: const [
                    Color(0xFF8B5CF6),
                    Color(0xFF6D28D9),
                  ],
                  compact: true,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppUi.metricCard(
                        icon: Icons.storefront_outlined,
                        title: 'Каспий',
                        value: kaspiCount.toString(),
                        accentColors: const [
                          Color(0xFF06B6D4),
                          Color(0xFF0891B2),
                        ],
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppUi.metricCard(
                        icon: Icons.local_shipping_outlined,
                        title: 'ОПТ',
                        value: optCount.toString(),
                        accentColors: const [
                          Color(0xFFF59E0B),
                          Color(0xFFD97706),
                        ],
                        compact: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  decoration: AppUi.cardDecoration(radius: 22),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          style: const TextStyle(
                            color: AppColors.textMain,
                          ),
                          decoration: InputDecoration(
                            hintText:
                            'Поиск по товару / заказу / клиенту / каналу',
                            hintStyle: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: AppColors.textSecondary,
                            ),
                            filled: true,
                            fillColor: AppColors.bg,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(
                                color: AppColors.stroke,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              AppUi.periodButton(
                                title: 'Сегодня',
                                selected:
                                _selectedPeriod == 'Сегодня',
                                onTap: () {
                                  setState(() {
                                    _selectedPeriod = 'Сегодня';
                                    _applyPresetPeriod(
                                      'Сегодня',
                                      refresh: false,
                                    );
                                  });
                                  _applyFilters();
                                },
                              ),
                              const SizedBox(width: 8),
                              AppUi.periodButton(
                                title: '7 дней',
                                selected: _selectedPeriod == '7 дней',
                                onTap: () {
                                  setState(() {
                                    _selectedPeriod = '7 дней';
                                    _applyPresetPeriod(
                                      '7 дней',
                                      refresh: false,
                                    );
                                  });
                                  _applyFilters();
                                },
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
                                onTap: () {
                                  setState(() {
                                    _selectedPeriod = '30 дней';
                                    _applyPresetPeriod(
                                      '30 дней',
                                      refresh: false,
                                    );
                                  });
                                  _applyFilters();
                                },
                                accentColors: const [
                                  Color(0xFF22C55E),
                                  Color(0xFF16A34A),
                                ],
                              ),
                              const SizedBox(width: 8),
                              AppUi.periodButton(
                                title: 'Всё',
                                selected: _selectedPeriod == 'Всё',
                                onTap: () {
                                  setState(() {
                                    _selectedPeriod = 'Всё';
                                    _applyPresetPeriod(
                                      'Всё',
                                      refresh: false,
                                    );
                                  });
                                  _applyFilters();
                                },
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
                                  value: _dateFrom == null
                                      ? 'Не выбрано'
                                      : '${_dateFrom!.day.toString().padLeft(2, '0')}.${_dateFrom!.month.toString().padLeft(2, '0')}.${_dateFrom!.year}',
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
                                  value: _dateTo == null
                                      ? 'Не выбрано'
                                      : '${_dateTo!.day.toString().padLeft(2, '0')}.${_dateTo!.month.toString().padLeft(2, '0')}.${_dateTo!.year}',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedChannel,
                          dropdownColor: AppColors.card,
                          style: const TextStyle(
                            color: AppColors.textMain,
                          ),
                          iconEnabledColor: AppColors.textSecondary,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.bg,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(
                                color: AppColors.stroke,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Все',
                              child: Text('Все'),
                            ),
                            DropdownMenuItem(
                              value: 'Каспий',
                              child: Text('Каспий'),
                            ),
                            DropdownMenuItem(
                              value: 'ОПТ',
                              child: Text('ОПТ'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedChannel = value ?? 'Все';
                            });
                            _applyFilters();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (_filteredSales.isEmpty)
                  AppUi.emptyBlock('По выбранным фильтрам продаж нет')
                else
                  ..._filteredSales.map(_buildSaleCard),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
