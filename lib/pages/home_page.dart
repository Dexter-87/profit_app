import 'package:flutter/material.dart';
import 'package:my_app/theme/app_colors.dart';
import 'package:my_app/widgets/app_ui.dart';

import 'sales_page.dart';
import 'analytics_page.dart';
import 'create_order_page.dart';
import 'expenses_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Widget _quickActionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
    required Widget page,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => page),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppUi.cardDecoration(
            radius: 22,
            borderColor: colors.first.withOpacity(0.22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.02),
                colors.first.withOpacity(0.08),
              ],
            ),
            shadows: [
              BoxShadow(
                color: colors.first.withOpacity(0.14),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(height: 12),
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
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _insightCard({
    required String title,
    required String text,
    required IconData icon,
    required List<Color> colors,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppUi.cardDecoration(
        radius: 22,
        borderColor: colors.first.withOpacity(0.20),
        shadows: [
          BoxShadow(
            color: colors.first.withOpacity(0.10),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
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
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    text,
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

  Widget _miniSummaryRow({
    required String label,
    required String value,
    required Color accent,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textMain,
              fontSize: 13,
              fontWeight: FontWeight.w800,
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
          'Главная',
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
              borderColor: const Color(0xFF4DA3FF).withOpacity(0.22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.02),
                  const Color(0xFF4DA3FF).withOpacity(0.08),
                ],
              ),
              shadows: [
                BoxShadow(
                  color: const Color(0xFF4DA3FF).withOpacity(0.14),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TechnoOpt',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Управление бизнесом',
                  style: TextStyle(
                    color: AppColors.textMain,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Продажи, аналитика, расходы и план в одном месте. Главный экран теперь показывает не меню, а полезную картину по бизнесу.',
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
                  title: 'Сегодня',
                  value: 'Скоро подключим',
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
                  title: '7 дней',
                  value: 'Скоро подключим',
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
                  icon: Icons.storefront_outlined,
                  title: 'Каспий',
                  value: 'Скоро подключим',
                  accentColors: const [
                    Color(0xFF8B5CF6),
                    Color(0xFF6D28D9),
                  ],
                  compact: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppUi.metricCard(
                  icon: Icons.local_shipping_outlined,
                  title: 'ОПТ',
                  value: 'Скоро подключим',
                  accentColors: const [
                    Color(0xFFF59E0B),
                    Color(0xFFD97706),
                  ],
                  compact: true,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          AppUi.sectionCard(
            title: 'Быстрые действия',
            icon: Icons.flash_on_rounded,
            accent: const Color(0xFF22C55E),
            child: Column(
              children: [
                Row(
                  children: [
                    _quickActionCard(
                      context: context,
                      title: 'Новый заказ',
                      subtitle: 'Быстро перейти к созданию заказа',
                      icon: Icons.add_box_outlined,
                      colors: const [
                        Color(0xFF22C55E),
                        Color(0xFF16A34A),
                      ],
                      page: const CreateOrderPage(),
                    ),
                    const SizedBox(width: 12),
                    _quickActionCard(
                      context: context,
                      title: 'Добавить расход',
                      subtitle: 'Занести расход и назначить владельца',
                      icon: Icons.receipt_long_outlined,
                      colors: const [
                        Color(0xFFEF4444),
                        Color(0xFFDC2626),
                      ],
                      page: const ExpensesPage(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _quickActionCard(
                      context: context,
                      title: 'Продажи',
                      subtitle: 'Открыть список продаж и фильтры',
                      icon: Icons.shopping_bag_outlined,
                      colors: const [
                        Color(0xFF4DA3FF),
                        Color(0xFF2D7DFF),
                      ],
                      page: const SalesPage(),
                    ),
                    const SizedBox(width: 12),
                    _quickActionCard(
                      context: context,
                      title: 'Аналитика',
                      subtitle: 'Перейти к разбору показателей',
                      icon: Icons.bar_chart_outlined,
                      colors: const [
                        Color(0xFF8B5CF6),
                        Color(0xFF6D28D9),
                      ],
                      page: const AnalyticsPage(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          AppUi.sectionCard(
            title: 'Короткая сводка',
            icon: Icons.grid_view_rounded,
            accent: const Color(0xFFF59E0B),
            child: Column(
              children: [
                _miniSummaryRow(
                  label: 'Продажи за период',
                  value: 'Скоро',
                  accent: const Color(0xFF4DA3FF),
                ),
                _miniSummaryRow(
                  label: 'Средний чек',
                  value: 'Скоро',
                  accent: const Color(0xFF22C55E),
                ),
                _miniSummaryRow(
                  label: 'Маржинальность',
                  value: 'Скоро',
                  accent: const Color(0xFF8B5CF6),
                ),
                _miniSummaryRow(
                  label: 'Расходы',
                  value: 'Скоро',
                  accent: const Color(0xFFEF4444),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          AppUi.sectionCard(
            title: 'Инсайты',
            icon: Icons.auto_awesome_rounded,
            accent: const Color(0xFF06B6D4),
            child: Column(
              children: [
                _insightCard(
                  title: 'По каналам',
                  text: 'Здесь можно будет показывать, какой канал даёт больше прибыли: Каспий или ОПТ.',
                  icon: Icons.compare_arrows_rounded,
                  colors: const [
                    Color(0xFF06B6D4),
                    Color(0xFF0891B2),
                  ],
                ),
                _insightCard(
                  title: 'По товарам',
                  text: 'Здесь появится топовый товар по прибыли и товары, которые тянут результат вверх.',
                  icon: Icons.workspace_premium_outlined,
                  colors: const [
                    Color(0xFFF59E0B),
                    Color(0xFFD97706),
                  ],
                ),
                _insightCard(
                  title: 'Для партнёра',
                  text: 'Позже на главной можно показывать ключевые цифры, которые удобно обсуждать с Алексеем.',
                  icon: Icons.groups_outlined,
                  colors: const [
                    Color(0xFF8B5CF6),
                    Color(0xFF6D28D9),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          AppUi.infoBlock(
            title: 'Что дальше',
            icon: Icons.auto_awesome,
            accent: const Color(0xFF22C55E),
            items: const [
              'Подключим реальные данные',
              'Добавим графики',
              'Сделаем топ товаров',
              'Сделаем отчёт для партнёра',
            ],
          ),
        ],
      ),
    );
  }
}
