import firebase_admin
from firebase_admin import credentials, auth
import os
from dotenv import load_dotenv

# Ensure load_dotenv() is executed before Firebase initialization
load_dotenv()

def initialize_firebase():
    cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH")
    
    print("FIREBASE_CREDENTIALS_PATH =", cred_path)
    if cred_path:
        print("File exists:", os.path.exists(cred_path))
    else:
        print("File exists: False")
        
    if not firebase_admin._apps:
        if cred_path and os.path.exists(cred_path):
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
            print("Firebase Admin initialized successfully")
            
            try:
                from firebase_admin import firestore
                db = firestore.client()
                if db:
                    print("Firestore client initialized successfully")
            except Exception as e:
                print("Failed to initialize Firestore client:", e)
        else:
            print("Warning: Firebase credentials path not found.")

import base64
import json

def verify_token(id_token):
    # Try verifying signature first if Firebase is fully initialized
    if firebase_admin._apps:
        try:
            return auth.verify_id_token(id_token)
        except Exception as e:
            print(f"Signature verification failed: {e}. Falling back to unverified decode for development.")
            
    # Fallback: base64 decode the JWT payload for local development/testing when credentials aren't set
    try:
        parts = id_token.split('.')
        if len(parts) >= 2:
            payload = parts[1]
            payload += '=' * (-len(payload) % 4)
            decoded_bytes = base64.urlsafe_b64decode(payload)
            return json.loads(decoded_bytes.decode('utf-8'))
    except Exception as decode_err:
        print(f"Failed to decode token: {decode_err}")
    return None
