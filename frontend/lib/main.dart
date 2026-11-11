import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // Для форматирования даты (yyyy-MM-dd)

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Менеджер подписок',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
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
  final String nextPaymentDate; // Новое поле: дата следующего списания

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
    _loadSubscriptions(); // Загружаем данные при первом открытии экрана
  }

  // Метод для загрузки списка и обновления состояния экрана
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
        throw Exception('Ошибка сервера: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Не удалось подключиться к серверу. Проверьте, запущен ли Flask.';
        _isLoading = false;
      });
    }
  }

  // Метод для ОТПРАВКИ POST-запроса (создание)
  Future<void> _addSubscription(String name, double price, String date) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/subscriptions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'price': price,
          'next_payment_date': date,
        }),
      );

      if (response.statusCode == 201) {
        // Если успешно, закрываем диалог и перезагружаем список
        Navigator.pop(context);
        _loadSubscriptions();
      } else {
        throw Exception('Ошибка при создании: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Метод для ОТПРАВКИ DELETE-запроса (удаление)
  Future<void> _deleteSubscription(int id) async {
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/api/subscriptions/$id'));
      if (response.statusCode == 200) {
        _loadSubscriptions(); // Перезагружаем список после успешного удаления
      } else {
        throw Exception('Ошибка при удалении');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ==================== ДИАЛОГ ДОБАВЛЕНИЯ ====================
  void _showAddSubscriptionDialog() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    DateTime? selectedDate; // Хранит выбранную дату

    showDialog(
      context: context,
      builder: (context) {
        // StatefulBuilder нужен, чтобы обновлять текст кнопки с датой 
        // внутри открытого диалога, не закрывая его.
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Новая подписка'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Название (напр. Netflix)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Цена (напр. 10.99)'),
                    ),
                    const SizedBox(height: 12),
                    // Кнопка выбора даты
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        selectedDate == null
                            ? 'Выбрать дату списания'
                            : DateFormat('yyyy-MM-dd').format(selectedDate!),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                        );
                        if (picked != null) {
                          // Обновляем состояние ТОЛЬКО внутри диалога
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context), // Закрыть без сохранения
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Простая валидация перед отправкой
                    if (nameController.text.isEmpty || priceController.text.isEmpty || selectedDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Заполните все поля и выберите дату')),
                      );
                      return;
                    }
                    
                    final price = double.tryParse(priceController.text) ?? 0.0;
                    final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate!);
                    
                    // Вызываем метод отправки POST-запроса
                    _addSubscription(nameController.text, price, formattedDate);
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
      appBar: AppBar(
        title: const Text('Мои подписки'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                  ),
                )
              : _subscriptions.isEmpty
                  ? const Center(child: Text('Подписок пока нет. Добавьте первую!'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _subscriptions.length,
                      itemBuilder: (context, index) {
                        final sub = _subscriptions[index];
                        return _buildSubscriptionCard(sub);
                      },
                    ),
      // Плавающая кнопка "+" для добавления
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSubscriptionDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  // ==================== КАРТОЧКА ПОДПИСКИ ====================
  Widget _buildSubscriptionCard(Subscription sub) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                sub.name.isNotEmpty ? sub.name[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sub.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  // Отображение даты следующего списания
                  Row(
                    children: [
                      const Icon(Icons.event, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        'Списание: ${sub.nextPaymentDate}',
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Блок с ценой и кнопкой удаления
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${sub.price.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                // Иконка корзины для DELETE-запроса
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _deleteSubscription(sub.id),
                  tooltip: 'Удалить подписку',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}