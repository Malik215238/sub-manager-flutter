import sqlite3
from flask import Flask, jsonify, request
from flask_cors import CORS # Импортируем CORS
from werkzeug.security import generate_password_hash, check_password_hash # Для безопасности паролей
import os



app = Flask(__name__)
CORS(app) # Разрешаем запросы с любых источников (нужно для Flutter)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_NAME = os.path.join(BASE_DIR, 'subscriptions.db')


def get_db_connection():
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # 1. Создаём таблицу пользователей
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL
        )
    ''')

    # 2. Создаём таблицу подписок с привязкой к user_id
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS subscriptions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            price REAL NOT NULL,
            status TEXT NOT NULL DEFAULT 'active',
            next_payment_date TEXT NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users (id)
        )
    ''')
    
    conn.commit()
    conn.close()
    print("✅ База данных инициализирована")

init_db()

# ==================== АВТОРИЗАЦИЯ ====================

@app.route('/api/register', methods=['POST'])
def register():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({"error": "Заполните все поля"}), 400

    # Хешируем пароль перед сохранением (никогда не храним пароли в открытом виде!)
    hashed_pw = generate_password_hash(password)

    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        cursor.execute('INSERT INTO users (username, password_hash) VALUES (?, ?)', (username, hashed_pw))
        conn.commit()
        new_id = cursor.lastrowid
        return jsonify({"user_id": new_id, "username": username}), 201
    except sqlite3.IntegrityError:
        return jsonify({"error": "Пользователь с таким именем уже существует"}), 409
    finally:
        conn.close()

@app.route('/api/login', methods=['POST'])
def login():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')

    conn = get_db_connection()
    user = conn.execute('SELECT * FROM users WHERE username = ?', (username,)).fetchone()
    conn.close()

    # Проверяем существование пользователя и совпадение хеша пароля
    if user and check_password_hash(user['password_hash'], password):
        return jsonify({"user_id": user['id'], "username": user['username']}), 200
    
    return jsonify({"error": "Неверный логин или пароль"}), 401

# ==================== ПОДПИСКИ (С УЧЁТОМ USER_ID) ====================

@app.route('/api/subscriptions', methods=['GET'])
def get_subscriptions():
    # Получаем user_id из параметров запроса (?user_id=1)
    user_id = request.args.get('user_id')
    if not user_id:
        return jsonify({"error": "Требуется user_id"}), 400

    conn = get_db_connection()
    # Выбираем только подписки конкретного пользователя
    subscriptions = conn.execute('SELECT * FROM subscriptions WHERE user_id = ?', (user_id,)).fetchall()
    conn.close()
    
    result = [dict(sub) for sub in subscriptions]
    return jsonify(result), 200

@app.route('/api/subscriptions', methods=['POST'])
def add_subscription():
    data = request.get_json()
    # Обязательно требуем user_id, name, price и дату
    required_fields = ["user_id", "name", "price", "next_payment_date"]
    if not data or not all(k in data for k in required_fields):
        return jsonify({"error": "Неверные данные"}), 400

    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute(
        'INSERT INTO subscriptions (user_id, name, price, status, next_payment_date) VALUES (?, ?, ?, ?, ?)',
        (data["user_id"], data["name"], float(data["price"]), "active", data["next_payment_date"])
    )
    
    conn.commit()
    new_id = cursor.lastrowid
    
    new_sub = {
        "id": new_id,
        "user_id": data["user_id"],
        "name": data["name"],
        "price": float(data["price"]),
        "status": "active",
        "next_payment_date": data["next_payment_date"]
    }
    
    conn.close()
    return jsonify(new_sub), 201

@app.route('/api/subscriptions/<int:sub_id>', methods=['DELETE'])
def delete_subscription(sub_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Удаляем по ID (в реальном проекте тут тоже стоит проверить user_id для безопасности)
    cursor.execute('DELETE FROM subscriptions WHERE id = ?', (sub_id,))
    conn.commit()
    conn.close()
    
    return jsonify({"message": "Удалено"}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)