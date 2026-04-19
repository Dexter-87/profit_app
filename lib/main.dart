import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'analytics_page.dart';
const String salesUrl =
    'https://docs.google.com/spreadsheets/d/e/2PACX-1vTVCDzAu1DphzNCs2AzlpsjgJyRfzYWEAicdYbqMEFCcjjcxo4WyjVkcKa2-6G2BDyhM2GaBRx23DvO/pub?gid=1240951053&single=true&output=csv';

const String teegPriceUrl =
    'https://docs.google.com/spreadsheets/d/e/2PACX-1vTs6jLT1iBie0Fcm28dPQ_x98Pm61yDGxBnHt85bPjyAUw_144eS0HaIEuejDQwYQ/pub?gid=115078867&single=true&output=csv';

const String aristonPriceUrl =
    'https://docs.google.com/spreadsheets/d/e/2PACX-1vQIpFNDSvIXvCQ4-uSvrHyM0QqXpMO83hn2K7b2tCVGJ8hOR9R199Sd2pKwTCRvVQ/pub?gid=1662607201&single=true&output=csv';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TechnoOpt',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF071427),
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F5BFF),
          brightness: Brightness.dark,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class CsvService {
  static Future<List<Map<String, String>>> fetchCsv(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Ошибка загрузки CSV');
    }

    final text = const Utf8Decoder().convert(response.bodyBytes);
    final lines = const LineSplitter().convert(text);

    if (lines.isEmpty) return [];

    final headers = _parseCsvLine(lines.first)
        .map((e) => e.replaceAll('\ufeff', '').trim())
        .toList();

    final result = <Map<String, String>>[];

    for (int i = 1; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) continue;

      final values = _parseCsvLine(lines[i]);
      final row = <String, String>{};

      for (int j = 0; j < headers.length; j++) {
        row[headers[j]] = j < values.length ? values[j].trim() : '';
      }

      result.add(row);
    }

    return result;
  }

  static List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    result.add(buffer.toString());
    return result;
  }
}

class PriceItem {
  final String brand;
  final String model;
  final String priceType;
  final double price;
  final double cost;

  PriceItem({
    required this.brand,
    required this.model,
    required this.priceType,
    required this.price,
    required this.cost,
  });
}

class PriceService {
  static Future<List<PriceItem>> loadAllPrices() async {
    final teegRows = await CsvService.fetchCsv(teegPriceUrl);
    final aristonRows = await CsvService.fetchCsv(aristonPriceUrl);
    final allRows = [...teegRows, ...aristonRows];

    return allRows.map(_mapRowToPriceItem).whereType<PriceItem>().toList();
  }

  static PriceItem? _mapRowToPriceItem(Map<String, String> row) {
    final brand = _pick(row, ['Бренд', 'бренд']);
    final model = _pick(row, ['Модель', 'модель', 'Наименование', 'наименование']);
    final priceType =
        _pick(row, ['ТипЦены', 'Тип цены', 'тип цены', 'Тип', 'тип']) ?? 'Основная';
    final price = _parseNum(_pick(row, ['Цена', 'цена', 'РРЦ', 'ррц']));
    final cost =
        _parseNum(_pick(row, ['Себестоимость', 'себестоимость', 'Закуп', 'закуп']));

    if ((brand == null || brand.isEmpty) || (model == null || model.isEmpty)) {
      return null;
    }

    return PriceItem(
      brand: brand.trim(),
      model: model.trim(),
      priceType: priceType.trim().isEmpty ? 'Основная' : priceType.trim(),
      price: price,
      cost: cost,
    );
  }
}

class SalesRecord {
  final String date;
  final String channel;
  final String name;
  final String orderNumber;
  final double cost;
  final double price;
  final double kaspiCommission;
  final double profit;
  final String comment;

  SalesRecord({
    required this.date,
    required this.channel,
    required this.name,
    required this.orderNumber,
    required this.cost,
    required this.price,
    required this.kaspiCommission,
    required this.profit,
    required this.comment,
  });
}

class SalesService {
  static Future<List<SalesRecord>> loadSales() async {
    final rows = await CsvService.fetchCsv(salesUrl);

    return rows.map((row) {
      final date = _pick(row, ['Дата', 'дата']) ?? '';
      final channel = _pick(row, ['Канал', 'канал']) ?? '';
      final name = _pick(row, ['Наименование', 'наименование']) ?? '';
      final orderNumber = _pick(row, ['Номер заказа', 'номер заказа']) ?? '';
      final cost = _parseNum(_pick(row, ['Себестоимость', 'себестоимость']));
      final price = _parseNum(_pick(row, ['РРЦ', 'ррц']));
      final kaspi =
          _parseNum(_pick(row, ['Комиссия Kaspi', 'комиссия kaspi', 'Комиссия', 'комиссия']));
      final profitFromSheet = _parseNum(_pick(row, ['Чистая прибыль', 'чистая прибыль']));
      final comment =
          _pick(row, ['Комментарий', 'комментарий', 'Комментарии', 'комментарии']) ?? '';

      final profit = profitFromSheet != 0 ? profitFromSheet : (price - cost - kaspi);

      return SalesRecord(
        date: date,
        channel: channel,
        name: name,
        orderNumber: orderNumber,
        cost: cost,
        price: price,
        kaspiCommission: kaspi,
        profit: profit,
        comment: comment,
      );
    }).toList();
  }
}

