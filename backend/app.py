from flask import Flask, jsonify
from flask_cors import CORS

app = Flask(__name__)
# Этот пункт разрешает любым устройствам (и эмуляторам) подключаться к серверу
CORS(app)

@app.route('/api/subscriptions', methods=['GET'])
def get_subscriptions():
    # Это тестовый список подписок, который наше приложение скачает позже
    test_data = [
        {"id": 1, "name": "Netflix", "price": 10.99, "status": "active"},
        {"id": 2, "name": "Spotify", "price": 5.99, "status": "active"},
        {"id": 3, "name": "YouTube Premium", "price": 11.99, "status": "expired"}
    ]
    return jsonify(test_data)

if __name__ == '__main__':
    # host='0.0.0.0' ЖЕСТКО НЕОБХОДИМ, чтобы сервер был виден снаружи компьютера (для телефона)
    app.run(debug=True, host='0.0.0.0', port=5000)
