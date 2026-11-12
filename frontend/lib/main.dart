import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

// ==================== НАСТРОЙКА ТЕМЫ ====================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sub Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF21A038),
          secondaryContainer: Color(0xFF1E1E1E),
          surface: Color(0xFF1E1E1E),
          onSurface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          elevation: 0,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF21A038),
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A2A2A),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          labelStyle: const TextStyle(color: Colors.grey),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

// ==================== УПРАВЛЕНИЕ СЕССИЕЙ (AuthWrapper) ====================
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  int? _userId;
  String? _username;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getInt('user_id');
      _username = prefs.getString('username');
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('username');
    setState(() {
      _userId = null;
      _username = null;
    });
  }

  void _onAuthSuccess() {
    _checkLoginStatus();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF21A038))));
    }

    if (_userId != null && _username != null) {
      return SubscriptionsScreen(
        userId: _userId!,
        username: _username!,
        onLogout: _logout,
      );
    }

    return AuthScreen(onAuthSuccess: _onAuthSuccess);
  }
}

// ==================== ЭКРАН ВХОДА / РЕГИСТРАЦИИ ====================
class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthSuccess;

  const AuthScreen({super.key, required this.onAuthSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  static const String _baseUrl = 'https://sub-manager-malik78.msk1.amvera.tech';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final url = _isLogin ? '$_baseUrl/api/login' : '$_baseUrl/api/register';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _usernameController.text.trim(),
          'password': _passwordController.text,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('user_id', data['user_id'] as int);
        await prefs.setString('username', data['username'] as String);

        if (mounted) {
          widget.onAuthSuccess();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['error'] ?? 'Ошибка авторизации'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сети: проверьте, запущен ли сервер'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 64, color: Color(0xFF21A038)),
                const SizedBox(height: 16),
                const Text(
                  'Sub Manager',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF21A038)),
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _usernameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Логин', prefixIcon: Icon(Icons.person, color: Colors.grey)),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Введите логин' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Пароль', prefixIcon: Icon(Icons.lock, color: Colors.grey)),
                  validator: (v) => v == null || v.isEmpty ? 'Введите пароль' : null,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF21A038),
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(_isLogin ? 'Войти' : 'Зарегистрироваться'),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(
                    _isLogin ? 'Нет аккаунта? Создать' : 'Уже есть аккаунт? Войти',
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
  final int userId;
  final String username;
  final VoidCallback onLogout;

  const SubscriptionsScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.onLogout,
  });

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  static const String _baseUrl = 'https://sub-manager-malik78.msk1.amvera.tech';
  List<Subscription> _subscriptions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  Future<void> _loadSubscriptions() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/subscriptions?user_id=${widget.userId}'));
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
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось загрузить данные'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addSubscription(String name, double price, String date) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/subscriptions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userId,
          'name': name,
          'price': price,
          'next_payment_date': date,
        }),
      );
      if (response.statusCode == 201) {
        if (mounted) Navigator.pop(context);
        _loadSubscriptions();
      } else {
        throw Exception('Ошибка создания');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteSubscription(int id) async {
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/api/subscriptions/$id'));
      if (response.statusCode == 200) {
        _loadSubscriptions();
      } else {
        throw Exception('Ошибка удаления');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  double get _totalAmount => _subscriptions.fold(0.0, (sum, item) => sum + item.price);

  Map<String, dynamic> _getUrgencyStatus(String dateStr) {
    final now = DateTime.now();
    final paymentDate = DateTime.parse(dateStr);
    final diff = paymentDate.difference(DateTime(now.year, now.month, now.day)).inDays;

    if (diff < 0) return {'text': 'Просрочено', 'color': Colors.redAccent, 'border': Colors.redAccent};
    if (diff == 0) return {'text': 'Списание сегодня', 'color': Colors.orange, 'border': Colors.orange};
    if (diff <= 3) return {'text': 'Скоро списание', 'color': Colors.orangeAccent, 'border': Colors.orangeAccent};
    return {'text': '', 'color': Colors.transparent, 'border': Colors.grey.shade800};
  }

  void _showAddDialog() {
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
                      decoration: const InputDecoration(labelText: 'Название'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      // Подсказка теперь с символом рубля
                      decoration: const InputDecoration(labelText: 'Цена (₽)'),
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
                          builder: (context, child) => Theme(data: ThemeData.dark(), child: child!),
                        );
                        if (picked != null) setDialogState(() => selectedDate = picked);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF21A038), foregroundColor: Colors.white),
                  onPressed: () {
                    if (nameController.text.isEmpty || priceController.text.isEmpty || selectedDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заполните все поля')));
                      return;
                    }
                    _addSubscription(
                      nameController.text,
                      double.tryParse(priceController.text) ?? 0.0,
                      DateFormat('yyyy-MM-dd').format(selectedDate!),
                    );
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
        title: Text('Привет, ${widget.username}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: widget.onLogout,
            tooltip: 'Выйти из аккаунта',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF21A038)))
          : RefreshIndicator(
              onRefresh: _loadSubscriptions,
              color: const Color(0xFF21A038),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSummaryCard(),
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 8),
                    child: Text('Активные сервисы', style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)),
                  ),
                  if (_subscriptions.isEmpty)
                    const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Список пуст', style: TextStyle(color: Colors.grey))))
                  else
                    ..._subscriptions.map((sub) => _buildCard(sub)).toList(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  // ==================== СВОДНАЯ КАРТОЧКА (с рублём) ====================
  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF21A038).withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Общие расходы / мес', style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Знак рубля после суммы с пробелом
              Text(
                '${_totalAmount.toStringAsFixed(2)} ₽',
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

  // ==================== КАРТОЧКА ПОДПИСКИ (с рублём) ====================
  Widget _buildCard(Subscription sub) {
    final urgency = _getUrgencyStatus(sub.nextPaymentDate);
    final isUrgent = urgency['text'].isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: urgency['border'], width: isUrgent ? 1.5 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: isUrgent ? urgency['color'].withOpacity(0.15) : const Color(0xFF21A038).withOpacity(0.15),
              child: Text(
                sub.name[0].toUpperCase(),
                style: TextStyle(
                  color: isUrgent ? urgency['color'] : const Color(0xFF21A038),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sub.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.event, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(sub.nextPaymentDate, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    ],
                  ),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Знак рубля после суммы с пробелом
                Text(
                  '${sub.price.toStringAsFixed(2)} ₽',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
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