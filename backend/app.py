from flask import Flask, jsonify, request

app = Flask(__name__)

# Храним подписки в памяти (в будущем заменим на базу данных)
# Добавили поле next_payment_date в формате "YYYY-MM-DD"
subscriptions = [
    {
        "id": 1, 
        "name": "Netflix", 
        "price": 10.99, 
        "status": "active", 
        "next_payment_date": "2026-11-25"
    },
    {
        "id": 2, 
        "name": "Spotify", 
        "price": 5.99, 
        "status": "active", 
        "next_payment_date": "2026-12-01"
    }
]

# 1. GET: Получить все подписки
@app.route('/api/subscriptions', methods=['GET'])
def get_subscriptions():
    return jsonify(subscriptions), 200

# 2. POST: Создать новую подписку
@app.route('/api/subscriptions', methods=['POST'])
def add_subscription():
    # Получаем JSON-данные из тела запроса
    data = request.get_json()
    
    # Простая валидация: проверяем, что все нужные поля переданы
    if not data or not all(k in data for k in ("name", "price", "next_payment_date")):
        return jsonify({"error": "Неверные данные. Требуются name, price и next_payment_date"}), 400

    # Генерируем новый ID: берём максимальный существующий ID и прибавляем 1.
    # Если список пуст, max() вернёт default=0, и новый ID будет 1.
    new_id = max((sub["id"] for sub in subscriptions), default=0) + 1
    
    new_sub = {
        "id": new_id,
        "name": data["name"],
        "price": float(data["price"]), # Гарантируем, что цена — число
        "status": "active",            # По умолчанию новая подписка активна
        "next_payment_date": data["next_payment_date"]
    }
    
    subscriptions.append(new_sub)
    # Возвращаем созданную подписку и статус 201 (Created)
    return jsonify(new_sub), 201

# 3. DELETE: Удалить подписку по ID
@app.route('/api/subscriptions/<int:sub_id>', methods=['DELETE'])
def delete_subscription(sub_id):
    global subscriptions # Объявляем, что будем изменять глобальный список
    
    # Ищем подписку с таким ID
    sub_to_delete = next((sub for sub in subscriptions if sub["id"] == sub_id), None)
    
    if sub_to_delete:
        subscriptions.remove(sub_to_delete)
        return jsonify({"message": "Подписка успешно удалена"}), 200
    
    # Если подписка с таким ID не найдена
    return jsonify({"error": "Подписка не найдена"}), 404

if __name__ == '__main__':
    # host='0.0.0.0' обязателен, чтобы эмулятор Android мог достучаться до сервера
    app.run(host='0.0.0.0', port=5000, debug=True)