import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // Для работы с датами и форматированием

void main() {
  runApp(const MyApp());
}

// ==================== НАСТРОЙКА ТЕМЫ (STRICT STYLE) ====================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sub Manager',
      debugShowCheckedModeBanner: false,
      // Настраиваем тёмную тему "под Сбер/Финтех"
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark, // Глобальная тёмная основа
        scaffoldBackgroundColor: const Color(0xFF121212), // Глубокий чёрный фон
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF21A038), // Изумрудно-зелёный акцент
          secondaryContainer: Color(0xFF1E1E1E), // Тёмно-серый для карточек
          surface: Color(0xFF1E1E1E),
          onSurface: Colors.white, // Белый текст
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        // Стиль для плавающей кнопки
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF21A038),
          foregroundColor: Colors.white,
        ),
      ),
      home: const SubscriptionsScreen(),
    );
  }
}

// ==================== МОДЕЛЬ ПОДПИСКИ ====================
class Subscription {
  final int id;
  final String name;
  final double price;
  final String status;
  final String nextPaymentDate;

  Subscription({
    required this.id,
    required this.name,
    required this.price,
    required this.status,
    required this.nextPaymentDate,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as int,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      status: json['status'] as String,
      nextPaymentDate: json['next_payment_date'] as String,
    );
  }
}

// ==================== ГЛАВНЫЙ ЭКРАН ====================
class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  static const String _baseUrl = 'http://10.0.2.2:5000';

  List<Subscription> _subscriptions = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  Future<void> _loadSubscriptions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/subscriptions'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _subscriptions = data.map((item) => Subscription.fromJson(item)).toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Ошибка сервера');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Нет связи с сервером';
        _isLoading = false;
      });
    }
  }

  // Логика добавления (POST)
  Future<void> _addSubscription(String name, double price, String date) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/subscriptions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'price': price, 'next_payment_date': date}),
      );
      if (response.statusCode == 201) {
        Navigator.pop(context);
        _loadSubscriptions();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  // Логика удаления (DELETE)
  Future<void> _deleteSubscription(int id) async {
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/api/subscriptions/$id'));
      if (response.statusCode == 200) _loadSubscriptions();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  // ==================== РАСЧЁТ СВОДКИ И ДАТ ====================
  
  // Считаем общую сумму всех подписок
  double get _totalAmount {
    return _subscriptions.fold(0.0, (sum, item) => sum + item.price);
  }

  // Определяем статус срочности платежа
  Map<String, dynamic> _getUrgencyStatus(String dateStr) {
    final now = DateTime.now();
    // Парсим дату из строки "YYYY-MM-DD" в объект DateTime
    final paymentDate = DateTime.parse(dateStr);
    
    // Сравниваем только даты (без времени), обнуляя время до полуночи
    final diff = paymentDate.difference(DateTime(now.year, now.month, now.day)).inDays;

    if (diff < 0) {
      return {'text': 'Просрочено', 'color': Colors.redAccent, 'border': Colors.redAccent};
    } else if (diff == 0) {
      return {'text': 'Списание сегодня', 'color': Colors.orange, 'border': Colors.orange};
    } else if (diff <= 3) {
      return {'text': 'Скоро списание', 'color': Colors.orangeAccent, 'border': Colors.orangeAccent};
    } else {
      return {'text': '', 'color': Colors.transparent, 'border': Colors.grey.shade800};
    }
  }

  // ==================== UI: ДИАЛОГ ДОБАВЛЕНИЯ ====================
  void _showAddSubscriptionDialog() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text('Новая подписка', style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Название', labelStyle: TextStyle(color: Colors.grey)),
                    ),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Цена', labelStyle: TextStyle(color: Colors.grey)),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.grey)),
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(selectedDate == null ? 'Выбрать дату' : DateFormat('yyyy-MM-dd').format(selectedDate!)),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                          builder: (context, child) {
                            // Делаем календарь тёмным
                            return Theme(data: ThemeData.dark(), child: child!);
                          },
                        );
                        if (picked != null) setDialogState(() => selectedDate = picked);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF21A038)),
                  onPressed: () {
                    if (nameController.text.isEmpty || priceController.text.isEmpty || selectedDate == null) return;
                    _addSubscription(nameController.text, double.tryParse(priceController.text) ?? 0.0, DateFormat('yyyy-MM-dd').format(selectedDate!));
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Мои подписки')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF21A038)))
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _loadSubscriptions,
                  color: const Color(0xFF21A038),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 1. СВОДНАЯ КАРТОЧКА (DASHBOARD)
                      _buildSummaryCard(),
                      const SizedBox(height: 20),
                      
                      // Заголовок списка
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 8),
                        child: Text('Активные сервисы', style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)),
                      ),

                      // 2. СПИСОК ПОДПИСОК
                      if (_subscriptions.isEmpty)
                        const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Список пуст', style: TextStyle(color: Colors.grey))))
                      else
                        ..._subscriptions.map((sub) => _buildSubscriptionCard(sub)).toList(),
                      
                      const SizedBox(height: 80), // Отступ снизу для FAB
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSubscriptionDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  // ==================== ВИДЖЕТ: СВОДНАЯ КАРТОЧКА ====================
  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF21A038).withOpacity(0.3), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Общие расходы / мес', style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '\$${_totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF21A038).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_subscriptions.length} сервисов',
                  style: const TextStyle(color: Color(0xFF21A038), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== ВИДЖЕТ: КАРТОЧКА ПОДПИСКИ ====================
  Widget _buildSubscriptionCard(Subscription sub) {
    final urgency = _getUrgencyStatus(sub.nextPaymentDate);
    final isUrgent = urgency['text'].isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        // Если срочно — красная/оранжевая рамка, иначе — тонкая серая
        border: Border.all(color: urgency['border'], width: isUrgent ? 1.5 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Иконка с первой буквой
            CircleAvatar(
              radius: 24,
              backgroundColor: isUrgent ? urgency['color'].withOpacity(0.15) : const Color(0xFF21A038).withOpacity(0.15),
              child: Text(
                sub.name[0].toUpperCase(),
                style: TextStyle(color: isUrgent ? urgency['color'] : const Color(0xFF21A038), fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sub.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  // Дата следующего списания
                  Row(
                    children: [
                      Icon(Icons.event, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(sub.nextPaymentDate, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    ],
                  ),
                  // Бейдж срочности (если есть)
                  if (isUrgent) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: urgency['color'].withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        urgency['text'],
                        style: TextStyle(color: urgency['color'], fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Цена и кнопка удаления
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('\$${sub.price.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: Colors.grey.shade600,
                  onPressed: () => _deleteSubscription(sub.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}