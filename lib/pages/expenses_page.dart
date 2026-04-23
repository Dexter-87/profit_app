import 'package:flutter/material.dart';
import 'package:my_app/theme/app_colors.dart';
import 'package:my_app/widgets/app_ui.dart';
import 'package:my_app/widgets/gradient_button.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  String _selectedOwner = 'Алексей';
  String _selectedCategory = 'Личный расход';

  @override
  void dispose() {
    _amountController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  List<Color> get _accentColors {
    switch (_selectedOwner) {
      case 'Алексей':
        return const [Color(0xFFF59E0B), Color(0xFFD97706)];
      case 'Стас':
        return const [Color(0xFF4DA3FF), Color(0xFF2D7DFF)];
      case 'Общий':
        return const [Color(0xFF8B5CF6), Color(0xFF6D28D9)];
      default:
        return const [Color(0xFFF59E0B), Color(0xFFD97706)];
    }
  }

  IconData get _ownerIcon {
    switch (_selectedOwner) {
      case 'Алексей':
        return Icons.person_outline;
      case 'Стас':
        return Icons.person;
      case 'Общий':
        return Icons.groups_outlined;
      default:
        return Icons.person_outline;
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          AppUi.iconBadge(
            icon: Icons.circle,
            accent: _accentColors.first,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: _accentColors.first,
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
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Container(
      decoration: AppUi.cardDecoration(
        color: AppColors.bg,
        radius: 20,
        borderColor: _accentColors.first.withOpacity(0.18),
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
              gradient: LinearGradient(colors: _accentColors),
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

  Widget _buildChoiceButton({
    required String title,
    required bool selected,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 56,
          decoration: BoxDecoration(
            gradient: selected ? LinearGradient(colors: _accentColors) : null,
            color: selected ? null : AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? _accentColors.first.withOpacity(0.26)
                  : AppColors.stroke,
            ),
            boxShadow: selected
                ? [
              BoxShadow(
                color: _accentColors.first.withOpacity(0.18),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : AppColors.textMain,
                size: 18,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.textMain,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
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
        borderColor: _accentColors.first.withOpacity(0.24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.02),
            _accentColors.first.withOpacity(0.08),
          ],
        ),
        shadows: [
          BoxShadow(
            color: _accentColors.first.withOpacity(0.14),
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
                gradient: LinearGradient(colors: _accentColors),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _selectedOwner == 'Общий'
                    ? 'Общий расход'
                    : 'Расход: $_selectedOwner',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Добавить расход',
              style: TextStyle(
                color: AppColors.textMain,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Здесь можно занести расход с комментарием и указать, к кому он относится: общий, только Алексей или только Стас.',
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
        borderColor: _accentColors.first.withOpacity(0.18),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('На кого относится расход'),
            Row(
              children: [
                _buildChoiceButton(
                  title: 'Алексей',
                  selected: _selectedOwner == 'Алексей',
                  onTap: () {
                    setState(() {
                      _selectedOwner = 'Алексей';
                    });
                  },
                  icon: Icons.person_outline,
                ),
                const SizedBox(width: 10),
                _buildChoiceButton(
                  title: 'Стас',
                  selected: _selectedOwner == 'Стас',
                  onTap: () {
                    setState(() {
                      _selectedOwner = 'Стас';
                    });
                  },
                  icon: Icons.person,
                ),
                const SizedBox(width: 10),
                _buildChoiceButton(
                  title: 'Общий',
                  selected: _selectedOwner == 'Общий',
                  onTap: () {
                    setState(() {
                      _selectedOwner = 'Общий';
                    });
                  },
                  icon: Icons.groups_outlined,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildSectionTitle('Тип расхода'),
            Row(
              children: [
                _buildChoiceButton(
                  title: 'Личный расход',
                  selected: _selectedCategory == 'Личный расход',
                  onTap: () {
                    setState(() {
                      _selectedCategory = 'Личный расход';
                    });
                  },
                  icon: Icons.receipt_long_outlined,
                ),
                const SizedBox(width: 10),
                _buildChoiceButton(
                  title: 'Операционный',
                  selected: _selectedCategory == 'Операционный',
                  onTap: () {
                    setState(() {
                      _selectedCategory = 'Операционный';
                    });
                  },
                  icon: Icons.settings_suggest_outlined,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildSectionTitle('Сумма'),
            _buildInput(
              controller: _amountController,
              hint: 'Введите сумму расхода',
              icon: Icons.payments_outlined,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 14),
            _buildSectionTitle('Комментарий'),
            _buildInput(
              controller: _commentController,
              hint: 'Например: доставка, бензин, реклама, упаковка',
              icon: Icons.notes_rounded,
              maxLines: 3,
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: AppUi.cardDecoration(
                color: AppColors.bg,
                radius: 20,
                borderColor: _accentColors.first.withOpacity(0.16),
                shadows: const [],
              ),
              child: Row(
                children: [
                  AppUi.iconBadge(
                    icon: _ownerIcon,
                    accent: _accentColors.first,
                    size: 42,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Как будет учитываться',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedOwner == 'Общий'
                              ? 'Этот расход потом делится между Стасом и Алексеем'
                              : 'Этот расход уйдет только в часть: $_selectedOwner',
                          style: const TextStyle(
                            color: AppColors.textMain,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                text: 'СОХРАНИТЬ РАСХОД',
                icon: Icons.save_outlined,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _selectedOwner == 'Общий'
                            ? 'Общий расход пока сохранится как заглушка. Подключим таблицу следующим этапом.'
                            : 'Расход для $_selectedOwner пока сохранится как заглушка. Подключим таблицу следующим этапом.',
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

  Widget _buildInfoCard() {
    return AppUi.infoBlock(
      title: 'Что подключим дальше',
      icon: Icons.auto_awesome_rounded,
      accent: _accentColors.first,
      items: const [
        'Сохранение расходов в таблицу',
        'Разделение общих и личных расходов',
        'Показ расходов внутри аналитики',
        'Фильтр по владельцу расхода',
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
          'Расходы',
          style: TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.w800,
            fontSize: 24,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopCard(),
            const SizedBox(height: 18),
            _buildFormCard(),
            const SizedBox(height: 14),
            _buildInfoCard(),
          ],
        ),
      ),
    );
  }
}
