import 'package:flutter/material.dart';

class PlanPage extends StatelessWidget {
  const PlanPage({super.key});

  @override
  Widget build(BuildContext context) {
    final monthlyPlan = [
      MonthPlanItem('Янв', '₸450 000', 0.42),
      MonthPlanItem('Фев', '₸420 000', 0.38),
      MonthPlanItem('Мар', '₸500 000', 0.51),
      MonthPlanItem('Апр', '₸620 000', 0.67),
      MonthPlanItem('Май', '₸780 000', 0.81),
      MonthPlanItem('Июн', '₸690 000', 0.72),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF09101D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'ПЛАН',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF09101D),
              Color(0xFF0D1630),
              Color(0xFF0A1120),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            children: [
              Row(
                children: const [
                  Expanded(
                    child: _PlanTopCard(
                      title: 'ГОДОВОЙ ПЛАН',
                      value: '₸7 200 000',
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _PlanTopCard(
                      title: 'ФАКТ',
                      value: '₸3 460 000',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: const [
                  Expanded(
                    child: _PlanTopCard(
                      title: 'ВЫПОЛНЕНИЕ',
                      value: '48%',
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _PlanTopCard(
                      title: 'ОСТАЛОСЬ',
                      value: '₸3 740 000',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _Panel(
                title: 'ПРОГРЕСС ПЛАНА',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: LinearProgressIndicator(
                        value: 0.48,
                        minHeight: 18,
                        backgroundColor: const Color(0xFF1C2740),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF74D96C),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Факт: ₸3 460 000',
                          style: TextStyle(
                            color: Color(0xFF93A4C3),
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'План: ₸7 200 000',
                          style: TextStyle(
                            color: Color(0xFF93A4C3),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              _Panel(
                title: 'РАСПРЕДЕЛЕНИЕ',
                child: Column(
                  children: const [
                    _SplitRow(
                      label: 'Твой заработок',
                      value: '₸620 000',
                      startColor: Color(0xFF46C2FF),
                      endColor: Color(0xFF2B72FF),
                    ),
                    SizedBox(height: 12),
                    _SplitRow(
                      label: 'Заработок Алексея',
                      value: '₸620 000',
                      startColor: Color(0xFF8B7BFF),
                      endColor: Color(0xFF5749D6),
                    ),
                    SizedBox(height: 12),
                    _SplitRow(
                      label: 'Общие расходы',
                      value: '₸200 000',
                      startColor: Color(0xFFFF7A8A),
                      endColor: Color(0xFFB8485A),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              _Panel(
                title: 'ПЛАН ПО МЕСЯЦАМ',
                child: Column(
                  children: monthlyPlan
                      .map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _MonthPlanCard(item: item),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MonthPlanItem {
  final String month;
  final String amount;
  final double progress;

  MonthPlanItem(this.month, this.amount, this.progress);
}

class _PlanTopCard extends StatelessWidget {
  final String title;
  final String value;

  const _PlanTopCard({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121B2F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF24314B),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1200A3FF),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF93A4C3),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final Widget child;

  const _Panel({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121B2F),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF24314B),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1200A3FF),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SplitRow extends StatelessWidget {
  final String label;
  final String value;
  final Color startColor;
  final Color endColor;

  const _SplitRow({
    required this.label,
    required this.value,
    required this.startColor,
    required this.endColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthPlanCard extends StatelessWidget {
  final MonthPlanItem item;

  const _MonthPlanCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final percent = (item.progress * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF18233A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF26344F),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                item.month,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                item.amount,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: item.progress,
              minHeight: 12,
              backgroundColor: const Color(0xFF101827),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF46C2FF),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$percent%',
              style: const TextStyle(
                color: Color(0xFF93A4C3),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
