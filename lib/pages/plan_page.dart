import 'package:flutter/material.dart';
import 'package:my_app/theme/app_colors.dart';
import 'package:my_app/widgets/app_ui.dart';

class PlanPage extends StatelessWidget {
  const PlanPage({super.key});

  Widget _scenarioCard({
    required String title,
    required String subtitle,
    required List<Color> accentColors,
    required IconData icon,
  }) {
    return Container(
      decoration: AppUi.cardDecoration(
        radius: 24,
        borderColor: accentColors.first.withOpacity(0.22),
        shadows: [
          BoxShadow(
            color: accentColors.first.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: accentColors),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textMain,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _planFactCard({
    required String title,
    required String fact,
    required String plan,
    required double progress,
    required List<Color> accentColors,
  }) {
    return AppUi.sectionCard(
      title: title,
      icon: Icons.flag_outlined,
      accent: accentColors.first,
      child: AppUi.progressBlock(
        title: 'Факт / План',
        currentLabel: fact,
        totalLabel: plan,
        progress: progress,
        accentColors: accentColors,
      ),
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
          'План',
          style: TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.w800,
            fontSize: 24,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppUi.cardDecoration(
              radius: 28,
              borderColor: const Color(0xFFF59E0B).withOpacity(0.22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.02),
                  const Color(0xFFF59E0B).withOpacity(0.08),
                ],
              ),
              shadows: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withOpacity(0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'План и модель',
                  style: TextStyle(
                    color: AppColors.textMain,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Здесь будет годовой план, сценарии по вложениям, сезонность и наглядная логика распределения прибыли.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.45,
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
                  icon: Icons.payments_outlined,
                  title: 'План выручки',
                  value: '10 000 000 ₸',
                  accentColors: const [
                    Color(0xFF4DA3FF),
                    Color(0xFF2D7DFF),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppUi.metricCard(
                  icon: Icons.trending_up_outlined,
                  title: 'План прибыли',
                  value: '800 000 ₸',
                  accentColors: const [
                    Color(0xFF22C55E),
                    Color(0xFF16A34A),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: AppUi.metricCard(
                  icon: Icons.wb_sunny_outlined,
                  title: 'Пик спроса',
                  value: 'Апр–Май',
                  accentColors: const [
                    Color(0xFFF59E0B),
                    Color(0xFFD97706),
                  ],
                  compact: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppUi.metricCard(
                  icon: Icons.calendar_month_outlined,
                  title: 'Второй пик',
                  value: 'Авг–Сен',
                  accentColors: const [
                    Color(0xFF8B5CF6),
                    Color(0xFF6D28D9),
                  ],
                  compact: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _planFactCard(
            title: 'План / факт по выручке',
            fact: '5 400 000 ₸',
            plan: '10 000 000 ₸',
            progress: 0.54,
            accentColors: const [
              Color(0xFF4DA3FF),
              Color(0xFF2D7DFF),
            ],
          ),
          const SizedBox(height: 12),

          _planFactCard(
            title: 'План / факт по прибыли',
            fact: '304 000 ₸',
            plan: '800 000 ₸',
            progress: 0.38,
            accentColors: const [
              Color(0xFF22C55E),
              Color(0xFF16A34A),
            ],
          ),
          const SizedBox(height: 16),

          AppUi.sectionCard(
            title: 'Сценарии',
            icon: Icons.account_tree_outlined,
            accent: const Color(0xFF8B5CF6),
            child: Column(
              children: [
                _scenarioCard(
                  title: 'Текущая модель',
                  subtitle:
                  'Текущая схема распределения прибыли между Стасом и Алексеем.',
                  accentColors: const [
                    Color(0xFF8B5CF6),
                    Color(0xFF6D28D9),
                  ],
                  icon: Icons.balance_outlined,
                ),
                const SizedBox(height: 12),
                _scenarioCard(
                  title: 'Капитал + работа',
                  subtitle:
                  'Модель, где отдельно учитываются вложения и операционная работа.',
                  accentColors: const [
                    Color(0xFF22C55E),
                    Color(0xFF16A34A),
                  ],
                  icon: Icons.handshake_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          AppUi.infoBlock(
            title: 'Что сюда подключим дальше',
            icon: Icons.auto_awesome_rounded,
            accent: const Color(0xFFF59E0B),
            items: const [
              'Помесячный план продаж',
              'План-факт по сезонам',
              'Сценарии вложений Стаса и Алексея',
              'Объяснение логики для партнера',
              'Привязку к реальным данным из продаж',
            ],
          ),
          const SizedBox(height: 14),

          AppUi.infoBlock(
            title: 'Для чего нужен этот экран',
            icon: Icons.lightbulb_outline,
            accent: const Color(0xFF4DA3FF),
            items: const [
              'Показать партнеру понятную бизнес-логику',
              'Сравнить модели распределения',
              'Следить за выполнением месячного и годового плана',
              'Принимать решения по вложениям и сезонности',
            ],
          ),
        ],
      ),
    );
  }
}
