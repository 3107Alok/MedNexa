from flask import Blueprint, request, jsonify, Response
import os
import logging
from bson.objectid import ObjectId
from firebase_admin import firestore
from routes import token_required
from models import UserModel
from db import get_db
from services import storage_service

# Configure Logger for Auditing
logging.basicConfig(level=logging.INFO)
audit_logger = logging.getLogger("STORAGE_AUDIT")

storage_blueprint = Blueprint('storage', __name__)

def get_firestore_client():
    try:
        return firestore.client()
    except Exception as e:
        audit_logger.error(f"Failed to get Firestore client: {e}")
        return None

def get_user_role_from_firestore(uid):
    fs_client = get_firestore_client()
    role = None
    allowed_roles = ['lab', 'labOwner', 'labowner', 'doctor', 'patient', 'admin']
    
    if not fs_client:
        print("Firestore client not available")
        print("UID:", uid)
        print("Firestore document exists: False (client unavailable)")
        print("Firestore data: None")
        print("Resolved role: None")
        print("Allowed roles:", allowed_roles)
        return None
        
    doc_ref = fs_client.collection('users').document(uid)
    doc = doc_ref.get()
    
    if doc.exists:
        role = doc.to_dict().get('role')
        
    print("UID:", uid)
    print("Firestore document exists:", doc.exists)
    print("Firestore data:", doc.to_dict() if doc.exists else None)
    print("Resolved role:", role)
    print("Allowed roles:", allowed_roles)
    
    return role

@storage_blueprint.route('/upload', methods=['POST'])
@token_required
def upload_file():
    try:
        # Check if file is in request
        if 'file' not in request.files:
            return jsonify({"error": "No file part in the request"}), 400
            
        file = request.files['file']
        if file.filename == '':
            return jsonify({"error": "No selected file"}), 400
            
        # 1. Extension Check
        filename = file.filename
        ext = filename.rsplit('.', 1)[1].lower() if '.' in filename else ''
        allowed_extensions = ['pdf', 'jpg', 'jpeg', 'png']
        if ext not in allowed_extensions:
            return jsonify({"error": "Only PDF, JPG, JPEG, and PNG files are allowed"}), 400
            
        # 2. Content-Type Check
        allowed_mimetypes = ['application/pdf', 'image/jpeg', 'image/png']
        if file.content_type not in allowed_mimetypes:
            return jsonify({"error": "MIME type must be application/pdf, image/jpeg, or image/png"}), 400
            
        # 3. Magic Bytes Verification
        first_bytes = file.read(4)
        file.seek(0)
        is_pdf = first_bytes.startswith(b'%PDF')
        is_jpeg = first_bytes.startswith(b'\xff\xd8\xff')
        is_png = first_bytes.startswith(b'\x89PNG')
        if not (is_pdf or is_jpeg or is_png):
            return jsonify({"error": "Invalid file content. The file must be a valid PDF or Image."}), 400
            
        # 4. Enforce max 10MB size limit
        file.seek(0, os.SEEK_END)
        size = file.tell()
        file.seek(0)
        if size > 10 * 1024 * 1024:
            return jsonify({"error": "File size exceeds the 10MB limit"}), 400
            
        # Extract metadata
        patient_id = request.form.get('patientId')
        booking_id = request.form.get('bookingId')
        doctor_id = request.form.get('doctorId')
        lab_id = request.form.get('labId')
        report_type = request.form.get('reportType')
        
        if not patient_id:
            return jsonify({"error": "patientId is required"}), 400
        if not report_type:
            return jsonify({"error": "reportType is required"}), 400
            
        uploader_uid = request.user['uid']
        uploader_role = get_user_role_from_firestore(uploader_uid)
        
        print("Authenticated user:", request.user)
        print("Resolved role:", uploader_role)
        
        normalized_role = (uploader_role or '').lower()
        is_lab_role = normalized_role.startswith('lab')
        is_doctor_role = normalized_role == 'doctor'
        is_patient_role = normalized_role == 'patient'
        is_admin_role = normalized_role == 'admin'
        
        # Role Permissions for uploading
        if is_lab_role:
            if not booking_id:
                return jsonify({"error": "bookingId is required for lab uploads"}), 400
            fs_client = get_firestore_client()
            if fs_client:
                booking_ref = fs_client.collection('lab_bookings').document(booking_id)
                booking_doc = booking_ref.get()
                if not booking_doc.exists:
                    return jsonify({"error": "Lab booking not found"}), 404
                    
                booking_data = booking_doc.to_dict()
                if booking_data.get('labId') != uploader_uid:
                    return jsonify({"error": "Unauthorized: Booking is not assigned to your lab"}), 403
            else:
                return jsonify({"error": "Database service unavailable"}), 500
                
        elif is_patient_role:
            if patient_id != uploader_uid:
                return jsonify({"error": "Unauthorized: You can only upload files for yourself"}), 403
                
        elif is_doctor_role:
            db_conn = get_db()
            appt = db_conn.appointments.find_one({
                "doctor_id": uploader_uid,
                "patient_id": patient_id
            })
            if not appt:
                return jsonify({"error": "Unauthorized: No appointment history with this patient"}), 403
                
        elif not is_admin_role:
            return jsonify({"error": "Unauthorized role"}), 403
            
        # Prepare metadata
        document_name = request.form.get('documentName')
        metadata = {
            "patientId": patient_id,
            "bookingId": booking_id,
            "doctorId": doctor_id,
            "labId": lab_id or (uploader_uid if is_lab_role else None),
            "uploadedBy": uploader_uid,
            "reportType": report_type,
            "documentName": document_name,
            "contentType": file.content_type,
            "fileSize": f"{round(size / (1024 * 1024), 2)} MB"
        }
        
        # Save to GridFS
        file_id = storage_service.save_file(file, filename, metadata)
        
        audit_logger.info(f"AUDIT: User {uploader_uid} ({uploader_role}) successfully uploaded file {file_id} of type {report_type}")
        return jsonify({"success": True, "fileId": file_id}), 201
        
    except Exception as e:
        import traceback
        traceback.print_exc()
        audit_logger.error(f"Upload error: {e}")
        return jsonify({"error": f"Internal server error occurred: {str(e)}"}), 500

