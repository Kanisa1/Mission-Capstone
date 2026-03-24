"""
MongoDB Connection and Database Management
"""

import os
from pymongo import MongoClient
from pymongo.errors import ConnectionFailure, ServerSelectionTimeoutError
from typing import Optional

class MongoDatabase:
    """MongoDB connection manager"""
    
    def __init__(self):
        self.conn_string = os.getenv("MONGODB_URI", "").strip()
        self.db_name = os.getenv("MONGODB_DB_NAME", "mineral_trace").strip()
        self.client: Optional[MongoClient] = None
        self.db = None
        
    def connect(self):
        """Establish MongoDB connection"""
        if not self.conn_string:
            raise ValueError(
                "MONGODB_URI not configured. "
                "Get it from MongoDB Atlas: https://www.mongodb.com/cloud/atlas"
            )
        
        try:
            self.client = MongoClient(self.conn_string, serverSelectionTimeoutMS=5000)
            # Test connection
            self.client.admin.command('ping')
            self.db = self.client[self.db_name]
            print(f"✓ MongoDB connected to '{self.db_name}'")
            self._create_indexes()
            return True
        except (ConnectionFailure, ServerSelectionTimeoutError) as e:
            raise ConnectionError(f"Failed to connect to MongoDB: {e}")
        except Exception as e:
            raise Exception(f"MongoDB connection error: {e}")
    
    def _create_indexes(self):
        """Create necessary indexes for performance"""
        if self.db is None:
            return
        
        from pymongo.errors import OperationFailure
        
        def _safe_index(collection, spec, **kwargs):
            """Safely create index, ignoring conflicts"""
            try:
                collection.create_index(spec, **kwargs)
            except OperationFailure as e:
                if "IndexKeySpecsConflict" not in str(e) and "already exists" not in str(e):
                    raise
        
        # Users indexes
        _safe_index(self.db.users, "email", unique=True, sparse=True)
        _safe_index(self.db.users, "id", unique=True, sparse=True)
        _safe_index(self.db.users, "role")
        
        # Mining Sites indexes
        _safe_index(self.db.mining_sites, "site_id", unique=True, sparse=True)
        _safe_index(self.db.mining_sites, "site_name")
        
        # Minerals indexes
        _safe_index(self.db.minerals, "mineral_id", unique=True, sparse=True)
        _safe_index(self.db.minerals, "mineral_name")
        
        # Fingerprints indexes (including new references)
        _safe_index(self.db.fingerprints, "sample_id", unique=True)
        _safe_index(self.db.fingerprints, "site")
        _safe_index(self.db.fingerprints, "mineral")
        _safe_index(self.db.fingerprints, "site_id")
        _safe_index(self.db.fingerprints, "mineral_id")
        _safe_index(self.db.fingerprints, "timestamp")
        
        # Scan Events indexes
        _safe_index(self.db.scan_events, "scan_id", unique=True, sparse=True)
        _safe_index(self.db.scan_events, "fingerprint_id")
        _safe_index(self.db.scan_events, "user_id")
        _safe_index(self.db.scan_events, "site_id")
        _safe_index(self.db.scan_events, "scan_timestamp")
        
        # Verification Records indexes
        _safe_index(self.db.verification_records, "verification_id", unique=True, sparse=True)
        _safe_index(self.db.verification_records, "scan_id")
        _safe_index(self.db.verification_records, "auditor_id")
        _safe_index(self.db.verification_records, "verification_timestamp")
        
        # Audit trail indexes
        _safe_index(self.db.audit_chain, "block_index", unique=True)
        _safe_index(self.db.audit_chain, "timestamp")
        _safe_index(self.db.audit_chain, "action")
        
        print("✓ Database indexes initialized (6 collections)")
    
    def disconnect(self):
        """Close MongoDB connection"""
        if self.client:
            self.client.close()
            print("✓ MongoDB disconnected")
    
    def get_collection(self, collection_name: str):
        """Get a collection"""
        if self.db is None:
            raise RuntimeError("Database not connected")
        return self.db[collection_name]

# Global database instance
_mongo_db: Optional[MongoDatabase] = None

def get_mongo_db() -> MongoDatabase:
    """Get or create MongoDB instance"""
    global _mongo_db
    if _mongo_db is None:
        _mongo_db = MongoDatabase()
    return _mongo_db

def init_mongodb():
    """Initialize MongoDB connection"""
    db = get_mongo_db()
    db.connect()
    return db
