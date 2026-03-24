"""
MongoDB-compatible fingerprint and user database functions
Replace the JSON file operations in api.py with these functions
"""

from typing import Optional, List, Dict, Any
from datetime import datetime
from db import get_mongo_db

# ============================================================================
# FINGERPRINT FUNCTIONS
# ============================================================================

def save_fingerprint(record: dict) -> None:
    """Save a fingerprint record to MongoDB"""
    db = get_mongo_db()
    collection = db.get_collection("fingerprints")
    
    # Add timestamp if not present
    if "timestamp" not in record:
        record["timestamp"] = datetime.now().isoformat()
    
    # Insert or update
    collection.update_one(
        {"sample_id": record["sample_id"]},
        {"$set": record},
        upsert=True
    )

def load_fingerprints() -> List[dict]:
    """Load all fingerprints from MongoDB"""
    db = get_mongo_db()
    collection = db.get_collection("fingerprints")
    
    # Return cursor as list, sorted by timestamp descending
    return list(collection.find({}).sort("timestamp", -1))

def find_fingerprint_by_sample_id(sample_id: str) -> Optional[dict]:
    """Find fingerprint by sample ID"""
    db = get_mongo_db()
    collection = db.get_collection("fingerprints")
    
    return collection.find_one({"sample_id": sample_id})

def find_similar_fingerprint(query_vector: list, records: List[dict], threshold: float = 0.95) -> Optional[dict]:
    """Find similar fingerprint in database"""
    # This requires vector similarity search
    # For now, keeping the original logic but working with MongoDB records
    from sklearn.metrics.pairwise import cosine_similarity
    import numpy as np
    
    best_match = None
    best_similarity = 0
    
    for record in records:
        stored_vector = record.get("fingerprint", [])
        if not stored_vector:
            continue
        
        try:
            similarity = float(cosine_similarity(
                [query_vector],
                [stored_vector]
            )[0, 0])
            
            if similarity > threshold and similarity > best_similarity:
                best_similarity = similarity
                best_match = record
        except Exception:
            continue
    
    if best_match:
        return {"record": best_match, "similarity": best_similarity}
    return None

# ============================================================================
# USER FUNCTIONS
# ============================================================================

def load_users() -> List[dict]:
    """Load all users from MongoDB"""
    db = get_mongo_db()
    collection = db.get_collection("users")
    
    return list(collection.find({}))

def save_user(user: dict) -> None:
    """Save/update user in MongoDB"""
    db = get_mongo_db()
    collection = db.get_collection("users")
    
    # Add timestamp if not present
    if "timestamp" not in user and "created_at" not in user:
        user["created_at"] = datetime.now().isoformat()
    
    collection.update_one(
        {"$or": [
            {"user_id": user.get("user_id")},
            {"email": user.get("email")}
        ]},
        {"$set": user},
        upsert=True
    )

def find_user_by_email(email: str) -> Optional[dict]:
    """Find user by email"""
    db = get_mongo_db()
    collection = db.get_collection("users")
    
    return collection.find_one({"email": email})

def find_user_by_id(user_id: str) -> Optional[dict]:
    """Find user by user ID"""
    db = get_mongo_db()
    collection = db.get_collection("users")
    
    return collection.find_one({"user_id": user_id})

def delete_user(user_id: str) -> bool:
    """Delete user by ID"""
    db = get_mongo_db()
    collection = db.get_collection("users")
    
    result = collection.delete_one({"user_id": user_id})
    return result.deleted_count > 0

# ============================================================================
# AUDIT CHAIN FUNCTIONS
# ============================================================================

def load_audit_chain() -> List[dict]:
    """Load all audit blocks from MongoDB"""
    db = get_mongo_db()
    if db.db is None:
        db.connect()
    collection = db.get_collection("audit_chain")
    
    # Return sorted by block_index
    return list(collection.find({}).sort("block_index", 1))

def save_audit_chain(records: List[dict]) -> None:
    """Save/update audit chain (called after batch updates)"""
    db = get_mongo_db()
    collection = db.get_collection("audit_chain")
    
    for record in records:
        collection.update_one(
            {"block_index": record["block_index"]},
            {"$set": record},
            upsert=True
        )

def get_audit_block_count() -> int:
    """Get total audit blocks"""
    db = get_mongo_db()
    collection = db.get_collection("audit_chain")
    
    return collection.count_documents({})
