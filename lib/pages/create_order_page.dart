import 'package:flutter/material.dart';
import 'package:my_app/theme/app_colors.dart';
import 'package:my_app/widgets/app_ui.dart';
import 'package:my_app/widgets/gradient_button.dart';

class CreateOrderPage extends StatefulWidget {
  const CreateOrderPage({super.key});

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  String _selectedChannel = 'Каспий';

  final TextEditingController _productController = TextEditingController();
  final TextEditingController _quantityController =
  TextEditingController(text: '1');
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _productController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  List<Color> get _channelColors {
    return _selectedChannel == 'Каспий'
        ? const [Color(0xFF4DA3FF), Color(0xFF2D7DFF)]
        : const [Color(0xFF22C55E), Color(0xFF16A34A)];
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
              if (channel == 'Каспий')
                const Icon(Icons.storefront_outlined, color: Colors.white, size: 18)
              else
                const Icon(Icons.local_shipping_outlined,
                    color: Colors.white, size: 18),
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
        shadows: [
          BoxShadow(
            color: _channelColors.first.withOpacity(0.14),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
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
              'Выбери канал, заполни товар, количество, цену и комментарий. Позже сюда легко подключим таблицы и автоподстановку.',
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
            _buildSectionTitle(
              'Канал продаж',
              accent: _channelColors.first,
            ),
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
            _buildSectionTitle(
              'Товар',
              accent: _channelColors.first,
            ),
            _buildInput(
              controller: _productController,
              hint: 'Введите модель товара',
              icon: Icons.inventory_2_outlined,
              accentColors: _channelColors,
            ),
            const SizedBox(height: 14),
            _buildSectionTitle(
              'Количество',
              accent: _channelColors.first,
            ),
            _buildInput(
              controller: _quantityController,
              hint: 'Введите количество',
              icon: Icons.format_list_numbered_rounded,
              keyboardType: TextInputType.number,
              accentColors: _channelColors,
            ),
            const SizedBox(height: 14),
            _buildSectionTitle(
              'Цена',
              accent: _channelColors.first,
            ),
            _buildInput(
              controller: _priceController,
              hint: 'Введите цену продажи',
              icon: Icons.payments_outlined,
              keyboardType: TextInputType.number,
              accentColors: _channelColors,
            ),
            const SizedBox(height: 14),
            _buildSectionTitle(
              'Комментарий',
              accent: _channelColors.first,
            ),
            _buildInput(
              controller: _commentController,
              hint: 'Комментарий к заказу',
              icon: Icons.notes_rounded,
              maxLines: 3,
              accentColors: _channelColors,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                text: 'СОХРАНИТЬ ЗАКАЗ',
                icon: Icons.save_outlined,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _selectedChannel == 'Каспий'
                            ? 'Сохранение заказа Kaspi подключим следующим этапом'
                            : 'Сохранение оптового заказа подключим следующим этапом',
                      ),
                    ),
                  );
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
      title: 'Что будет дальше',
      icon: Icons.auto_awesome_rounded,
      accent: _selectedChannel == 'Каспий'
          ? const Color(0xFF4DA3FF)
          : const Color(0xFF22C55E),
      items: [
        'Поиск товара по прайсу',
        'Автоподстановка цены и себестоимости',
        'Добавление нескольких позиций в один заказ',
        'Сохранение в таблицу и backend',
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
