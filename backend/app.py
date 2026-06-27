from flask import Flask, jsonify
from pymongo import MongoClient
from flask_cors import CORS
from routes import api_blueprint
from routes.storage_routes import storage_blueprint
from firebase_config import initialize_firebase
import os
from dotenv import load_dotenv

load_dotenv()

# MongoDB Configuration
MONGO_URI = os.getenv("MONGO_URI")
DB_NAME = os.getenv("DB_NAME", "medinexa")

mongo_client = MongoClient(MONGO_URI)
db = mongo_client[DB_NAME]

try:
    mongo_client.admin.command("ping")
    print("MongoDB Atlas Connected Successfully")
except Exception as e:
    print(f"MongoDB Connection Error: {e}")

app = Flask(__name__)
CORS(app)
initialize_firebase()
app.register_blueprint(api_blueprint, url_prefix='/api')
app.register_blueprint(storage_blueprint, url_prefix='/api/storage')

@app.route('/')
def index():
    return jsonify({"message": "MediNexa Backend API is running", "status": "success"})

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=True)
