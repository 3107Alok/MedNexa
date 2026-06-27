from pymongo import MongoClient, ASCENDING, DESCENDING
import gridfs
import os
from dotenv import load_dotenv

load_dotenv()

mongo_uri = os.getenv("MONGO_URI")
if not mongo_uri:
    raise ValueError("MONGO_URI not found in environment variables")

client = MongoClient(mongo_uri)
db_name = os.getenv("DB_NAME", "medinexa")
db = client.get_database(db_name)
fs = gridfs.GridFS(db)

# Create/ensure indexes on storage_metadata
metadata_collection = db["storage_metadata"]
metadata_collection.create_index([("patientId", ASCENDING)])
metadata_collection.create_index([("bookingId", ASCENDING)])
metadata_collection.create_index([("createdAt", DESCENDING)])

def get_db():
    return db

def get_gridfs():
    return fs

def get_metadata_collection():
    return metadata_collection
