import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:my_app/theme/app_colors.dart';
import 'package:my_app/widgets/app_ui.dart';
import 'package:my_app/widgets/gradient_button.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel;

class CreateOrderPage extends StatefulWidget {
  const CreateOrderPage({super.key});

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  static const String baseUrl = 'https://profit-app-7u44.onrender.com';

  String _selectedChannel = 'ОПТ';
  String _selectedPriceType = 'Цена 0';

  bool _isSaving = false;
  bool _loadingPrices = true;

  List<dynamic> _prices = [];
  List<dynamic> _filteredPrices = [];

  List<String> _clients = [];
  List<String> _filteredClients = [];

  final List<Map<String, dynamic>> _invoiceItems = [];

  final TextEditingController _productController = TextEditingController();
  final TextEditingController _quantityController =
      TextEditingController(text: '1');
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _commissionController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _clientController = TextEditingController();
  final TextEditingController _orderController = TextEditingController();

  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadPrices();
    _loadClients();
  }

  @override
  void dispose() {
    _productController.dispose();
    _quantityController.dispose();
    _costController.dispose();
    _priceController.dispose();
    _commissionController.dispose();
    _commentController.dispose();
    _clientController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  String _field(dynamic item, String snake, String camel) {
    return (item[snake] ?? item[camel] ?? '').toString().trim();
  }

  Future<void> _loadPrices() async {
    setState(() => _loadingPrices = true);

    try {
      final response = await http.get(Uri.parse('$baseUrl/prices'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          _prices = data;
          _filteredPrices = [];
          _loadingPrices = false;
        });
      } else {
        setState(() => _loadingPrices = false);
        _showMessage('Ошибка загрузки прайса');
      }
    } catch (e) {
      setState(() => _loadingPrices = false);
      _showMessage('Прайс не загрузился: $e');
    }
  }

  Future<void> _loadClients() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/sales'));
      final data = jsonDecode(response.body);

      final Set<String> clients = {};

      for (final row in data) {
        final client = (row['Клиент'] ?? row['client'] ?? '').toString().trim();

        if (client.isNotEmpty && client != '-' && client.length > 2) {
          clients.add(client);
        }
      }

      setState(() {
        _clients = clients.toList()..sort();
      });
    } catch (e) {
      debugPrint('Ошибка загрузки клиентов: $e');
    }
  }

  List<String> get _priceTypes {
    final set = <String>{};

    for (final item in _prices) {
      final type = _field(item, 'price_type', 'priceType');
      if (type.isNotEmpty) set.add(type);
    }

    final list = set.toList();
    list.sort();

    return list.isEmpty ? ['Цена 0'] : list;
  }

  void _onProductChanged(String value) {
    final query = value.toLowerCase().trim();
    final selectedType = _selectedPriceType.toLowerCase().trim();

    if (query.isEmpty) {
      setState(() => _filteredPrices = []);
      return;
    }

    setState(() {
      _filteredPrices = _prices.where((item) {
        final brand = _field(item, 'brand', 'brand').toLowerCase();
        final model = _field(item, 'model', 'model').toLowerCase();
        final fullName = _field(item, 'full_name', 'fullName').toLowerCase();
        final source = _field(item, 'source', 'source').toLowerCase();
        final priceType =
            _field(item, 'price_type', 'priceType').toLowerCase();

        final matchesProduct = brand.contains(query) ||
            model.contains(query) ||
            fullName.contains(query) ||
            source.contains(query);

        final matchesPriceType = priceType == selectedType;

        return matchesProduct && matchesPriceType;
      }).take(30).toList();
    });
  }

  void _onClientChanged(String value) {
    final query = value.toLowerCase().trim();

    if (query.isEmpty) {
      setState(() => _filteredClients = []);
      return;
    }

    setState(() {
      _filteredClients = _clients
          .where((client) => client.toLowerCase().contains(query))
          .take(8)
          .toList();
    });
  }

  void _selectProduct(dynamic item) {
    setState(() {
      final brand = _field(item, 'brand', 'brand');
      final model = _field(item, 'model', 'model');

      final modelLower = model.toLowerCase();
      final brandLower = brand.toLowerCase();

      if (brand.isNotEmpty && modelLower.startsWith(brandLower)) {
        _productController.text = model;
      } else {
        _productController.text = '$brand $model'.trim();
      }

      _priceController.text = (item['price'] ?? 0).toString();
      _costController.text = (item['cost'] ?? 0).toString();
      _filteredPrices = [];
    });
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

  int _toInt(String value) {
    final result = int.tryParse(value.trim()) ?? 1;
    return result <= 0 ? 1 : result;
  }

  int get _quantity => _toInt(_quantityController.text);
  double get _cost => _toDouble(_costController.text);
  double get _price => _toDouble(_priceController.text);

  double get _commission =>
      _selectedChannel == 'Каспий' ? _toDouble(_commissionController.text) : 0;

  double get _lineProfit => (_price - _cost - _commission) * _quantity;

  double get _invoiceTotal {
    double total = 0;
    for (final item in _invoiceItems) {
      total += (item['price'] as double) * (item['quantity'] as int);
    }
    return total;
  }

  double get _invoiceProfit {
    double total = 0;
    for (final item in _invoiceItems) {
      total += item['profit'] as double;
    }
    return total;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('ru', 'RU'),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  String _formatMoney(double value) {
    final number = value.round().toString();
    final isNegative = number.startsWith('-');
    final clean = number.replaceAll('-', '');

    final buffer = StringBuffer();
    int counter = 0;

    for (int i = clean.length - 1; i >= 0; i--) {
      buffer.write(clean[i]);
      counter++;

      if (counter == 3 && i != 0) {
        buffer.write(' ');
        counter = 0;
      }
    }

    return '${isNegative ? '-' : ''}${buffer.toString().split('').reversed.join()} ₸';
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

  void _addItemToInvoice() {
    final name = _productController.text.trim();
    final quantity = _quantity;
    final cost = _cost;
    final price = _price;
    final channel = _selectedChannel;
    final commission = channel == 'Каспий' ? _commission : 0;
    final comment = _commentController.text.trim();
    final client = _clientController.text.trim();
    final orderNumber = _orderController.text.trim();

    if (name.isEmpty) {
      _showMessage('Введите товар');
      return;
    }

    if (price <= 0) {
      _showMessage('Введите цену продажи');
      return;
    }

    if (channel == 'Каспий' && orderNumber.isEmpty) {
      _showMessage('Введите номер заказа Каспий');
      return;
    }

    final profit = (price - cost - commission) * quantity;

    setState(() {
      _invoiceItems.add({
        'name': name,
        'quantity': quantity,
        'cost': cost,
        'price': price,
        'commission': commission,
        'comment': comment,
        'profit': profit,
        'channel': channel,
        'client': client,
        'orderNumber': orderNumber,
      });

      _productController.clear();
      _quantityController.text = '1';
      _costController.clear();
      _priceController.clear();
      _commissionController.clear();
      _commentController.clear();
      _filteredPrices = [];
      _filteredClients = [];
    });

    _showMessage('Товар добавлен в накладную');
  }

  void _removeInvoiceItem(int index) {
    setState(() {
      _invoiceItems.removeAt(index);
    });
  }

  Future<void> _saveOrder() async {
    if (_invoiceItems.isEmpty) {
      _addItemToInvoice();
      if (_invoiceItems.isEmpty) return;
    }

    setState(() => _isSaving = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/add-sale'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'items': _invoiceItems,
          'date': _formatDate(_selectedDate),
        }),
      );

      if (response.statusCode != 200) {
        _showMessage('Ошибка: ${response.body}');
        return;
      }

      final data = jsonDecode(response.body);
      final added = data['added'] ?? 0;

      setState(() {
        _invoiceItems.clear();
        _productController.clear();
        _quantityController.text = '1';
        _costController.clear();
        _priceController.clear();
        _commissionController.clear();
        _commentController.clear();
        _clientController.clear();
        _orderController.clear();
        _selectedChannel = 'ОПТ';
        _selectedDate = DateTime.now();
        _filteredPrices = [];
        _filteredClients = [];
      });

      _showMessage('Продажи добавлены: $added шт');
      _loadClients();
    } catch (e) {
      _showMessage('Ошибка подключения: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

    Future<void> _saveInvoiceExcel() async {
      if (_invoiceItems.isEmpty) {
        _showMessage('Сначала добавь товары в накладную');
        return;
      }

      try {
        final response = await http.post(
          Uri.parse('$baseUrl/invoice-excel'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'items': _invoiceItems,
            'client': _clientController.text.trim(),
            'channel': _selectedChannel,
          }),
        );

        if (response.statusCode == 200) {
          await _saveAndOpenFile(
            bytes: response.bodyBytes,
            fileName: 'nakladnaya_${DateTime.now().millisecondsSinceEpoch}.xlsx',
          );
          _showMessage('Excel готов');
        } else {
          _showMessage('Ошибка Excel: ${response.body}');
        }
      } catch (e) {
        _showMessage('Ошибка Excel: $e');
      }
    }

    Future<void> _saveInvoicePdf() async {
      if (_invoiceItems.isEmpty) {
        _showMessage('Сначала добавь товары в накладную');
        return;
      }

      try {
        final response = await http.post(
          Uri.parse('$baseUrl/invoice-pdf'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'items': _invoiceItems,
            'client': _clientController.text.trim(),
            'channel': _selectedChannel,
          }),
        );

        if (response.statusCode == 200) {
          await _saveAndOpenFile(
            bytes: response.bodyBytes,
            fileName: 'nakladnaya_${DateTime.now().millisecondsSinceEpoch}.pdf',
          );
          _showMessage('PDF готов');
        } else {
          _showMessage('Ошибка PDF: ${response.body}');
        }
      } catch (e) {
        _showMessage('Ошибка PDF: $e');
      }
    }

Future<void> _importKaspiReport() async {
   try {
     final result = await FilePicker.platform.pickFiles(
       type: FileType.custom,
       allowedExtensions: ['xlsx'],
     );

     if (result == null) return;

     final path = result.files.single.path;

     if (path == null) {
       _showMessage('Не удалось открыть файл');
       return;
     }

     final bytes = File(path).readAsBytesSync();
     final excelFile = excel.Excel.decodeBytes(bytes);

     final List<Map<String, dynamic>> importedItems = [];

     for (final table in excelFile.tables.values) {
       List<String> headers = [];

       for (final row in table.rows) {
         final cells = row.map((cell) {
           return cell?.value?.toString().trim() ?? '';
         }).toList();

         final lowerCells = cells.map((x) => x.toLowerCase().trim()).toList();
         final joined = lowerCells.join(' ');

         if ((joined.contains('номер заказа') || joined.contains('номер операции')) &&
             joined.contains('детали покупки') &&
             (joined.contains('сумма операции') || joined.contains('сумма'))) {
           headers = lowerCells;
           continue;
         }

         if (headers.isEmpty) continue;

         String getByHeaderContains(String name) {
           final index = headers.indexWhere((h) => h.contains(name.toLowerCase()));
           if (index >= 0 && index < cells.length) {
             return cells[index];
           }
           return '';
         }

         double sumByHeaderContains(List<String> names) {
           double total = 0;

           for (final name in names) {
             final index = headers.indexWhere((h) => h.contains(name.toLowerCase()));
             if (index >= 0 && index < cells.length) {
               total += _toDouble(cells[index]).abs();
             }
           }

           return total;
         }

         final orderNumberRaw = getByHeaderContains('номер заказа').isNotEmpty
             ? getByHeaderContains('номер заказа')
             : getByHeaderContains('номер операции');

         final orderNumber = orderNumberRaw.replaceAll(RegExp(r'\D'), '');

         if (!RegExp(r'^\d{8,12}$').hasMatch(orderNumber)) continue;

         final product = getByHeaderContains('детали покупки');

         final date = getByHeaderContains('дата операции').isNotEmpty
             ? getByHeaderContains('дата операции')
             : getByHeaderContains('дата');

         final priceRaw = getByHeaderContains('сумма операции').isNotEmpty
             ? getByHeaderContains('сумма операции')
             : getByHeaderContains('сумма');

         final price = _toDouble(priceRaw);

         double sumKaspiCommissions() {
           double total = 0;

           for (int i = 0; i < headers.length && i < cells.length; i++) {
             final h = headers[i].toLowerCase();

             final isKaspiExpense =
                 h.contains('комиссия') ||
                 h.contains('стоимость услуг') ||
                 h.contains('стоимость услуги') ||
                 h.contains('оплата услуг') ||
                 h.contains('бонусы от продавца');

             final isWithoutVat =
                 h.contains('без ндс') ||
                 h.contains('без ндс');

             if (isKaspiExpense && !isWithoutVat) {
               total += _toDouble(cells[i]).abs();
             }
           }

           return total;
         }

         final commission = sumKaspiCommissions();

         if (product.isEmpty || price <= 0) continue;

         importedItems.add({
           'name': product,
           'quantity': 1,
           'costPrice': 0,
           'salePrice': price,
           'commission': commission,
           'comment': '',
           'channel': 'Каспий',
           'client': 'Kaspi',
           'orderNumber': orderNumber,
           'date': date,
         });
       }
     }

     if (importedItems.isEmpty) {
       _showMessage('В файле не найдены продажи Kaspi');
       return;
     }

     _showMessage('Найдено продаж: ${importedItems.length}');

     final response = await http.post(
       Uri.parse('$baseUrl/import-kaspi'),
       headers: {'Content-Type': 'application/json'},
       body: jsonEncode({
         'items': importedItems,
       }),
     );

     if (response.statusCode == 200) {
       final data = jsonDecode(response.body);
       final added = data['added'] ?? 0;
       final duplicates = data['duplicates'] ?? data['skipped'] ?? 0;

       _showMessage('Импорт готов: добавлено $added, дублей $duplicates');
       _loadClients();
     } else {
       _showMessage('Ошибка импорта: ${response.body}');
     }
   } catch (e) {
     _showMessage('Ошибка импорта: $e');
   }
 }

    Widget _channelButton(String title) {
      final selected = _selectedChannel == title;

      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            setState(() {
              _selectedChannel = title;

              if (_selectedChannel == 'ОПТ') {
                _commissionController.clear();
                _orderController.clear();
              }
            });
          },
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: selected
                  ? const LinearGradient(
                      colors: [Color(0xFF4DA3FF), Color(0xFF2D7DFF)],
                    )
                  : null,
              color: selected ? null : AppColors.bg,
              border: Border.all(
                color: selected ? Colors.transparent : AppColors.stroke,
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    }

    Widget _priceTypeDropdown() {
      final types = _priceTypes;

      if (!types.contains(_selectedPriceType)) {
        _selectedPriceType = types.first;
      }

      return Container(
        decoration: AppUi.cardDecoration(
          color: AppColors.bg,
          radius: 18,
          borderColor: AppColors.stroke,
          shadows: const [],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedPriceType,
            dropdownColor: AppColors.bg,
            iconEnabledColor: AppColors.textMain,
            isExpanded: true,
            style: const TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.w800,
            ),
            items: types.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) return;

              setState(() {
                _selectedPriceType = value;
                _priceController.clear();
                _costController.clear();

                if (_productController.text.trim().isEmpty) {
                  _filteredPrices = [];
                }
              });

              if (_productController.text.trim().isNotEmpty) {
                _onProductChanged(_productController.text);
              }
            },
          ),
        ),
      );
    }

    Widget _dateBlock() {
      return AppUi.sectionCard(
        title: 'Дата продажи',
        icon: Icons.calendar_month_rounded,
        accent: const Color(0xFF8B5CF6),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _pickDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
            decoration: AppUi.cardDecoration(
              color: AppColors.bg,
              radius: 18,
              borderColor: AppColors.stroke,
              shadows: const [],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  _formatDate(_selectedDate),
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget _input({
      required TextEditingController controller,
      required String hint,
      required IconData icon,
      TextInputType? keyboardType,
      int maxLines = 1,
      void Function(String)? onChanged,
    }) {
      return Container(
        decoration: AppUi.cardDecoration(
          color: AppColors.bg,
          radius: 18,
          borderColor: AppColors.stroke,
          shadows: const [],
        ),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
          style: const TextStyle(
            color: AppColors.textMain,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 21),
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      );
    }

    Widget _productSearchBlock() {
      return Column(
        children: [
          _priceTypeDropdown(),
          const SizedBox(height: 10),
          _input(
            controller: _productController,
            hint: _loadingPrices ? 'Загружаю прайс...' : 'Товар',
            icon: Icons.inventory_2_outlined,
            onChanged: _onProductChanged,
          ),
          if (_filteredPrices.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 260),
              decoration: AppUi.cardDecoration(
                color: AppColors.bg,
                radius: 18,
                borderColor: const Color(0xFF4DA3FF).withOpacity(0.35),
                shadows: const [],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: _filteredPrices.length,
                separatorBuilder: (_, __) => const Divider(
                  color: AppColors.stroke,
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  final item = _filteredPrices[index];

                  final brand = _field(item, 'brand', 'brand');
                  final model = _field(item, 'model', 'model');
                  final source = _field(item, 'source', 'source');
                  final priceType = _field(item, 'price_type', 'priceType');
                  final price = _toDouble((item['price'] ?? 0).toString());
                  final cost = _toDouble((item['cost'] ?? 0).toString());

                  return ListTile(
                    dense: true,
                    onTap: () => _selectProduct(item),
                    title: Text(
                      '$brand $model'.trim(),
                      style: const TextStyle(
                        color: AppColors.textMain,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      '$source • $priceType • цена ${_formatMoney(price)} • себ. ${_formatMoney(cost)}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      );
    }

      Widget _clientSearchBlock() {
        return Column(
          children: [
            _input(
              controller: _clientController,
              hint: 'Клиент',
              icon: Icons.person_outline,
              onChanged: _onClientChanged,
            ),
            if (_filteredClients.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 230),
                decoration: AppUi.cardDecoration(
                  color: AppColors.bg,
                  radius: 18,
                  borderColor: const Color(0xFF4DA3FF).withOpacity(0.30),
                  shadows: const [],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: _filteredClients.length,
                  separatorBuilder: (_, __) => const Divider(
                    color: AppColors.stroke,
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final client = _filteredClients[index];

                    return ListTile(
                      dense: true,
                      onTap: () {
                        setState(() {
                          _clientController.text = client;
                          _filteredClients = [];
                        });
                      },
                      leading: const Icon(
                        Icons.person_outline,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      title: Text(
                        client,
                        style: const TextStyle(
                          color: AppColors.textMain,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSecondary,
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        );
      }

      Widget _profitPreview() {
        final profit = _lineProfit;
        final isGood = profit >= 0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: AppUi.cardDecoration(
            color: AppColors.bg,
            radius: 22,
            borderColor: isGood
                ? const Color(0xFF22C55E).withOpacity(0.35)
                : AppColors.danger.withOpacity(0.35),
            shadows: const [],
          ),
          child: Row(
            children: [
              AppUi.iconBadge(
                icon: isGood
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                accent: isGood ? const Color(0xFF22C55E) : AppColors.danger,
                size: 42,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ожидаемая прибыль',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatMoney(profit),
                      style: TextStyle(
                        color: isGood ? const Color(0xFF22C55E) : AppColors.danger,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      Widget _invoiceBlock() {
        return AppUi.sectionCard(
          title: 'Накладная',
          icon: Icons.receipt_long_outlined,
          accent: const Color(0xFF06B6D4),
          child: Column(
            children: [
              if (_invoiceItems.isEmpty)
                AppUi.emptyBlock('Товары пока не добавлены')
              else
                Column(
                  children: List.generate(_invoiceItems.length, (index) {
                    final item = _invoiceItems[index];
                    final name = item['name'].toString();
                    final quantity = item['quantity'] as int;
                    final price = item['price'] as double;
                    final profit = item['profit'] as double;
                    final channel = (item['channel'] ?? '').toString();
                    final client = (item['client'] ?? '').toString();
                    final orderNumber = (item['orderNumber'] ?? '').toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: AppUi.cardDecoration(
                        color: AppColors.bg,
                        radius: 18,
                        borderColor: AppColors.stroke,
                        shadows: const [],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    color: AppColors.textMain,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '$quantity шт • ${_formatMoney(price)}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                if (channel.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      channel,
                                      style: const TextStyle(
                                        color: Color(0xFF4DA3FF),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                if (client.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      client,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                if (orderNumber.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Заказ: $orderNumber',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatMoney(profit),
                                style: const TextStyle(
                                  color: Color(0xFF22C55E),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () => _removeInvoiceItem(index),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.danger.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: AppColors.danger,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ),
            ],
          ),
        );
      }

        Widget _totalsBlock() {
          return AppUi.sectionCard(
            title: 'Итого по накладной',
            icon: Icons.summarize_outlined,
            accent: const Color(0xFF22C55E),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: AppUi.cardDecoration(
                      color: AppColors.bg,
                      radius: 18,
                      borderColor: AppColors.stroke,
                      shadows: const [],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Сумма',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatMoney(_invoiceTotal),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textMain,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: AppUi.cardDecoration(
                      color: AppColors.bg,
                      radius: 18,
                      borderColor: const Color(0xFF22C55E).withOpacity(0.35),
                      shadows: const [],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Прибыль',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatMoney(_invoiceProfit),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF22C55E),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        Widget _sectionTitle(String title) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          );
        }

        Widget _mainFormCard() {
          return AppUi.sectionCard(
            title: 'Товар и клиент',
            icon: Icons.add_shopping_cart_rounded,
            accent: const Color(0xFF4DA3FF),
            child: Column(
              children: [
                _sectionTitle('Канал продажи'),
                Row(
                  children: [
                    _channelButton('ОПТ'),
                    const SizedBox(width: 10),
                    _channelButton('Каспий'),
                  ],
                ),
                const SizedBox(height: 16),

                _sectionTitle('Клиент'),
                _clientSearchBlock(),
                const SizedBox(height: 16),

                _sectionTitle('Товар'),
                _productSearchBlock(),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _input(
                        controller: _quantityController,
                        hint: 'Кол-во',
                        icon: Icons.numbers_rounded,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _input(
                        controller: _costController,
                        hint: 'Себестоимость',
                        icon: Icons.price_change_outlined,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                _input(
                  controller: _priceController,
                  hint: 'Цена продажи',
                  icon: Icons.sell_outlined,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),

                if (_selectedChannel == 'Каспий') ...[
                  _input(
                    controller: _orderController,
                    hint: 'Номер заказа Каспий',
                    icon: Icons.confirmation_number_outlined,
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 12),
                  _input(
                    controller: _commissionController,
                    hint: 'Комиссия Kaspi',
                    icon: Icons.percent_rounded,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                ],

                _input(
                  controller: _commentController,
                  hint: 'Комментарий',
                  icon: Icons.comment_outlined,
                ),
                const SizedBox(height: 16),

                _profitPreview(),
                const SizedBox(height: 16),

                GradientButton(
                  text: 'Добавить товар в накладную',
                  onTap: _addItemToInvoice,
                ),
              ],
            ),
          );
        }

        Future<void> _importPricesToSupabase() async {
          try {
            final response = await http.get(
              Uri.parse('$baseUrl/import-prices-to-supabase'),
            );

            if (response.statusCode == 200) {
              _showMessage('Прайс обновлен в Supabase');
              await _loadPrices();
            } else {
              _showMessage('Ошибка обновления прайса: ${response.body}');
            }
          } catch (e) {
            _showMessage('Ошибка обновления прайса: $e');
          }
        }


        Widget _actionButtons() {
          return Column(
            children: [
              GradientButton(
                text: 'Обновить прайс',
                onTap: _importPricesToSupabase,
              ),

              const SizedBox(height: 10),

              if (_selectedChannel == 'Каспий') ...[
                GradientButton(
                  text: 'Импорт Kaspi',
                  onTap: _importKaspiReport,
                ),
                const SizedBox(height: 10),
              ],

              GradientButton(
                text: _isSaving ? 'Сохраняю...' : 'Сохранить продажу',
                onTap: () {
                  if (!_isSaving) {
                    _saveOrder();
                  }
                },
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: GradientButton(
                      text: 'Excel',
                      onTap: _saveInvoiceExcel,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GradientButton(
                      text: 'PDF',
                      onTap: _saveInvoicePdf,
                    ),
                  ),
                ],
              ),
            ],
          );
        }
          @override
          Widget build(BuildContext context) {
            return Scaffold(
              backgroundColor: AppColors.bg,
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      const SizedBox(height: 16),

                      _dateBlock(),
                      const SizedBox(height: 16),

                      _mainFormCard(),
                      const SizedBox(height: 16),

                      _invoiceBlock(),
                      const SizedBox(height: 16),

                      _totalsBlock(),
                      const SizedBox(height: 16),

                      _actionButtons(),
                    ],
                  ),
                ),
              ),
            );
          }

            void _showMessage(String message) {
              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
        }