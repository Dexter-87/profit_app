import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:my_app/services/api_service.dart';
import 'package:my_app/theme/app_colors.dart';
import 'package:my_app/widgets/app_ui.dart';
import 'package:my_app/widgets/gradient_button.dart';
import 'package:url_launcher/url_launcher.dart';

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  bool _loading = true;
  String _error = '';

  List<Map<String, dynamic>> _stockRows = [];
  List<Map<String, dynamic>> _prices = [];
  List<Map<String, dynamic>> _filteredPrices = [];

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();

  Map<String, dynamic>? _selectedProduct;
  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _searchController.addListener(_filterPrices);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    try {
      setState(() {
        _loading = true;
        _error = '';
      });

      final stock = await ApiService.fetchStock();
      final prices = await ApiService.fetchPrices();

      setState(() {
        _stockRows = stock;
        _prices = prices;
        _filteredPrices = [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _downloadStockPdf() async {
    final uri = Uri.parse('http://192.168.1.248:8080/stock-report/pdf');

    await launchUrl(
      uri,
      mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
  }

  void _filterPrices() {
    final q = _searchController.text.toLowerCase().trim();

    if (q.isEmpty) {
      setState(() => _filteredPrices = []);
      return;
    }

    final result = _prices.where((item) {
      final brand = (item['brand'] ?? '').toString().toLowerCase();
      final model = (item['model'] ?? '').toString().toLowerCase();
      final fullName = (item['fullName'] ?? '').toString().toLowerCase();
      final source = (item['source'] ?? '').toString().toLowerCase();

      return brand.contains(q) ||
          model.contains(q) ||
          fullName.contains(q) ||
          source.contains(q);
    }).take(20).toList();

    setState(() => _filteredPrices = result);
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
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

  String _formatQty(double qty) {
    return qty.toStringAsFixed(qty % 1 == 0 ? 0 : 1);
  }

  String _stockName(Map<String, dynamic> row) {
    return (row['Наименование'] ??
            row['name'] ??
            row['Модель'] ??
            row['model'] ??
            row['__row']?[0] ??
            '')
        .toString()
        .trim();
  }

  double _stockQty(Map<String, dynamic> row) {
    return _toDouble(
      row['Количество'] ?? row['quantity'] ?? row['qty'] ?? row['__row']?[1],
    );
  }

  int? _stockRowIndex(Map<String, dynamic> row) {
    final value = row['__index'] ?? row['rowIndex'];
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  bool _sameProduct(String a, String b) {
    final aa = a.toLowerCase().trim();
    final bb = b.toLowerCase().trim();
    return aa == bb;
  }

  double _qtyForProduct(Map<String, dynamic> product) {
    final model = (product['model'] ?? '').toString();
    final fullName = (product['fullName'] ?? '').toString();

    double total = 0;

    for (final row in _stockRows) {
      final name = _stockName(row);

      if (_sameProduct(name, model) || _sameProduct(name, fullName)) {
        total += _stockQty(row);
      }
    }

    return total;
  }

  Map<String, dynamic>? _findPriceForName(String name) {
    final n = name.toLowerCase().trim();

    for (final p in _prices) {
      final model = (p['model'] ?? '').toString().toLowerCase().trim();
      final fullName = (p['fullName'] ?? '').toString().toLowerCase().trim();

      if (model == n || fullName == n) return p;
    }

    for (final p in _prices) {
      final model = (p['model'] ?? '').toString().toLowerCase().trim();
      final fullName = (p['fullName'] ?? '').toString().toLowerCase().trim();

      if (model.contains(n) || fullName.contains(n) || n.contains(model)) {
        return p;
      }
    }

    return null;
  }

  Future<void> _addStock() async {
    final product = _selectedProduct;
    final qty = _toDouble(_qtyController.text);

    if (product == null) {
      _message('Выбери товар из прайса');
      return;
    }

    if (qty <= 0) {
      _message('Введите количество');
      return;
    }

    final name = (product['model'] ?? product['fullName'] ?? '').toString();

    setState(() => _saving = true);

    try {
      await ApiService.addStock(name: name, quantity: qty);

      _searchController.clear();
      _qtyController.clear();

      setState(() {
        _selectedProduct = null;
        _filteredPrices = [];
      });

      await _loadAll();
      _message('Остаток добавлен');
    } catch (e) {
      _message('Ошибка: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteStock(Map<String, dynamic> row) async {
    final rowIndex = _stockRowIndex(row);
    final name = _stockName(row);

    if (rowIndex == null || rowIndex < 2) {
      _message('Не найден номер строки для удаления');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text(
          'Удалить остаток?',
          style: TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          name.isEmpty ? 'Без названия' : name,
          style: const TextStyle(color: AppColors.textSecondary),
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
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _deleting = true);

      await ApiService.deleteStock(rowIndex);

      await _loadAll();
      _message('Остаток удалён');
    } catch (e) {
      _message('Ошибка удаления: $e');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
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
        radius: 18,
        shadows: const [],
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

  Widget _priceSuggestion(Map<String, dynamic> item) {
    final title = (item['fullName'] ?? item['model'] ?? '').toString();
    final cost = _toDouble(item['cost']);
    final source = (item['source'] ?? '').toString();

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        setState(() {
          _selectedProduct = item;
          _searchController.text = title;
          _filteredPrices = [];
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: AppUi.cardDecoration(
          color: AppColors.bg,
          radius: 16,
          borderColor: AppColors.stroke.withOpacity(0.75),
          shadows: const [],
        ),
        child: Row(
          children: [
            AppUi.iconBadge(
              icon: Icons.inventory_2_outlined,
              accent: const Color(0xFF22C55E),
              size: 34,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.textMain,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_formatMoney(cost)}\n$source',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallMetric(String title, String value, {bool accent = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.stroke.withOpacity(0.75)),
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
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent ? const Color(0xFF22C55E) : AppColors.textMain,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectedProductBlock() {
    final product = _selectedProduct;
    if (product == null) return const SizedBox.shrink();

    final title = (product['fullName'] ?? product['model'] ?? '').toString();
    final cost = _toDouble(product['cost']);
    final qty = _qtyForProduct(product);
    final total = qty * cost;

    final qtyColor = qty <= 0
        ? AppColors.danger
        : qty <= 2
            ? const Color(0xFFF59E0B)
            : const Color(0xFF22C55E);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppUi.cardDecoration(
        radius: 20,
        borderColor: qtyColor.withOpacity(0.28),
        shadows: [
          BoxShadow(
            color: qtyColor.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              AppUi.iconBadge(
                icon: Icons.search_outlined,
                accent: qtyColor,
                size: 38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _smallMetric('В наличии', _formatQty(qty), accent: qty > 0),
              const SizedBox(width: 8),
              _smallMetric('Себ', _formatMoney(cost)),
              const SizedBox(width: 8),
              _smallMetric('Итого', _formatMoney(total), accent: true),
            ],
          ),
          if (qty <= 0) ...[
            const SizedBox(height: 10),
            const Text(
              'Этой модели сейчас нет в остатках',
              style: TextStyle(
                color: AppColors.danger,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stockCard(Map<String, dynamic> row) {
    final name = _stockName(row);
    final qty = _stockQty(row);
    final price = _findPriceForName(name);
    final cost = price == null ? 0 : _toDouble(price['cost']);
    final total = qty * cost;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: AppUi.cardDecoration(
        radius: 20,
        borderColor: const Color(0xFF22C55E).withOpacity(0.22),
        shadows: [
          BoxShadow(
            color: const Color(0xFF22C55E).withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppUi.iconBadge(
                icon: Icons.inventory_2_outlined,
                accent: const Color(0xFF22C55E),
                size: 38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name.isEmpty ? 'Без названия' : name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _deleting ? null : () => _deleteStock(row),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.18)),
                  ),
                  child: Icon(
                    _deleting
                        ? Icons.hourglass_top_rounded
                        : Icons.delete_outline_rounded,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _smallMetric('Кол-во', _formatQty(qty)),
              const SizedBox(width: 8),
              _smallMetric('Себ', _formatMoney(cost)),
              const SizedBox(width: 8),
              _smallMetric('Итого', _formatMoney(total), accent: true),
            ],
          ),
          if (price == null) ...[
            const SizedBox(height: 8),
            const Text(
              'Себестоимость не найдена в прайсе',
              style: TextStyle(
                color: AppColors.danger,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalQty = 0;
    double totalCost = 0;

    for (final row in _stockRows) {
      final name = _stockName(row);
      final qty = _stockQty(row);
      final price = _findPriceForName(name);
      final cost = price == null ? 0 : _toDouble(price['cost']);

      totalQty += qty;
      totalCost += qty * cost;
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text(
          'Остатки',
          style: TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadAll,
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
                  onRefresh: _loadAll,
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
                                  const Color(0xFF22C55E).withOpacity(0.25),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withOpacity(0.02),
                                  const Color(0xFF22C55E).withOpacity(0.07),
                                ],
                              ),
                            ),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Склад и остатки',
                                  style: TextStyle(
                                    color: AppColors.textMain,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Выбери модель из прайса и сразу проверь, сколько штук есть в наличии.',
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
                                  icon: Icons.inventory_2_outlined,
                                  title: 'Позиций',
                                  value: _stockRows.length.toString(),
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
                                  icon: Icons.numbers,
                                  title: 'Штук',
                                  value: _formatQty(totalQty),
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
                          AppUi.metricCard(
                            icon: Icons.payments_outlined,
                            title: 'Сумма склада',
                            value: _formatMoney(totalCost),
                            accentColors: const [
                              Color(0xFF22C55E),
                              Color(0xFF16A34A),
                            ],
                            compact: true,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: GradientButton(
                              text: 'PDF ОТЧЁТ ПО ОСТАТКАМ',
                              icon: Icons.picture_as_pdf_outlined,
                              onTap: _downloadStockPdf,
                            ),
                          ),
                          const SizedBox(height: 16),
                          AppUi.sectionCard(
                            title: 'Проверить модель',
                            icon: Icons.search_outlined,
                            accent: const Color(0xFF06B6D4),
                            child: Column(
                              children: [
                                _input(
                                  controller: _searchController,
                                  hint: 'Начни писать модель из прайса',
                                ),
                                if (_filteredPrices.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  ..._filteredPrices.map(_priceSuggestion),
                                ],
                                if (_selectedProduct != null) ...[
                                  const SizedBox(height: 12),
                                  _selectedProductBlock(),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          AppUi.sectionCard(
                            title: 'Добавить остаток',
                            icon: Icons.add_box_outlined,
                            accent: const Color(0xFF22C55E),
                            child: Column(
                              children: [
                                if (_selectedProduct == null)
                                  const Text(
                                    'Сначала выбери модель в блоке выше.',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                else
                                  _selectedProductBlock(),
                                const SizedBox(height: 12),
                                _input(
                                  controller: _qtyController,
                                  hint: 'Количество',
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: GradientButton(
                                    text: _saving
                                        ? 'ДОБАВЛЯЮ...'
                                        : 'ДОБАВИТЬ ОСТАТОК',
                                    icon: Icons.save_outlined,
                                    onTap: () {
                                      if (_saving) return;
                                      _addStock();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          AppUi.sectionCard(
                            title: 'Список остатков',
                            icon: Icons.list_alt_outlined,
                            accent: const Color(0xFF4DA3FF),
                            child: _stockRows.isEmpty
                                ? AppUi.emptyBlock('Остатков пока нет')
                                : Column(
                                    children: _stockRows.map(_stockCard).toList(),
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