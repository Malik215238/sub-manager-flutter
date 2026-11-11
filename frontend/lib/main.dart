import 'dart:convert'; // Для работы с JSON (преобразование строк в объекты)
import 'package:flutter/material.dart'; // Основная библиотека Flutter
import 'package:http/http.dart' as http; // HTTP-клиент для сетевых запросов

// ==================== ТОЧКА ВХОДА В ПРИЛОЖЕНИЕ ====================
void main() {
  // runApp запускает приложение. MyApp — корневой виджет.
  runApp(const MyApp());
}

// ==================== КОРНЕВОЙ ВИДЖЕТ ====================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Менеджер подписок',
      debugShowCheckedModeBanner: false, // Убирает баннер DEBUG в углу
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true, // Включаем Material Design 3
      ),
      home: const SubscriptionsScreen(), // Главный экран приложения
    );
  }
}

// ==================== МОДЕЛЬ ПОДПИСКИ ====================
// Класс, описывающий одну подписку. Нужен, чтобы работать с объектами,
// а не с "сырым" JSON-словарём.
class Subscription {
  final int id;
  final String name;
  final double price;
  final String status;

  Subscription({
    required this.id,
    required this.name,
    required this.price,
    required this.status,
  });

  // Фабричный метод: создаёт объект Subscription из JSON-словаря
  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as int,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(), // num -> double (безопаснее)
      status: json['status'] as String,
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
  // IP-адрес твоего компьютера с точки зрения Android-эмулятора.
  // 10.0.2.2 — это специальный alias, который эмулятор перенаправляет
  // на localhost хост-машины (твоего Windows-компьютера).
  static const String _baseUrl = 'http://10.0.2.2:5000';

  // Метод, который делает GET-запрос к Flask и возвращает список подписок.
  // async — означает, что метод асинхронный (не блокирует UI).
  // Future<List<Subscription>> — метод вернёт список подписок "в будущем".
  Future<List<Subscription>> fetchSubscriptions() async {
    // 1. Формируем полный URL эндпоинта
    final Uri url = Uri.parse('$_baseUrl/api/subscriptions');

    // 2. Делаем HTTP GET-запрос. await ждёт ответ от сервера.
    final http.Response response = await http.get(url);

    // 3. Проверяем, что сервер вернул успешный код (200 OK)
    if (response.statusCode == 200) {
      // 4. Декодируем JSON-строку в Dart-объект (List<dynamic>)
      final List<dynamic> data = jsonDecode(response.body);

      // 5. Превращаем каждый JSON-словарь в объект Subscription
      return data
          .map((item) => Subscription.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      // Если сервер вернул ошибку — выбрасываем исключение
      throw Exception('Ошибка сервера: ${response.statusCode}');
    }
  }

  // Вспомогательный метод: возвращает цвет для статуса подписки
  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'paused':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Вспомогательный метод: возвращает читаемое название статуса
  String _getStatusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Активна';
      case 'paused':
        return 'Приостановлена';
      case 'cancelled':
        return 'Отменена';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои подписки'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      // FutureBuilder — виджет, который ждёт результат асинхронной операции
      // (нашего HTTP-запроса) и в зависимости от состояния строит UI.
      body: FutureBuilder<List<Subscription>>(
        future: fetchSubscriptions(), // Что ждём
        builder: (context, snapshot) {
          // snapshot.connectionState — текущее состояние запроса
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Пока данные грузятся — показываем индикатор загрузки
            return const Center(child: CircularProgressIndicator());
          }

          // Если произошла ошибка — показываем её
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Ошибка: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // Если данных нет (пустой список)
          final subscriptions = snapshot.data ?? [];
          if (subscriptions.isEmpty) {
            return const Center(
              child: Text(
                'Подписок пока нет',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          // Если всё ок — строим список подписок
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: subscriptions.length,
            itemBuilder: (context, index) {
              final sub = subscriptions[index];
              return _buildSubscriptionCard(sub);
            },
          );
        },
      ),
    );
  }

  // Метод, строящий красивую карточку для одной подписки
  Widget _buildSubscriptionCard(Subscription sub) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 2, // Лёгкая тень для объёма
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Круглая иконка слева с первой буквой названия
            CircleAvatar(
              radius: 24,
              backgroundColor:
                  Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                sub.name.isNotEmpty ? sub.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Название и статус
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sub.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Маленький "бейдж" со статусом
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(sub.status).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getStatusLabel(sub.status),
                      style: TextStyle(
                        color: _getStatusColor(sub.status),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Цена справа
            Text(
              '\$${sub.price.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}