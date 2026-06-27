from bson.objectid import ObjectId
from datetime import datetime
from config.mongodb import get_gridfs, get_metadata_collection

def save_file(file_stream, filename, metadata):
    """
    Saves a file stream to GridFS and stores metadata in storage_metadata.
    """
    fs = get_gridfs()
    meta_coll = get_metadata_collection()
    
    # Store file in GridFS
    file_id = fs.put(file_stream, filename=filename)
    
    # Store metadata document
    metadata_doc = {
        "fileId": str(file_id),
        "patientId": metadata.get("patientId"),
        "bookingId": metadata.get("bookingId"),
        "doctorId": metadata.get("doctorId"),
        "labId": metadata.get("labId"),
        "uploadedBy": metadata.get("uploadedBy"),
        "reportType": metadata.get("reportType"),
        "documentName": metadata.get("documentName"),
        "originalFilename": filename,
        "contentType": metadata.get("contentType"),
        "fileSize": metadata.get("fileSize"),
        "createdAt": datetime.utcnow()
    }
    meta_coll.insert_one(metadata_doc)
    
    return str(file_id)

def get_file(file_id):
    """
    Retrieves the file object from GridFS.
    """
    fs = get_gridfs()
    try:
        return fs.get(ObjectId(file_id))
    except Exception:
        return None

def delete_file(file_id):
    """
    Deletes the file from GridFS and metadata collection.
    """
    fs = get_gridfs()
    meta_coll = get_metadata_collection()
    
    try:
        # Delete from GridFS
        fs.delete(ObjectId(file_id))
    except Exception as e:
        print(f"Error deleting file from GridFS: {e}")
        
    # Delete from metadata collection
    meta_coll.delete_one({"fileId": file_id})

def get_metadata(file_id):
    """
    Retrieves file metadata by fileId.
    """
    meta_coll = get_metadata_collection()
    return meta_coll.find_one({"fileId": file_id})

def get_metadata_by_query(query):
    """
    Queries the storage_metadata collection.
    """
    meta_coll = get_metadata_collection()
    # Exclude _id to make it JSON serializable
    return list(meta_coll.find(query, {"_id": 0}))
