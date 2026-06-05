import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../services/api_service.dart';
import 'package:my_app/theme/app_colors.dart';
import 'package:my_app/widgets/app_ui.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  static const String baseUrl = 'https://profit-app-7u44.onrender.com';

  bool _loading = true;
  String _error = '';

  List<Map<String, dynamic>> _allSales = [];
  List<Map<String, dynamic>> _filteredSales = [];

  final TextEditingController _searchController = TextEditingController();

  String _selectedChannel = 'Все';
  String _selectedPeriod = '30 дней';
  DateTime? _dateFrom;
  DateTime? _dateTo;

  final Set<String> _deletingBatches = {};
  final Set<String> _expandedBatches = {};
  final Set<String> _exportingBatches = {};

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
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _batchId(Map<String, dynamic> row) {
    final raw = (row['batchId'] ??
            row['BatchId'] ??
            row['BATCHID'] ??
            row['Накладная'] ??
            '')
        .toString()
        .trim();

    final client = (row['Клиент'] ?? row['client'] ?? '').toString().trim();

    if (raw.isNotEmpty) {
      return '$raw-$client';
    }

    final rowIndex = (row['__index'] ?? '').toString();
    return 'ROW-$rowIndex';

  bool _isLegacyBatch(String batchId) => batchId.startsWith('ROW-');

  List<List<Map<String, dynamic>>> get _groups {
    final map = LinkedHashMap<String, List<Map<String, dynamic>>>();

    for (final row in _filteredSales) {
      final batch = _batchId(row);
      map.putIfAbsent(batch, () => []);
      map[batch]!.add(row);
    }

    final groups = map.values.toList();

    groups.sort((a, b) {
      final aIndex = a
          .map((x) => int.tryParse((x['__index'] ?? '0').toString()) ?? 0)
          .fold<int>(0, (m, v) => v > m ? v : m);

      final bIndex = b
          .map((x) => int.tryParse((x['__index'] ?? '0').toString()) ?? 0)
          .fold<int>(0, (m, v) => v > m ? v : m);

      return bIndex.compareTo(aIndex);
    });

    return groups;
  }

  Future<void> _deleteBatch(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;

    final batch = _batchId(rows.first);
    final isLegacy = _isLegacyBatch(batch);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          title: Text(
            isLegacy ? 'Удалить продажу?' : 'Удалить накладную целиком?',
            style: const TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            isLegacy
                ? 'Будет удалена 1 строка продажи.'
                : 'Будут удалены все позиции этой накладной: ${rows.length} шт.',
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
      _deletingBatches.add(batch);
    });

    try {
      final indexes = rows
          .map((row) => int.tryParse((row['__index'] ?? '0').toString()) ?? 0)
          .where((index) => index > 0)
          .toList()
        ..sort((a, b) => b.compareTo(a));

      if (isLegacy) {
        for (final rowIndex in indexes) {
          await ApiService.deleteSale(rowIndex);
        }
      } else {
        await ApiService.deleteSaleByBatch(batch);
      }

      _showMessage(isLegacy ? 'Продажа удалена' : 'Накладная удалена');
      await _loadSales();
    } catch (e) {
      _showMessage('Ошибка удаления: $e');
    } finally {
      if (mounted) {
        setState(() {
          _deletingBatches.remove(batch);
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
      final serial = double.tryParse(value.replaceAll(',', '.'));
      if (serial != null && serial > 30000 && serial < 60000) {
        final baseDate = DateTime(1899, 12, 30);
        return baseDate.add(Duration(days: serial.floor()));
      }

      if (value.contains('.')) {
        final parts = value.split('.');
        if (parts.length == 3) {
          final day = int.tryParse(parts[0]) ?? 1;
          final month = int.tryParse(parts[1]) ?? 1;
          final year = int.tryParse(parts[2]) ?? 2000;
          return DateTime(year, month, day);
        }
      }

      if (value.contains('-')) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }

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

  String _productName(Map<String, dynamic> row) {
    final product = (row['Наименование'] ??
            row['Товар'] ??
            row['productName'] ??
            row['product'] ??
            row['name'] ??
            '')
        .toString()
        .trim();

    return product.isEmpty ? 'Без названия' : product;
  }

  String _clientName(List<Map<String, dynamic>> rows) {
    for (final row in rows) {
      final client = (row['Клиент'] ?? row['client'] ?? '').toString().trim();
      if (client.isNotEmpty) return client;
    }

    return '';
  }

  List<Map<String, dynamic>> _invoiceItemsFromRows(
    List<Map<String, dynamic>> rows,
  ) {
    return rows.map((row) {
      return {
        'name': _productName(row),
        'quantity': 1,
        'cost': _toDouble(row['Себестоимость']),
        'price': _toDouble(row['РРЦ']),
        'commission': _toDouble(row['Комиссия Kaspi']),
        'comment': (row['Комментарий'] ?? '').toString(),
        'profit': _profit(row),
        'channel': _detectChannel(row),
        'client': (row['Клиент'] ?? '').toString(),
        'orderNumber': (row['Номер заказа'] ?? '').toString(),
      };
    }).toList();
  }

  Future<void> _saveAndOpenFile({
    required List<int> bytes,
    required String fileName,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');

    await file.writeAsBytes(bytes, flush: true);

    final result = await OpenFilex.open(file.path);

    if (result.type != ResultType.done) {
      _showMessage('Файл сохранён, но не открылся: ${result.message}');
    }
  }

  Future<void> _exportInvoice({
    required List<Map<String, dynamic>> rows,
    required String type,
  }) async {
    if (rows.isEmpty) return;

    final batch = _batchId(rows.first);
    final endpoint = type == 'pdf' ? 'invoice-pdf' : 'invoice-excel';
    final extension = type == 'pdf' ? 'pdf' : 'xlsx';
    final client = _clientName(rows);
    final channel = rows.map(_detectChannel).toSet().join(' / ');
    final items = _invoiceItemsFromRows(rows);

    setState(() {
      _exportingBatches.add('$batch-$type');
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'items': items,
          'client': client,
          'channel': channel,
        }),
      );

      if (response.statusCode == 200) {
        await _saveAndOpenFile(
          bytes: response.bodyBytes,
          fileName:
              'nakladnaya_${DateTime.now().millisecondsSinceEpoch}.$extension',
        );

        _showMessage(type == 'pdf' ? 'PDF готов' : 'Excel готов');
      } else {
        _showMessage('Ошибка файла: ${response.body}');
      }
    } catch (e) {
      _showMessage('Ошибка файла: $e');
    } finally {
      if (mounted) {
        setState(() {
          _exportingBatches.remove('$batch-$type');
        });
      }
    }
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
      final batch = _batchId(row);

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
        final haystack =
            '$product $brand $order $channel $client $batch'.toLowerCase();

        if (!haystack.contains(search)) return false;
      }

      return true;
    }).toList();

    filtered.sort((a, b) {
      final ai = int.tryParse((a['__index'] ?? '0').toString()) ?? 0;
      final bi = int.tryParse((b['__index'] ?? '0').toString()) ?? 0;
      return bi.compareTo(ai);
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

  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 6,
            child: Text(
              'Товар',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Себ.',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'РРЦ',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Приб.',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableRow(Map<String, dynamic> row, int index) {
    final product = _productName(row);
    final channel = _detectChannel(row);
    final cost = _toDouble(row['Себестоимость']);
    final rrc = _toDouble(row['РРЦ']);
    final profit = _profit(row);
    final order = (row['Номер заказа'] ?? '').toString().trim();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.stroke.withOpacity(0.5),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${index + 1}. $product',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$channel${order.isNotEmpty ? " • №$order" : ""}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _formatMoney(cost),
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.textMain,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _formatMoney(rrc),
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.textMain,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _formatMoney(profit),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: profit >= 0 ? AppColors.success : AppColors.danger,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String title, double value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.stroke.withOpacity(0.7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${_formatMoney(value)} ₸',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _exportButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool loading,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: loading ? null : onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withOpacity(0.14),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.28)),
          ),
          child: loading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: color, size: 18),
                    const SizedBox(width: 7),
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildBatchCard(List<Map<String, dynamic>> rows) {
    final batch = _batchId(rows.first);
    final isDeleting = _deletingBatches.contains(batch);
    final isExpanded = _expandedBatches.contains(batch);
    final pdfLoading = _exportingBatches.contains('$batch-pdf');
    final excelLoading = _exportingBatches.contains('$batch-excel');

    final date = (rows.first['Дата'] ?? '').toString().trim();

    final totalRevenue =
        rows.fold<double>(0, (sum, row) => sum + _toDouble(row['РРЦ']));

    final totalProfit =
        rows.fold<double>(0, (sum, row) => sum + _profit(row));

    final channels = rows.map(_detectChannel).toSet().join(' / ');
    final product = _productName(rows.first);
    final client = _clientName(rows);
    final shortBatch = batch.replaceAll('BATCH-', '#');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppUi.cardDecoration(
        radius: 20,
        borderColor: AppColors.stroke.withOpacity(0.8),
        shadows: const [],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          setState(() {
            if (isExpanded) {
              _expandedBatches.remove(batch);
            } else {
              _expandedBatches.add(batch);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Накладная $shortBatch от $date',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMain,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (client.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            client,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          rows.length == 1
                              ? product
                              : '$product + ещё ${rows.length - 1}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMain,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$channels • выручка ${_formatMoney(totalRevenue)} ₸ • прибыль ${_formatMoney(totalProfit)} ₸',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: totalProfit >= 0
                                ? AppColors.success
                                : AppColors.danger,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 4),
                      isDeleting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.danger,
                              ),
                            )
                          : IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              onPressed: () => _deleteBatch(rows),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppColors.danger,
                                size: 21,
                              ),
                            ),
                    ],
                  ),
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.bg.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.stroke.withOpacity(0.6),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Состав накладной',
                        style: TextStyle(
                          color: AppColors.textMain,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _tableHeader(),
                      ...List.generate(rows.length, (index) {
                        return _tableRow(rows[index], index);
                      }),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _summaryRow(
                            'Итого',
                            totalRevenue,
                            AppColors.textMain,
                          ),
                          const SizedBox(width: 8),
                          _summaryRow(
                            'Прибыль',
                            totalProfit,
                            totalProfit >= 0
                                ? AppColors.success
                                : AppColors.danger,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _exportButton(
                            title: 'PDF',
                            icon: Icons.picture_as_pdf_outlined,
                            color: AppColors.danger,
                            loading: pdfLoading,
                            onTap: () => _exportInvoice(
                              rows: rows,
                              type: 'pdf',
                            ),
                          ),
                          const SizedBox(width: 10),
                          _exportButton(
                            title: 'EXCEL',
                            icon: Icons.table_chart_outlined,
                            color: const Color(0xFF22C55E),
                            loading: excelLoading,
                            onTap: () => _exportInvoice(
                              rows: rows,
                              type: 'excel',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
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

    final groups = _groups;

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
                                  'Открой накладную, чтобы посмотреть состав и повторно сформировать PDF/Excel.',
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
                                  icon: Icons.receipt_long_outlined,
                                  title: 'Накладных',
                                  value: groups.length.toString(),
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
                                          selected:
                                              _selectedPeriod == '7 дней',
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
                                          onTap: () => _pickDate(isFrom: true),
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
                                          onTap: () => _pickDate(isFrom: false),
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
                            ...groups.map(_buildBatchCard),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }
}