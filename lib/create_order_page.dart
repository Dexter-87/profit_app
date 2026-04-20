import 'package:flutter/material.dart';

class CreateOrderPage extends StatefulWidget {
  const CreateOrderPage({super.key});

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  final TextEditingController productController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController commentController = TextEditingController();

  String selectedChannel = 'Каспий';

  @override
  void dispose() {
    productController.dispose();
    quantityController.dispose();
    priceController.dispose();
    commentController.dispose();
    super.dispose();
  }

  void saveOrder() {
    final product = productController.text.trim();
    final quantity = quantityController.text.trim();
    final price = priceController.text.trim();
    final comment = commentController.text.trim();

    if (product.isEmpty || quantity.isEmpty || price.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заполни товар, количество и цену'),
          backgroundColor: Color(0xFFB8485A),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF121B2F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Заказ сохранён',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Канал: $selectedChannel\n'
          'Товар: $product\n'
          'Количество: $quantity\n'
          'Цена: $price\n'
          'Комментарий: ${comment.isEmpty ? "—" : comment}',
          style: const TextStyle(
            color: Color(0xFF93A4C3),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text(
              'ОК',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09101D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'СОЗДАТЬ ЗАКАЗ',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Канал продаж',
                      style: TextStyle(
                        color: Color(0xFF93A4C3),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ChannelButton(
                            title: 'Каспий',
                            active: selectedChannel == 'Каспий',
                            onTap: () {
                              setState(() {
                                selectedChannel = 'Каспий';
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ChannelButton(
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
              const SizedBox(height: 16),
              _buildPanel(
                child: Column(
                  children: [
                    _buildField(
                      controller: productController,
                      label: 'Товар',
                      hint: 'Например: Thermex IF 80',
                      icon: Icons.inventory_2_rounded,
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      controller: quantityController,
                      label: 'Количество',
                      hint: 'Например: 2',
                      icon: Icons.format_list_numbered_rounded,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      controller: priceController,
                      label: 'Цена',
                      hint: 'Например: 85000',
                      icon: Icons.payments_rounded,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      controller: commentController,
                      label: 'Комментарий',
                      hint: 'Например: +',
                      icon: Icons.comment_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF46C2FF),
                      Color(0xFF2B72FF),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF46C2FF).withOpacity(0.28),
                      blurRadius: 22,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: saveOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'СОХРАНИТЬ ЗАКАЗ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPanel({required Widget child}) {
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
      child: child,
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFF93A4C3)),
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Color(0xFF93A4C3)),
        hintStyle: const TextStyle(color: Color(0xFF5E6E8C)),
        filled: true,
        fillColor: const Color(0xFF18233A),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF26344F)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFF46C2FF),
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

class _ChannelButton extends StatelessWidget {
  final String title;
  final bool active;
  final VoidCallback onTap;

  const _ChannelButton({
    required this.title,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    colors: [
                      Color(0xFF74D96C),
                      Color(0xFF4C9945),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: active ? null : const Color(0xFF18233A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? Colors.transparent : const Color(0xFF26344F),
            ),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
