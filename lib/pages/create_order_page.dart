import 'dart:convert';

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
  bool _isSaving = false;

  final TextEditingController _productController = TextEditingController();
  final TextEditingController _quantityController =
  TextEditingController(text: '1');
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _clientController = TextEditingController();

  @override
  void dispose() {
    _productController.dispose();
    _quantityController.dispose();
    _costController.dispose();
    _priceController.dispose();
    _commentController.dispose();
    _clientController.dispose();
    super.dispose();
  }

  double _toDouble(String value) {
    return double.tryParse(
      value
          .replaceAll('₸', '')
          .replaceAll(' ', '')
          .replaceAll(',', '.'),
    ) ??
        0;
  }

  int _toInt(String value) {
    return int.tryParse(value.trim()) ?? 1;
  }

  List<Color> get _channelColors {
    return _selectedChannel == 'Каспий'
        ? const [Color(0xFF4DA3FF), Color(0xFF2D7DFF)]
        : const [Color(0xFF22C55E), Color(0xFF16A34A)];
  }

  Future<void> _saveOrder() async {
    final name = _productController.text.trim();
    final quantity = _toInt(_quantityController.text);
    final cost = _toDouble(_costController.text);
    final price = _toDouble(_priceController.text);
    final comment = _commentController.text.trim();
    final client = _clientController.text.trim();

    if (name.isEmpty) {
      _showMessage('Введите товар');
      return;
    }

    if (quantity <= 0) {
      _showMessage('Количество должно быть больше 0');
      return;
    }

    if (price <= 0) {
      _showMessage('Введите цену продажи');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/add-sale'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'quantity': quantity,
          'cost': cost,
          'price': price,
          'comment': comment,
          'client': client,
          'channel': _selectedChannel,
        }),
      );

      if (response.statusCode == 200) {
        _productController.clear();
        _quantityController.text = '1';
        _costController.clear();
        _priceController.clear();
        _commentController.clear();
        _clientController.clear();

        _showMessage('Заказ сохранён. Добавлено строк: $quantity');
      } else {
        _showMessage('Ошибка сохранения: ${response.body}');
      }
    } catch (e) {
      _showMessage('Не удалось подключиться к серверу: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Widget _buildSectionTitle(String title, {Color accent = AppColors.primary}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          AppUi.iconBadge(
            icon: Icons.circle,
            accent: accent,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: accent,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    List<Color>? accentColors,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    final colors = accentColors ??
        const [
          Color(0xFF4DA3FF),
          Color(0xFF2D7DFF),
        ];

    return Container(
      decoration: AppUi.cardDecoration(
        color: AppColors.bg,
        radius: 20,
        borderColor: colors.first.withOpacity(0.18),
        shadows: const [],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(
          color: AppColors.textMain,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          prefixIcon: Container(
            margin: const EdgeInsets.all(10),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 18,
            ),
          ),
          hintText: hint,
          hintStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
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

  Widget _buildChannelButton(String channel, List<Color> colors) {
    final isSelected = _selectedChannel == channel;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedChannel = channel;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 58,
          decoration: BoxDecoration(
            gradient: isSelected ? LinearGradient(colors: colors) : null,
            color: isSelected ? null : AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? colors.first.withOpacity(0.28)
                  : AppColors.stroke,
            ),
            boxShadow: isSelected
                ? [
              BoxShadow(
                color: colors.first.withOpacity(0.20),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                channel == 'Каспий'
                    ? Icons.storefront_outlined
                    : Icons.local_shipping_outlined,
                color: isSelected ? Colors.white : AppColors.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                channel,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textMain,
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopCard() {
    return Container(
      width: double.infinity,
      decoration: AppUi.cardDecoration(
        radius: 28,
        borderColor: _channelColors.first.withOpacity(0.24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.02),
            _channelColors.first.withOpacity(0.08),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: _channelColors),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _selectedChannel == 'Каспий' ? 'Kaspi заказ' : 'Оптовый заказ',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Создать заказ',
              style: TextStyle(
                color: AppColors.textMain,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Заполни товар, себестоимость, цену и количество. После сохранения заказ сразу попадёт в Google Sheets.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      width: double.infinity,
      decoration: AppUi.cardDecoration(
        radius: 26,
        borderColor: _channelColors.first.withOpacity(0.18),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Канал продаж', accent: _channelColors.first),
            Row(
              children: [
                _buildChannelButton(
                  'Каспий',
                  const [Color(0xFF4DA3FF), Color(0xFF2D7DFF)],
                ),
                const SizedBox(width: 10),
                _buildChannelButton(
                  'ОПТ',
                  const [Color(0xFF22C55E), Color(0xFF16A34A)],
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildSectionTitle('Товар', accent: _channelColors.first),
            _buildInput(
              controller: _productController,
              hint: 'Введите модель товара',
              icon: Icons.inventory_2_outlined,
              accentColors: _channelColors,
            ),
            const SizedBox(height: 14),
            _buildSectionTitle('Клиент', accent: _channelColors.first),
            _buildInput(
              controller: _clientController,
              hint: 'Введите клиента',
              icon: Icons.person_outline_rounded,
              accentColors: _channelColors,
            ),
            const SizedBox(height: 14),
            _buildSectionTitle('Количество', accent: _channelColors.first),
            _buildInput(
              controller: _quantityController,
              hint: 'Введите количество',
              icon: Icons.format_list_numbered_rounded,
              keyboardType: TextInputType.number,
              accentColors: _channelColors,
            ),
            const SizedBox(height: 14),
            _buildSectionTitle('Себестоимость', accent: _channelColors.first),
            _buildInput(
              controller: _costController,
              hint: 'Введите себестоимость',
              icon: Icons.price_change_outlined,
              keyboardType: TextInputType.number,
              accentColors: _channelColors,
            ),
            const SizedBox(height: 14),
            _buildSectionTitle('Цена продажи', accent: _channelColors.first),
            _buildInput(
              controller: _priceController,
              hint: 'Введите РРЦ / цену продажи',
              icon: Icons.payments_outlined,
              keyboardType: TextInputType.number,
              accentColors: _channelColors,
            ),
            const SizedBox(height: 14),
            _buildSectionTitle('Комментарий', accent: _channelColors.first),
            _buildInput(
              controller: _commentController,
              hint: 'Комментарий. Для 50/50 можно поставить +',
              icon: Icons.notes_rounded,
              maxLines: 3,
              accentColors: _channelColors,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                text: _isSaving ? 'СОХРАНЯЮ...' : 'СОХРАНИТЬ ЗАКАЗ',
                icon: Icons.save_outlined,
                onTap: () {
                  if (_isSaving) return;
                  _saveOrder();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    return AppUi.infoBlock(
      title: 'Как сохранится',
      icon: Icons.check_circle_outline_rounded,
      accent: _selectedChannel == 'Каспий'
          ? const Color(0xFF4DA3FF)
          : const Color(0xFF22C55E),
      items: [
        'Дата — сегодняшняя',
        'Канал — $_selectedChannel',
        'Если количество 3 — в таблицу добавятся 3 строки',
        'Комментарий + сохранится как текст для логики 50/50',
      ],
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
          'Заказ',
          style: TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.w800,
            fontSize: 24,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopCard(),
              const SizedBox(height: 18),
              _buildFormCard(),
              const SizedBox(height: 14),
              _buildPreviewCard(),
            ],
          ),
        ),
      ),
    );
  }
}
