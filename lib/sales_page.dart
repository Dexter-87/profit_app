import 'package:flutter/material.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final TextEditingController searchController = TextEditingController();

  String selectedChannel = 'Все';

  final List<SaleItem> allSales = [
    SaleItem(
      product: 'Thermex IF 80',
      channel: 'Каспий',
      amount: 85000,
      date: '20.04.2026',
    ),
    SaleItem(
      product: 'Ariston ABS VLS',
      channel: 'ОПТ',
      amount: 120000,
      date: '20.04.2026',
    ),
    SaleItem(
      product: 'Garanterm Flat 50',
      channel: 'Каспий',
      amount: 73000,
      date: '19.04.2026',
    ),
    SaleItem(
      product: 'Edison ER 80',
      channel: 'ОПТ',
      amount: 92000,
      date: '19.04.2026',
    ),
    SaleItem(
      product: 'Etalon ES 50',
      channel: 'Каспий',
      amount: 61000,
      date: '18.04.2026',
    ),
  ];

  List<SaleItem> get filteredSales {
    final query = searchController.text.trim().toLowerCase();

    return allSales.where((sale) {
      final channelMatch =
          selectedChannel == 'Все' || sale.channel == selectedChannel;

      final productMatch = sale.product.toLowerCase().contains(query);

      return channelMatch && productMatch;
    }).toList();
  }

  int get totalSalesCount => filteredSales.length;

  int get totalSalesAmount =>
      filteredSales.fold(0, (sum, item) => sum + item.amount);

  String formatMoney(int value) {
    final text = value.toString();
    final buffer = StringBuffer();
    int counter = 0;

    for (int i = text.length - 1; i >= 0; i--) {
      buffer.write(text[i]);
      counter++;
      if (counter % 3 == 0 && i != 0) {
        buffer.write(' ');
      }
    }

    return '₸${buffer.toString().split('').reversed.join()}';
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sales = filteredSales;

    return Scaffold(
      backgroundColor: const Color(0xFF09101D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'ПРОДАЖИ',
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _TopInfoCard(
                          title: 'ВСЕГО ПРОДАЖ',
                          value: '$totalSalesCount',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TopInfoCard(
                          title: 'СУММА',
                          value: formatMoney(totalSalesAmount),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _FilterPanel(
                    child: Column(
                      children: [
                        TextField(
                          controller: searchController,
                          onChanged: (_) {
                            setState(() {});
                          },
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Color(0xFF93A4C3),
                            ),
                            hintText: 'Поиск по товару',
                            hintStyle: const TextStyle(
                              color: Color(0xFF5E6E8C),
                            ),
                            filled: true,
                            fillColor: const Color(0xFF18233A),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFF26344F),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFF46C2FF),
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _ChannelFilterChip(
                                title: 'Все',
                                active: selectedChannel == 'Все',
                                onTap: () {
                                  setState(() {
                                    selectedChannel = 'Все';
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _ChannelFilterChip(
                                title: 'Каспий',
                                active: selectedChannel == 'Каспий',
                                onTap: () {
                                  setState(() {
                                    selectedChannel = 'Каспий';
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _ChannelFilterChip(
                                title: 'ОПТ',
                                active: selectedChannel == 'ОПТ',
                                onTap: () {
                                  setState(() {
                                    selectedChannel = 'ОПТ';
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: sales.isEmpty
                  ? const Center(
                      child: Text(
                        'Ничего не найдено',
                        style: TextStyle(
                          color: Color(0xFF93A4C3),
                          fontSize: 16,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      itemCount: sales.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = sales[index];
                        return _SaleCard(
                          item: item,
                          formattedAmount: formatMoney(item.amount),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class SaleItem {
  final String product;
  final String channel;
  final int amount;
  final String date;

  SaleItem({
    required this.product,
    required this.channel,
    required this.amount,
    required this.date,
  });
}

class _TopInfoCard extends StatelessWidget {
  final String title;
  final String value;

  const _TopInfoCard({
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
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  final Widget child;

  const _FilterPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF121B2F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF24314B),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}

class _ChannelFilterChip extends StatelessWidget {
  final String title;
  final bool active;
  final VoidCallback onTap;

  const _ChannelFilterChip({
    required this.title,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isKaspi = title == 'Каспий';
    final isOpt = title == 'ОПТ';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: active
                ? LinearGradient(
                    colors: title == 'Все'
                        ? const [
                            Color(0xFF8B7BFF),
                            Color(0xFF5749D6),
                          ]
                        : isKaspi
                            ? const [
                                Color(0xFF74D96C),
                                Color(0xFF4C9945),
                              ]
                            : isOpt
                                ? const [
                                    Color(0xFF46C2FF),
                                    Color(0xFF2B72FF),
                                  ]
                                : const [
                                    Color(0xFF46C2FF),
                                    Color(0xFF2B72FF),
                                  ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: active ? null : const Color(0xFF18233A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? Colors.transparent : const Color(0xFF26344F),
            ),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SaleCard extends StatelessWidget {
  final SaleItem item;
  final String formattedAmount;

  const _SaleCard({
    required this.item,
    required this.formattedAmount,
  });

  @override
  Widget build(BuildContext context) {
    final isKaspi = item.channel == 'Каспий';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121B2F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF24314B),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.product,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isKaspi
                        ? const [
                            Color(0xFF74D96C),
                            Color(0xFF4C9945),
                          ]
                        : const [
                            Color(0xFF46C2FF),
                            Color(0xFF2B72FF),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  item.channel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                formattedAmount,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.date,
            style: const TextStyle(
              color: Color(0xFF93A4C3),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