@storage_blueprint.route('/file/<fileId>', methods=['GET'])
@token_required
def get_file(fileId):
    try:
        # Validate ObjectId format
        if not ObjectId.is_valid(fileId):
            return jsonify({"error": "Malformed file ID"}), 400
            
        requester_uid = request.user['uid']
        requester_role = get_user_role_from_firestore(requester_uid)
        
        normalized_role = (requester_role or '').lower()
        is_lab_role = normalized_role.startswith('lab')
        is_doctor_role = normalized_role == 'doctor'
        is_patient_role = normalized_role == 'patient'
        is_admin_role = normalized_role == 'admin'
        
        # Fetch metadata
        meta = storage_service.get_metadata(fileId)
        if not meta:
            return jsonify({"error": "File not found"}), 404
            
        # Enforce Permissions
        is_authorized = False
        if is_admin_role:
            is_authorized = True
        elif is_patient_role:
            if meta.get('patientId') == requester_uid:
                is_authorized = True
        elif is_doctor_role:
            patient_id = meta.get('patientId')
            db_conn = get_db()
            appt = db_conn.appointments.find_one({
                "doctor_id": requester_uid,
                "patient_id": patient_id
            })
            if appt:
                is_authorized = True
            else:
                fs_client = get_firestore_client()
                if fs_client:
                    try:
                        appts = fs_client.collection('appointments')\
                            .where('doctor_id', '==', requester_uid)\
                            .where('patient_id', '==', patient_id)\
                            .limit(1).get()
                        if len(appts) > 0:
                            is_authorized = True
                    except Exception as e:
                        print("Error checking Firestore appointments for file access:", e)
        elif is_lab_role:
            if meta.get('labId') == requester_uid or meta.get('uploadedBy') == requester_uid:
                is_authorized = True
                
        if not is_authorized:
            audit_logger.warning(f"AUDIT: Unauthorized file download attempt by {requester_uid} on file {fileId}")
            return jsonify({"error": "Unauthorized access to this file"}), 403
            
        # Retrieve file object
        file_obj = storage_service.get_file(fileId)
        if not file_obj:
            return jsonify({"error": "File content not found in storage"}), 404
            
        # Memory-efficient chunked streaming generator
        def generate():
            while True:
                chunk = file_obj.read(256 * 1024)  # Read 256KB chunks
                if not chunk:
                    break
                yield chunk
                
        audit_logger.info(f"AUDIT: User {requester_uid} ({requester_role}) started downloading file {fileId}")
        
        filename = file_obj.filename or "report.pdf"
        ext = filename.rsplit('.', 1)[1].lower() if '.' in filename else ''
        if ext == 'png':
            mime = 'image/png'
        elif ext in ('jpg', 'jpeg'):
            mime = 'image/jpeg'
        else:
            mime = 'application/pdf'
            
        return Response(
            generate(),
            mimetype=mime,
            headers={
                'Content-Disposition': f'inline; filename="{filename}"'
            }
        )
        
    except Exception as e:
        audit_logger.error(f"Download error: {e}")
        return jsonify({"error": "Internal server error occurred"}), 500

