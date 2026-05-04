import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:my_app/theme/app_colors.dart';
import 'package:my_app/widgets/app_ui.dart';
import 'package:my_app/widgets/gradient_button.dart';

class CreateOrderPage extends StatefulWidget {
  const CreateOrderPage({super.key});

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  static const String baseUrl = 'http://localhost:8080';

  String _selectedChannel = 'ОПТ';
  String _selectedPriceType = 'Цена 0';

  bool _isSaving = false;
  bool _loadingPrices = true;

  List<dynamic> _prices = [];
  List<dynamic> _filteredPrices = [];
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

  @override
  void initState() {
    super.initState();
    _loadPrices();
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

  Future<void> _loadPrices() async {
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

  List<String> get _priceTypes {
    final set = <String>{};

    for (final item in _prices) {
      final type = (item['priceType'] ?? '').toString().trim();
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
        final brand = (item['brand'] ?? '').toString().toLowerCase();
        final model = (item['model'] ?? '').toString().toLowerCase();
        final fullName = (item['fullName'] ?? '').toString().toLowerCase();
        final source = (item['source'] ?? '').toString().toLowerCase();
        final priceType =
        (item['priceType'] ?? '').toString().toLowerCase().trim();

        final matchesProduct =
            brand.contains(query) ||
                model.contains(query) ||
                fullName.contains(query) ||
                source.contains(query);

        final matchesPriceType = priceType == selectedType;

        return matchesProduct && matchesPriceType;
      }).take(30).toList();
    });
  }

  void _selectProduct(dynamic item) {
    setState(() {
      final brand = (item['brand'] ?? '').toString().trim();
      final model = (item['model'] ?? '').toString().trim();

      _productController.text = '$brand $model'.trim();
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

  void _downloadFile({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  }) {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);

    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';

    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();

    html.Url.revokeObjectUrl(url);
  }

  void _addItemToInvoice() {
    final name = _productController.text.trim();
    final quantity = _quantity;
    final cost = _cost;
    final price = _price;
    final commission = _selectedChannel == 'Каспий' ? _commission : 0;
    final comment = _commentController.text.trim();

    if (name.isEmpty) {
      _showMessage('Введите товар');
      return;
    }

    if (price <= 0) {
      _showMessage('Введите цену продажи');
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
      });

      _productController.clear();
      _quantityController.text = '1';
      _costController.clear();
      _priceController.clear();
      _commissionController.clear();
      _commentController.clear();
      _filteredPrices = [];
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

    final client = _clientController.text.trim();
    final orderNumber = _orderController.text.trim();

    if (_selectedChannel == 'Каспий' && orderNumber.isEmpty) {
      _showMessage('Введите номер заказа Каспий');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/add-sale'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'items': _invoiceItems,
          'client': client,
          'channel': _selectedChannel,
          'orderNumber': orderNumber,
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
        _clientController.clear();
        _orderController.clear();
      });

      _showMessage('Продажи добавлены: $added шт');
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
        _downloadFile(
          bytes: response.bodyBytes,
          fileName: 'nakladnaya_${DateTime.now().millisecondsSinceEpoch}.xlsx',
          mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
        _showMessage('Excel скачан');
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
        _downloadFile(
          bytes: response.bodyBytes,
          fileName: 'nakladnaya_${DateTime.now().millisecondsSinceEpoch}.pdf',
          mimeType: 'application/pdf',
        );
        _showMessage('PDF скачан');
      } else {
        _showMessage('Ошибка PDF: ${response.body}');
      }
    } catch (e) {
      _showMessage('Ошибка PDF: $e');
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
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

                final brand = (item['brand'] ?? '').toString();
                final model = (item['model'] ?? '').toString();
                final source = (item['source'] ?? '').toString();
                final priceType = (item['priceType'] ?? '').toString();
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
                    color:
                    isGood ? const Color(0xFF22C55E) : AppColors.danger,
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
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '$quantity шт • ${_formatMoney(price)} • прибыль ${_formatMoney(profit)}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _removeInvoiceItem(index),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Итого: ${_formatMoney(_invoiceTotal)}',
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                'Прибыль: ${_formatMoney(_invoiceProfit)}',
                style: const TextStyle(
                  color: Color(0xFF22C55E),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _outlineActionButton({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: AppUi.cardDecoration(
          color: AppColors.bg,
          radius: 18,
          borderColor: AppColors.stroke,
          shadows: const [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.textMain, size: 20),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                color: AppColors.textMain,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppUi.cardDecoration(
        radius: 28,
        borderColor: const Color(0xFF4DA3FF).withOpacity(0.25),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.02),
            const Color(0xFF4DA3FF).withOpacity(0.08),
          ],
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Новый заказ',
            style: TextStyle(
              color: AppColors.textMain,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Добавляй товары в накладную, сохраняй продажи и формируй Excel/PDF.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text(
          'Заказ',
          style: TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
        backgroundColor: AppColors.bg,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadPrices,
            icon: const Icon(Icons.refresh, color: AppColors.textMain),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              _headerCard(),
              const SizedBox(height: 16),

              AppUi.sectionCard(
                title: 'Тип продажи',
                icon: Icons.swap_horiz_rounded,
                accent: const Color(0xFF4DA3FF),
                child: Row(
                  children: [
                    _channelButton('Каспий'),
                    const SizedBox(width: 10),
                    _channelButton('ОПТ'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              AppUi.sectionCard(
                title: 'Товар и клиент',
                icon: Icons.inventory_2_outlined,
                accent: const Color(0xFF22C55E),
                child: Column(
                  children: [
                    _productSearchBlock(),
                    const SizedBox(height: 10),
                    _input(
                      controller: _clientController,
                      hint: 'Клиент',
                      icon: Icons.person_outline,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              if (_selectedChannel == 'Каспий') ...[
                AppUi.sectionCard(
                  title: 'Данные Kaspi',
                  icon: Icons.storefront_outlined,
                  accent: const Color(0xFF06B6D4),
                  child: Column(
                    children: [
                      _input(
                        controller: _orderController,
                        hint: 'Номер заказа Каспий',
                        icon: Icons.confirmation_number_outlined,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 10),
                      _input(
                        controller: _commissionController,
                        hint: 'Комиссия Kaspi',
                        icon: Icons.percent_rounded,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              AppUi.sectionCard(
                title: 'Финансы',
                icon: Icons.payments_outlined,
                accent: const Color(0xFFF59E0B),
                child: Column(
                  children: [
                    _input(
                      controller: _quantityController,
                      hint: 'Количество',
                      icon: Icons.format_list_numbered_rounded,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _input(
                            controller: _costController,
                            hint: 'Себестоимость',
                            icon: Icons.money_off_outlined,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _input(
                            controller: _priceController,
                            hint: 'РРЦ',
                            icon: Icons.attach_money_rounded,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _profitPreview(),
                    const SizedBox(height: 14),
                    _outlineActionButton(
                      text: '+ ДОБАВИТЬ В НАКЛАДНУЮ',
                      icon: Icons.add_rounded,
                      onTap: _addItemToInvoice,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              AppUi.sectionCard(
                title: 'Комментарий',
                icon: Icons.notes_rounded,
                accent: const Color(0xFF8B5CF6),
                child: _input(
                  controller: _commentController,
                  hint: 'Комментарий (+ для 50/50)',
                  icon: Icons.add_comment_outlined,
                ),
              ),

              const SizedBox(height: 16),

              _invoiceBlock(),

              const SizedBox(height: 22),

              GradientButton(
                text: _isSaving ? 'СОХРАНЯЮ...' : '+ ДОБАВИТЬ В ПРОДАЖИ',
                onTap: () {
                  if (_isSaving) return;
                  _saveOrder();
                },
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _outlineActionButton(
                      text: 'EXCEL',
                      icon: Icons.table_chart_outlined,
                      onTap: _saveInvoiceExcel,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _outlineActionButton(
                      text: 'PDF',
                      icon: Icons.picture_as_pdf_outlined,
                      onTap: _saveInvoicePdf,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
