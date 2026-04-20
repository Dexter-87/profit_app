import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09101D),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'АНАЛИТИКА ПРОДАЖ',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
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
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                const SizedBox(height: 20),

                // Главный акцент
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 22,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121B2F),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: const Color(0xFF24314B),
                      width: 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2200A3FF),
                        blurRadius: 28,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Column(
                    children: [
                      Text(
                        '₸124 500',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Сегодня',
                        style: TextStyle(
                          color: Color(0xFF93A4C3),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.38,
                  children: const [
                    MetricCard(
                      title: 'ОБЩАЯ ПРИБЫЛЬ',
                      value: '₸1 240 000',
                      subtitle: '+11% к плану',
                      startColor: Color(0xFF74D96C),
                      endColor: Color(0xFF4C9945),
                    ),
                    MetricCard(
                      title: 'ТЫ',
                      value: '₸620 000',
                      subtitle: 'доля 50%',
                      startColor: Color(0xFF46C2FF),
                      endColor: Color(0xFF2B72FF),
                    ),
                    MetricCard(
                      title: 'АЛЕКСЕЙ',
                      value: '₸620 000',
                      subtitle: 'доля 50%',
                      startColor: Color(0xFF8B7BFF),
                      endColor: Color(0xFF5749D6),
                    ),
                    MetricCard(
                      title: 'РАСХОДЫ',
                      value: '₸200 000',
                      subtitle: '+2% за период',
                      startColor: Color(0xFFFF7A8A),
                      endColor: Color(0xFFB8485A),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                _Panel(
                  title: 'ДИНАМИКА ПРИБЫЛИ',
                  child: SizedBox(
                    height: 290,
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            RangeChip(label: 'Н'),
                            SizedBox(width: 6),
                            RangeChip(label: 'М', active: true),
                            SizedBox(width: 6),
                            RangeChip(label: 'К'),
                            SizedBox(width: 6),
                            RangeChip(label: 'Г'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: LineChart(
                            LineChartData(
                              minX: 0,
                              maxX: 5,
                              minY: 0,
                              maxY: 5,
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: 1,
                                getDrawingHorizontalLine: (value) {
                                  return const FlLine(
                                    color: Color(0xFF24314B),
                                    strokeWidth: 1,
                                  );
                                },
                              ),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: 1,
                                    getTitlesWidget: (value, meta) {
                                      const labels = [
                                        '1 нед',
                                        '2 нед',
                                        '3 нед',
                                        '4 нед',
                                        '5 нед',
                                        '6 нед',
                                      ];
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: Text(
                                          labels[value.toInt()],
                                          style: const TextStyle(
                                            color: Color(0xFF93A4C3),
                                            fontSize: 10,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              lineTouchData: LineTouchData(
                                touchTooltipData: LineTouchTooltipData(
                                  getTooltipColor: (_) => const Color(0xFF1B2640),
                                  tooltipRoundedRadius: 12,
                                  getTooltipItems: (spots) {
                                    return spots.map((spot) {
                                      return LineTooltipItem(
                                        '₸${((spot.y + 1) * 50000).toInt()}',
                                        const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );
                                    }).toList();
                                  },
                                ),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: const [
                                    FlSpot(0, 0.4),
                                    FlSpot(1, 1.7),
                                    FlSpot(2, 1.0),
                                    FlSpot(3, 3.0),
                                    FlSpot(4, 2.7),
                                    FlSpot(5, 4.2),
                                  ],
                                  isCurved: true,
                                  barWidth: 4,
                                  isStrokeCapRound: true,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF5CE1E6),
                                      Color(0xFF47B5FF),
                                      Color(0xFF7B6DFF),
                                    ],
                                  ),
                                  dotData: FlDotData(
                                    show: true,
                                    getDotPainter: (spot, percent, bar, index) {
                                      return FlDotCirclePainter(
                                        radius: 4.5,
                                        color: Colors.white,
                                        strokeWidth: 3,
                                        strokeColor: const Color(0x6647B5FF),
                                      );
                                    },
                                  ),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        const Color(0xFF47B5FF).withOpacity(0.35),
                                        const Color(0xFF47B5FF).withOpacity(0.02),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                Row(
                  children: const [
                    Expanded(
                      child: SmallInfoCard(
                        title: 'ВЫРУЧКА',
                        value: '₸3 460 000',
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: SmallInfoCard(
                        title: 'СРЕДНИЙ ЧЕК',
                        value: '₸17 300',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                const SmallInfoCard(
                  title: 'ПРОДАЖИ',
                  value: '200',
                  fullWidth: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color startColor;
  final Color endColor;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.startColor,
    required this.endColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: startColor.withOpacity(0.20),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class SmallInfoCard extends StatelessWidget {
  final String title;
  final String value;
  final bool fullWidth;

  const SmallInfoCard({
    super.key,
    required this.title,
    required this.value,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121B2F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF24314B),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            fullWidth ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF93A4C3),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
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
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class RangeChip extends StatelessWidget {
  final String label;
  final bool active;

  const RangeChip({
    super.key,
    required this.label,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF6EDC76) : const Color(0xFF1A2338),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.black : const Color(0xFF93A4C3),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
