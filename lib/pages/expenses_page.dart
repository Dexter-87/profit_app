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

  String _selectedType = 'Стас';

  @override
  void dispose() {
    _amountController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  List<Color> get _accentColors {
    switch (_selectedType) {
      case 'Алексей':
        return const [Color(0xFFF59E0B), Color(0xFFD97706)];
      case 'Стас':
        return const [Color(0xFF4DA3FF), Color(0xFF2D7DFF)];
      case 'Общий 50/50':
        return const [Color(0xFF8B5CF6), Color(0xFF6D28D9)];
      case 'Общий по модели':
        return const [Color(0xFF22C55E), Color(0xFF16A34A)];
      default:
        return const [Color(0xFF4DA3FF), Color(0xFF2D7DFF)];
    }
  }

  Widget _choice(String title) {
    final selected = _selectedType == title;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          setState(() {
            _selectedType = title;
          });
        },
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected ? LinearGradient(colors: _accentColors) : null,
            color: selected ? null : AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? Colors.transparent : AppColors.stroke,
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textMain,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hint,
  }) {
    return Container(
      decoration: AppUi.cardDecoration(
        color: AppColors.bg,
        radius: 20,
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
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

  String get _hint {
    switch (_selectedType) {
      case 'Стас':
        return 'Расход уйдет только в Стаса';
      case 'Алексей':
        return 'Расход уйдет только в Алексея';
      case 'Общий 50/50':
        return 'Расход делится 50/50';
      case 'Общий по модели':
        return 'Расход делится по долям модели';
      default:
        return '';
    }
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
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppUi.cardDecoration(
                    radius: 28,
                    borderColor: _accentColors.first.withOpacity(0.25),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Добавить расход',
                        style: TextStyle(
                          color: AppColors.textMain,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Выбери тип расхода и добавь сумму.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                /// ТИП РАСХОДА
                AppUi.sectionCard(
                  title: 'Тип расхода',
                  icon: Icons.tune,
                  accent: _accentColors.first,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _choice('Стас'),
                          const SizedBox(width: 8),
                          _choice('Алексей'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _choice('Общий 50/50'),
                          const SizedBox(width: 8),
                          _choice('Общий по модели'),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                /// СУММА
                AppUi.sectionCard(
                  title: 'Сумма',
                  icon: Icons.payments_outlined,
                  accent: _accentColors.first,
                  child: _input(
                    controller: _amountController,
                    hint: 'Введите сумму',
                  ),
                ),

                const SizedBox(height: 16),

                /// КОММЕНТ
                AppUi.sectionCard(
                  title: 'Комментарий',
                  icon: Icons.notes,
                  accent: _accentColors.first,
                  child: _input(
                    controller: _commentController,
                    hint: 'Например: доставка, реклама',
                  ),
                ),

                const SizedBox(height: 16),

                /// ПОДСКАЗКА
                AppUi.sectionCard(
                  title: 'Как будет считаться',
                  icon: Icons.info_outline,
                  accent: _accentColors.first,
                  child: Text(
                    _hint,
                    style: const TextStyle(
                      color: AppColors.textMain,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                /// КНОПКА
                SizedBox(
                  width: double.infinity,
                  child: GradientButton(
                    text: 'СОХРАНИТЬ РАСХОД',
                    icon: Icons.save,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Тип: $_selectedType | сумма: ${_amountController.text}',
                          ),
                        ),
                      );
                    },
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
