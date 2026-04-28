import 'package:flutter/material.dart';
import 'package:my_app/theme/app_colors.dart';

class SummaryPage extends StatefulWidget {
  const SummaryPage({super.key});

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {

  final TextEditingController stasCapital = TextEditingController(text: '1100000');
  final TextEditingController alexCapital = TextEditingController(text: '7600000');

  final TextEditingController stasWork = TextEditingController(text: '19');
  final TextEditingController alexWork = TextEditingController(text: '81');

  final TextEditingController capitalWeight = TextEditingController(text: '50');
  final TextEditingController workWeight = TextEditingController(text: '50');

  double _toDouble(String v) => double.tryParse(v) ?? 0;

  double get totalCapital => _toDouble(stasCapital.text) + _toDouble(alexCapital.text);
  double get totalWork => _toDouble(stasWork.text) + _toDouble(alexWork.text);

  double get stasCapitalShare => totalCapital == 0 ? 0 : _toDouble(stasCapital.text) / totalCapital;
  double get stasWorkShare => totalWork == 0 ? 0 : _toDouble(stasWork.text) / totalWork;

  double get finalStasShare {
    final cWeight = _toDouble(capitalWeight.text) / 100;
    final wWeight = _toDouble(workWeight.text) / 100;
    return (stasCapitalShare * cWeight) + (stasWorkShare * wWeight);
  }

  Widget _input(String label, TextEditingController controller) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            TextField(
              controller: controller,
              style: const TextStyle(color: AppColors.textMain),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                border: InputBorder.none,
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _section(String title, Widget child, Color accent) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.textMain,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          child
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    final stasPercent = (finalStasShare * 100).toStringAsFixed(1);
    final alexPercent = (100 - finalStasShare * 100).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text(
          'Настройки распределения',
          style: TextStyle(
            color: AppColors.textMain,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [

          _section(
            'Вложения',
            Row(
              children: [
                _input('Стас', stasCapital),
                const SizedBox(width: 10),
                _input('Алексей', alexCapital),
              ],
            ),
            Colors.blue,
          ),

          const SizedBox(height: 16),

          _section(
            'Работа (баллы)',
            Row(
              children: [
                _input('Стас', stasWork),
                const SizedBox(width: 10),
                _input('Алексей', alexWork),
              ],
            ),
            Colors.orange,
          ),

          const SizedBox(height: 16),

          _section(
            'Веса модели (%)',
            Row(
              children: [
                _input('Капитал', capitalWeight),
                const SizedBox(width: 10),
                _input('Работа', workWeight),
              ],
            ),
            Colors.purple,
          ),

          const SizedBox(height: 16),

          _section(
            'Итоговое распределение',
            Column(
              children: [
                Text(
                  'Стас: $stasPercent%',
                  style: const TextStyle(
                      color: Colors.green,
                      fontSize: 18,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Алексей: $alexPercent%',
                  style: const TextStyle(
                      color: AppColors.textMain,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
            Colors.green,
          ),
        ],
      ),
    );
  }
}
