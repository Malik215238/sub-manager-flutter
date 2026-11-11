import sqlite3
import os
from flask import Flask, jsonify, request
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# ==================== НАСТРОЙКА БАЗЫ ДАННЫХ ====================

# Имя файла базы данных. Он будет создан в той же папке, где лежит app.py
DB_NAME = 'subscriptions.db'

def get_db_connection():
    """
    Создаёт и возвращает соединение с базой данных.
    Включаем row_factory='sqlite3.Row', чтобы обращаться к колонкам по имени,
    а не по индексу (например, row['name'] вместо row[1]).
    """
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    """
    Инициализирует базу данных: создаёт таблицу, если её ещё нет.
    Вызывается один раз при запуске приложения.
    """
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # SQL-запрос на создание таблицы
    # IF NOT EXISTS гарантирует, что ошибка не возникнет, если таблица уже есть
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS subscriptions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            price REAL NOT NULL,
            status TEXT NOT NULL DEFAULT 'active',
            next_payment_date TEXT NOT NULL
        )
    ''')
    
    conn.commit()
    conn.close()
    print("✅ База данных инициализирована (файл subscriptions.db)")

# Запускаем инициализацию сразу при старте скрипта
init_db()

# ==================== МАРШРУТЫ API ====================

# 1. GET: Получить все подписки из базы
@app.route('/api/subscriptions', methods=['GET'])
def get_subscriptions():
    conn = get_db_connection()
    # Выбираем все колонки (*) из таблицы subscriptions
    subscriptions = conn.execute('SELECT * FROM subscriptions').fetchall()
    conn.close()
    
    # Превращаем объекты Row в обычные словари для JSON
    result = [dict(sub) for sub in subscriptions]
    return jsonify(result), 200

# 2. POST: Добавить новую подписку в базу
@app.route('/api/subscriptions', methods=['POST'])
def add_subscription():
    data = request.get_json()
    
    if not data or not all(k in data for k in ("name", "price", "next_payment_date")):
        return jsonify({"error": "Неверные данные"}), 400

    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Используем параметризованный запрос (?) для защиты от SQL-инъекций
    cursor.execute(
        'INSERT INTO subscriptions (name, price, status, next_payment_date) VALUES (?, ?, ?, ?)',
        (data["name"], float(data["price"]), "active", data["next_payment_date"])
    )
    
    conn.commit()
    
    # Получаем ID только что добавленной записи
    new_id = cursor.lastrowid
    
    # Формируем ответ точно в том же формате, что и раньше, чтобы Flutter не сломался
    new_sub = {
        "id": new_id,
        "name": data["name"],
        "price": float(data["price"]),
        "status": "active",
        "next_payment_date": data["next_payment_date"]
    }
    
    conn.close()
    return jsonify(new_sub), 201

# 3. DELETE: Удалить подписку из базы по ID
@app.route('/api/subscriptions/<int:sub_id>', methods=['DELETE'])
def delete_subscription(sub_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Сначала проверяем, существует ли такая запись
    cursor.execute('SELECT * FROM subscriptions WHERE id = ?', (sub_id,))
    sub = cursor.fetchone()
    
    if sub is None:
        conn.close()
        return jsonify({"error": "Подписка не найдена"}), 404
    
    # Если существует — удаляем
    cursor.execute('DELETE FROM subscriptions WHERE id = ?', (sub_id,))
    conn.commit()
    conn.close()
    
    return jsonify({"message": "Подписка успешно удалена"}), 200

if __name__ == '__main__':
    # host='0.0.0.0' обязателен для доступа из эмулятора Android
    app.run(host='0.0.0.0', port=5000, debug=True)