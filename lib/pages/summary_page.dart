import 'package:flutter/material.dart';
import 'package:my_app/theme/app_colors.dart';

class SummaryPage extends StatelessWidget {
  const SummaryPage({super.key});

  Widget _metricCard({
    required IconData icon,
    required String title,
    required String value,
    required List<Color> accentColors,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accentColors.first.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: accentColors.first.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
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
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBlock({
    required String title,
    required IconData icon,
    required List<String> items,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textMain,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.map(
                (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.circle, size: 7, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13.5,
                        height: 1.35,
                      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text(
          'Сводка',
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
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.primary.withOpacity(0.22)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.02),
                  AppColors.primary.withOpacity(0.07),
                ],
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Быстрая сводка',
                  style: TextStyle(
                    color: AppColors.textMain,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Здесь будет короткий обзор по ключевым цифрам без глубокой аналитики.',
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
          _metricCard(
            icon: Icons.payments_outlined,
            title: 'Прибыль сегодня',
            value: 'Скоро подключим',
            accentColors: const [Color(0xFF4DA3FF), Color(0xFF2D7DFF)],
          ),
          const SizedBox(height: 12),
          _metricCard(
            icon: Icons.calendar_view_week_outlined,
            title: '7 дней',
            value: 'Скоро подключим',
            accentColors: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
          ),
          const SizedBox(height: 12),
          _metricCard(
            icon: Icons.storefront_outlined,
            title: 'Каспий / ОПТ',
            value: 'Скоро подключим',
            accentColors: const [Color(0xFF22C55E), Color(0xFF16A34A)],
          ),
          const SizedBox(height: 16),
          _infoBlock(
            title: 'Что будет в сводке',
            icon: Icons.flash_on_rounded,
            accent: const Color(0xFFF59E0B),
            items: const [
              'Прибыль сегодня',
              'Выручка за 7 и 30 дней',
              'Сравнение Каспий и ОПТ',
              'Топ товар по прибыли',
            ],
          ),
        ],
      ),
    );
  }
}