String? _pick(Map<String, String> row, List<String> keys) {
  for (final key in keys) {
    if (row.containsKey(key) && (row[key]?.trim().isNotEmpty ?? false)) {
      return row[key]!.trim();
    }
  }
  return null;
}

double _parseNum(String? value) {
  if (value == null) return 0;
  final cleaned = value.replaceAll(' ', '').replaceAll(',', '.').trim();
  return double.tryParse(cleaned) ?? 0;
}

String formatMoney(num value) {
  final rounded = value.round().toString();
  final chars = rounded.split('').reversed.toList();
  final buffer = StringBuffer();

  for (int i = 0; i < chars.length; i++) {
    if (i > 0 && i % 3 == 0) buffer.write(' ');
    buffer.write(chars[i]);
  }

  return buffer.toString().split('').reversed.join();
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Widget buildActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    required Widget page,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => page),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color.fromARGB(70, 0, 0, 0),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 26),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xD9FFFFFF),
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1C33),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1D3152)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFFA9B6CC),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TechnoOpt'),
        centerTitle: false,
        backgroundColor: const Color(0xFF071427),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Привет, Стас!',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Панель управления бизнесом',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFFA9B6CC),
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Поиск по товарам и заказам',
                  hintStyle: const TextStyle(color: Color(0xFF7D8DAA)),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF7D8DAA)),
                  filled: true,
                  fillColor: const Color(0xFF0E1C33),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFF1D3152)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFF1D3152)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFF2F80ED)),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              const Text(
                'Быстрые действия',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 0.95,
                children: [
                  buildActionCard(
                    context: context,
                    icon: Icons.add_box_rounded,
                    title: 'Создать\nзаказ',
                    subtitle: 'Прайсы из Google Sheets',
                    gradientColors: const [
                      Color(0xFF2F5BFF),
                      Color(0xFF2445B8),
                    ],
                    page: const CreateOrderPage(),
                  ),
                  buildActionCard(
                    context: context,
                    icon: Icons.receipt_long_rounded,
                    title: 'Продажи',
                    subtitle: 'Список и сводка',
                    gradientColors: const [
                      Color(0xFF8C3BFF),
                      Color(0xFF6723D4),
                    ],
                    page: const SalesPage(),
                  ),
                  buildActionCard(
                    context: context,
                    icon: Icons.analytics_rounded,
                    title: 'Аналитика',
                    subtitle: 'Подключим следующим этапом',
                    gradientColors: const [
                      Color(0xFFFF9A2F),
                      Color(0xFFD66A0A),
                    ],
                    page: AnalyticsPage(),
                      
                  ),
                  buildActionCard(
                    context: context,
                    icon: Icons.inventory_2_rounded,
                    title: 'Остатки',
                    subtitle: 'Пока отложено',
                    gradientColors: const [
                      Color(0xFF14A66A),
                      Color(0xFF0E7F52),
                    ],
                    page: const PlaceholderPage(
                      title: 'Остатки',
                      subtitle: 'Остатки сделаем позже, когда посчитаешь склад',
                      icon: Icons.inventory_2_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              const Text(
                'Быстрый доступ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.15,
                children: [
                  buildSummaryCard(
                    title: 'Создать заказ',
                    value: 'Прайсы',
                    icon: Icons.add_business_rounded,
                    iconColor: const Color(0xFF35D49A),
                  ),
                  buildSummaryCard(
                    title: 'Продажи',
                    value: 'CSV',
                    icon: Icons.cloud_download_rounded,
                    iconColor: const Color(0xFF4DA3FF),
                  ),
                  buildSummaryCard(
                    title: 'Статус',
                    value: 'В работе',
                    icon: Icons.build_circle_rounded,
                    iconColor: const Color(0xFFFFB449),
                  ),
                  buildSummaryCard(
                    title: 'Платформа',
                    value: 'Flutter',
                    icon: Icons.phone_iphone_rounded,
                    iconColor: const Color(0xFFC087FF),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CreateOrderPage extends StatefulWidget {
  const CreateOrderPage({super.key});

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  final TextEditingController clientController = TextEditingController();
  final TextEditingController qtyController = TextEditingController(text: '1');
  final TextEditingController commentController = TextEditingController();

  List<PriceItem> allPrices = [];
  bool isLoading = true;
  String? errorText;

  String? selectedBrand;
  String? selectedModel;
  String? selectedPriceType;

  @override
  void initState() {
    super.initState();
    loadPrices();
  }

  @override
  void dispose() {
    clientController.dispose();
    qtyController.dispose();
    commentController.dispose();
    super.dispose();
  }

  Future<void> loadPrices() async {
    try {
      final prices = await PriceService.loadAllPrices();

      final brands = prices.map((e) => e.brand).toSet().toList()..sort();
      final firstBrand = brands.isNotEmpty ? brands.first : null;

      final models = prices
          .where((e) => e.brand == firstBrand)
          .map((e) => e.model)
          .toSet()
          .toList()
        ..sort();

      final firstModel = models.isNotEmpty ? models.first : null;

      final priceTypes = prices
          .where((e) => e.brand == firstBrand && e.model == firstModel)
          .map((e) => e.priceType)
          .toSet()
          .toList()
        ..sort();

      final firstPriceType = priceTypes.isNotEmpty ? priceTypes.first : null;

      setState(() {
        allPrices = prices;
        selectedBrand = firstBrand;
        selectedModel = firstModel;
        selectedPriceType = firstPriceType;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorText = 'Ошибка загрузки прайсов';
        isLoading = false;
      });
    }
  }

  List<String> get brands =>
      allPrices.map((e) => e.brand).toSet().toList()..sort();

  List<String> get models {
    if (selectedBrand == null) return [];
    return allPrices
        .where((e) => e.brand == selectedBrand)
        .map((e) => e.model)
        .toSet()
        .toList()
      ..sort();
  }

  List<String> get priceTypes {
    if (selectedBrand == null || selectedModel == null) return [];
    return allPrices
        .where((e) => e.brand == selectedBrand && e.model == selectedModel)
        .map((e) => e.priceType)
        .toSet()
        .toList()
      ..sort();
  }

  PriceItem? get currentItem {
    if (selectedBrand == null || selectedModel == null || selectedPriceType == null) {
      return null;
    }

    try {
      return allPrices.firstWhere(
        (e) =>
            e.brand == selectedBrand &&
            e.model == selectedModel &&
            e.priceType == selectedPriceType,
      );
    } catch (_) {
      return null;
    }
  }

  int get qty => int.tryParse(qtyController.text) ?? 0;

  double get currentPrice => currentItem?.price ?? 0;

  double get currentCost => currentItem?.cost ?? 0;

  double get totalSum => currentPrice * qty;

  InputDecoration fieldStyle(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF7D8DAA)),
      filled: true,
      fillColor: const Color(0xFF0E1C33),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF1D3152)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF1D3152)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF2F80ED)),
      ),
    );
  }

  Widget label(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFA9B6CC),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void saveOrder() {
    if (clientController.text.trim().isEmpty) {
      showMessage('Введите клиента');
      return;
    }

    if (qty <= 0) {
      showMessage('Количество должно быть больше 0');
      return;
    }

    if (currentItem == null) {
      showMessage('Не найдена цена для выбранной позиции');
      return;
    }

    showMessage(
      'Заказ готов: ${clientController.text.trim()} / ${selectedBrand ?? ""} / ${selectedModel ?? ""} / ${formatMoney(totalSum)} ₸',
    );
  }

  void addPosition() {
    if (currentItem == null) {
      showMessage('Сначала выбери позицию');
      return;
    }

    showMessage(
      'Позиция добавлена: ${selectedModel ?? ""} / $qty шт / ${formatMoney(totalSum)} ₸',
    );
  }

  void showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Создать заказ'),
        backgroundColor: const Color(0xFF071427),
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorText != null
              ? Center(child: Text(errorText!))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView(
                    children: [
                      const Text(
                        'Новый заказ',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Прайсы загружаются из Google Sheets',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFFA9B6CC),
                        ),
                      ),

                      label('Клиент'),
                      TextField(
                        controller: clientController,
                        decoration: fieldStyle('Имя клиента'),
                      ),

                      label('Бренд'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E1C33),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF1D3152)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedBrand,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF0E1C33),
                            items: brands
                                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;

                              final nextModels = allPrices
                                  .where((e) => e.brand == value)
                                  .map((e) => e.model)
                                  .toSet()
                                  .toList()
                                ..sort();

                              final nextModel =
                                  nextModels.isNotEmpty ? nextModels.first : null;

                              final nextPriceTypes = allPrices
                                  .where((e) => e.brand == value && e.model == nextModel)
                                  .map((e) => e.priceType)
                                  .toSet()
                                  .toList()
                                ..sort();

                              setState(() {
                                selectedBrand = value;
                                selectedModel = nextModel;
                                selectedPriceType = nextPriceTypes.isNotEmpty
                                    ? nextPriceTypes.first
                                    : null;
                              });
                            },
                          ),
                        ),
                      ),

                      label('Модель'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E1C33),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF1D3152)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedModel,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF0E1C33),
                            items: models
                                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;

                              final nextPriceTypes = allPrices
                                  .where((e) =>
                                      e.brand == selectedBrand && e.model == value)
                                  .map((e) => e.priceType)
                                  .toSet()
                                  .toList()
                                ..sort();

                              setState(() {
                                selectedModel = value;
                                selectedPriceType = nextPriceTypes.isNotEmpty
                                    ? nextPriceTypes.first
                                    : null;
                              });
                            },
                          ),
                        ),
                      ),

                      label('Тип цены'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E1C33),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF1D3152)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedPriceType,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF0E1C33),
                            items: priceTypes
                                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                selectedPriceType = value;
                              });
                            },
                          ),
                        ),
                      ),

                      label('Количество'),
                      TextField(
                        controller: qtyController,
                        keyboardType: TextInputType.number,
                        decoration: fieldStyle('1'),
                        onChanged: (_) => setState(() {}),
                      ),

                      label('Комментарий'),
                      TextField(
                        controller: commentController,
                        maxLines: 3,
                        decoration: fieldStyle('Комментарий'),
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: infoCard(
                              'Цена',
                              '${formatMoney(currentPrice)} ₸',
                              Icons.sell_rounded,
                              const Color(0xFF4DA3FF),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: infoCard(
                              'Себестоимость',
                              '${formatMoney(currentCost)} ₸',
                              Icons.inventory_rounded,
                              const Color(0xFFFFB449),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E1C33),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF1D3152)),
                        ),
                        child: Text(
                          'Итого: ${formatMoney(totalSum)} ₸',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: addPosition,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E8E5A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: const Text(
                                'Добавить позицию',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: saveOrder,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2F5BFF),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: const Text(
                                'Сохранить',
                                style: TextStyle(fontWeight: FontWeight.w700),
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

  Widget infoCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1C33),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1D3152)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFFA9B6CC),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  late Future<List<SalesRecord>> salesFuture;

  @override
  void initState() {
    super.initState();
    salesFuture = SalesService.loadSales();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Продажи'),
        backgroundColor: const Color(0xFF071427),
        elevation: 0,
      ),
      body: FutureBuilder<List<SalesRecord>>(
        future: salesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Ошибка загрузки продаж'));
          }

          final sales = snapshot.data ?? [];
          final salesCount = sales.length;
          final revenue = sales.fold<double>(0, (sum, item) => sum + item.price);
          final profit = sales.fold<double>(0, (sum, item) => sum + item.profit);
          final avgCheck = salesCount > 0 ? revenue / salesCount : 0;

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                salesFuture = SalesService.loadSales();
              });
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Продажи',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Данные загружаются из Google Sheets CSV',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFFA9B6CC),
                  ),
                ),
                const SizedBox(height: 18),

                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.2,
                  children: [
                    summaryBox('Количество', '$salesCount', Icons.shopping_bag_rounded,
                        const Color(0xFF35D49A)),
                    summaryBox('Выручка', '${formatMoney(revenue)} ₸',
                        Icons.trending_up_rounded, const Color(0xFF4DA3FF)),
                    summaryBox('Прибыль', '${formatMoney(profit)} ₸',
                        Icons.account_balance_wallet_rounded, const Color(0xFFFFB449)),
                    summaryBox('Средний чек', '${formatMoney(avgCheck)} ₸',
                        Icons.receipt_long_rounded, const Color(0xFFC087FF)),
                  ],
                ),

                const SizedBox(height: 22),
                const Text(
                  'Последние продажи',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),

                if (sales.isEmpty)
                  const Text('Нет данных')
                else
                  ...sales.reversed.take(20).map((sale) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E1C33),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF1D3152)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sale.name.isEmpty ? 'Без названия' : sale.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          rowText('Дата', sale.date.isEmpty ? '-' : sale.date),
                          rowText('Канал', sale.channel.isEmpty ? '-' : sale.channel),
                          rowText(
                            'Заказ',
                            sale.orderNumber.isEmpty ? '-' : sale.orderNumber,
                          ),
                          rowText('РРЦ', '${formatMoney(sale.price)} ₸'),
                          rowText(
                            'Прибыль',
                            '${formatMoney(sale.profit)} ₸',
                            valueColor: const Color(0xFF35D49A),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget summaryBox(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1C33),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1D3152)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFFA9B6CC),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget rowText(String label, String value, {Color valueColor = Colors.white}) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Color(0xFFA9B6CC),
              fontSize: 13,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PlaceholderPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const PlaceholderPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF071427),
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1C33),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF1D3152)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 54, color: Colors.white),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFFA9B6CC),
                    height: 1.35,
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