@storage_blueprint.route('/patient/<patientId>', methods=['GET'])
@token_required
def get_patient_files(patientId):
    try:
        requester_uid = request.user['uid']
        requester_role = get_user_role_from_firestore(requester_uid)
        
        normalized_role = (requester_role or '').lower()
        is_lab_role = normalized_role.startswith('lab')
        is_doctor_role = normalized_role == 'doctor'
        is_patient_role = normalized_role == 'patient'
        is_admin_role = normalized_role == 'admin'
        
        is_authorized = False
        if is_admin_role:
            is_authorized = True
        elif is_patient_role and patientId == requester_uid:
            is_authorized = True
        elif is_doctor_role:
            db_conn = get_db()
            appt = db_conn.appointments.find_one({
                "doctor_id": requester_uid,
                "patient_id": patientId
            })
            if appt:
                is_authorized = True
        elif is_lab_role:
            query = {"patientId": patientId, "labId": requester_uid}
            files = storage_service.get_metadata_by_query(query)
            return jsonify(files), 200
            
        if not is_authorized:
            return jsonify({"error": "Unauthorized access"}), 403
            
        return jsonify(files), 200
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@storage_blueprint.route('/patient', methods=['GET'])
@token_required
def get_authenticated_patient_documents():
    try:
        patient_id = request.user['uid']
        files = storage_service.get_metadata_by_query({
            "patientId": patient_id,
            "reportType": "patient_document"
        })
        return jsonify(files), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@storage_blueprint.route('/patient/<patientId>/documents', methods=['GET'])
@token_required
def get_patient_documents(patientId):
    try:
        requester_uid = request.user['uid']
        requester_role = get_user_role_from_firestore(requester_uid)
        
        normalized_role = (requester_role or '').lower()
        is_doctor_role = normalized_role == 'doctor' or normalized_role.startswith('doc')
        is_patient_role = normalized_role == 'patient'
        is_admin_role = normalized_role == 'admin'
        
        db_conn = get_db()
        appt = db_conn.appointments.find_one({
            "doctor_id": requester_uid,
            "patient_id": patientId
        })
        appointment_exists = appt is not None
        
        if not appointment_exists:
            fs_client = get_firestore_client()
            if fs_client:
                try:
                    appts = fs_client.collection('appointments')\
                        .where('doctor_id', '==', requester_uid)\
                        .where('patient_id', '==', patientId)\
                        .limit(1).get()
                    if len(appts) > 0:
                        appointment_exists = True
                except Exception as e:
                    print("Error checking Firestore appointments:", e)
        
        print("Role:", requester_role)
        print("Requested patient:", patientId)
        print("Requester UID:", requester_uid)
        print("Appointment found:", appointment_exists)
        
        is_authorized = False
        if is_admin_role:
            is_authorized = True
        elif is_patient_role and patientId == requester_uid:
            is_authorized = True
        elif is_doctor_role and appointment_exists:
            is_authorized = True
                
        if not is_authorized:
            return jsonify({"error": "Unauthorized access to these documents"}), 403
            
        files = storage_service.get_metadata_by_query({
            "patientId": patientId,
            "reportType": "patient_document"
        })
        return jsonify(files), 200
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@storage_blueprint.route('/patient/<patientId>/lab-reports', methods=['GET'])
@token_required
def get_patient_lab_reports(patientId):
    try:
        requester_uid = request.user['uid']
        requester_role = get_user_role_from_firestore(requester_uid)
        
        normalized_role = (requester_role or '').lower()
        is_doctor_role = normalized_role == 'doctor' or normalized_role.startswith('doc')
        is_patient_role = normalized_role == 'patient'
        is_admin_role = normalized_role == 'admin'
        
        db_conn = get_db()
        appt = db_conn.appointments.find_one({
            "doctor_id": requester_uid,
            "patient_id": patientId
        })
        appointment_exists = appt is not None
        
        if not appointment_exists:
            fs_client = get_firestore_client()
            if fs_client:
                try:
                    appts = fs_client.collection('appointments')\
                        .where('doctor_id', '==', requester_uid)\
                        .where('patient_id', '==', patientId)\
                        .limit(1).get()
                    if len(appts) > 0:
                        appointment_exists = True
                except Exception as e:
                    print("Error checking Firestore appointments:", e)
        
        print("Role:", requester_role)
        print("Requested patient:", patientId)
        print("Requester UID:", requester_uid)
        print("Appointment found:", appointment_exists)
        
        is_authorized = False
        if is_admin_role:
            is_authorized = True
        elif is_patient_role and patientId == requester_uid:
            is_authorized = True
        elif is_doctor_role and appointment_exists:
            is_authorized = True
                
        if not is_authorized:
            return jsonify({"error": "Unauthorized access to these reports"}), 403
            
        files = storage_service.get_metadata_by_query({
            "patientId": patientId,
            "reportType": "lab_report"
        })
        
        fs_client = get_firestore_client()
        if fs_client:
            for f in files:
                lab_id = f.get('labId')
                if lab_id:
                    lab_doc = fs_client.collection('users').document(lab_id).get()
                    if lab_doc.exists:
                        f['labName'] = lab_doc.to_dict().get('name')
                        
        return jsonify(files), 200
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@storage_blueprint.route('/doctor', methods=['GET'])
@token_required
def get_doctor_files():
    try:
        requester_uid = request.user['uid']
        requester_role = get_user_role_from_firestore(requester_uid)
        
        normalized_role = (requester_role or '').lower()
        is_doctor_role = normalized_role == 'doctor'
        is_admin_role = normalized_role == 'admin'
        
        if not is_doctor_role and not is_admin_role:
            return jsonify({"error": "Unauthorized"}), 403
            
        db_conn = get_db()
        patient_ids = db_conn.appointments.distinct("patient_id", {"doctor_id": requester_uid})
        files = storage_service.get_metadata_by_query({"patientId": {"$in": patient_ids}})
        return jsonify(files), 200
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@storage_blueprint.route('/lab/<labId>', methods=['GET'])
@token_required
def get_lab_files(labId):
    try:
        requester_uid = request.user['uid']
        requester_role = get_user_role_from_firestore(requester_uid)
        
        normalized_role = (requester_role or '').lower()
        is_lab_role = normalized_role.startswith('lab')
        is_admin_role = normalized_role == 'admin'
        
        if not is_admin_role and (not is_lab_role or labId != requester_uid):
            return jsonify({"error": "Unauthorized"}), 403
            
        files = storage_service.get_metadata_by_query({"labId": labId})
        return jsonify(files), 200
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@storage_blueprint.route('/file/<fileId>', methods=['DELETE'])
@token_required
def delete_file(fileId):
    try:
        if not ObjectId.is_valid(fileId):
            return jsonify({"error": "Malformed file ID"}), 400
            
        requester_uid = request.user['uid']
        requester_role = get_user_role_from_firestore(requester_uid)
        
        meta = storage_service.get_metadata(fileId)
        if not meta:
            return jsonify({"error": "File not found"}), 404
            
        # Allowed to delete if uploader or admin
        if requester_role == 'admin' or meta.get('uploadedBy') == requester_uid:
            storage_service.delete_file(fileId)
            audit_logger.info(f"AUDIT: User {requester_uid} ({requester_role}) deleted file {fileId}")
            return jsonify({"success": True, "message": "File deleted successfully"}), 200
            
        audit_logger.warning(f"AUDIT: Unauthorized file deletion attempt by {requester_uid} on file {fileId}")
        return jsonify({"error": "Unauthorized to delete this file"}), 403
        
    except Exception as e:
        audit_logger.error(f"Deletion error: {e}")
        return jsonify({"error": "Internal server error occurred"}), 500
