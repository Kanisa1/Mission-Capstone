"""
Migration script: JSON → MongoDB
Migrates all data from JSON files to MongoDB Atlas
"""

import json
import sys
from pathlib import Path
from datetime import datetime
from dotenv import load_dotenv

# Add API directory to path
api_dir = Path(__file__).parent
sys.path.insert(0, str(api_dir))
sys.path.insert(0, str(api_dir.parent))

from db import init_mongodb

# Load environment variables
load_dotenv(api_dir / ".env")

BASE_DIR = api_dir.parent

FINGERPRINT_DB = BASE_DIR / "dataset" / "fingerprints.jsonl"
USERS_DB = BASE_DIR / "dataset" / "users.json"
AUDIT_CHAIN_DB = BASE_DIR / "logs" / "audit_chain.jsonl"

def migrate_fingerprints(db):
    """Migrate fingerprints from JSON to MongoDB"""
    print("\n📊 Migrating fingerprints...")
    
    if not FINGERPRINT_DB.exists():
        print("  ℹ️ No fingerprints file found (fingerprints.jsonl)")
        return 0
    
    collection = db.get_collection("fingerprints")
    migrated = 0
    errors = 0
    
    with open(FINGERPRINT_DB, "r", encoding="utf-8") as f:
        for line_num, line in enumerate(f, 1):
            try:
                record = json.loads(line.strip())
                if record.get("sample_id"):
                    # Upsert: update if exists, insert if new
                    collection.update_one(
                        {"sample_id": record["sample_id"]},
                        {"$set": record},
                        upsert=True
                    )
                    migrated += 1
            except Exception as e:
                errors += 1
                print(f"  ⚠️ Error on line {line_num}: {e}")
    
    print(f"  ✓ Fingerprints: {migrated} records migrated ({errors} errors)")
    return migrated

def migrate_users(db):
    """Migrate users from JSON to MongoDB"""
    print("\n👥 Migrating users...")
    
    if not USERS_DB.exists():
        print("  ℹ️ No users file found (users.json)")
        return 0
    
    collection = db.get_collection("users")
    migrated = 0
    errors = 0
    
    try:
        with open(USERS_DB, "r", encoding="utf-8") as f:
            data = json.load(f)
        
        # Handle both list and dict formats
        users = data if isinstance(data, list) else (data.get("users") or [])
        
        for user in users:
            try:
                if user.get("id") or user.get("email"):
                    collection.update_one(
                        {"$or": [
                            {"id": user.get("id")},
                            {"email": user.get("email")}
                        ]},
                        {"$set": user},
                        upsert=True
                    )
                    migrated += 1
            except Exception as e:
                errors += 1
                print(f"  ⚠️ Error migrating user: {e}")
    
    except Exception as e:
        print(f"  ⚠️ Error reading users file: {e}")
        errors += 1
    
    print(f"  ✓ Users: {migrated} records migrated ({errors} errors)")
    return migrated

def migrate_audit_chain(db):
    """Migrate audit chain from JSON to MongoDB"""
    print("\n🔐 Migrating audit trail...")
    
    if not AUDIT_CHAIN_DB.exists():
        print("  ℹ️ No audit chain file found (audit_chain.jsonl)")
        return 0
    
    collection = db.get_collection("audit_chain")
    migrated = 0
    errors = 0
    
    with open(AUDIT_CHAIN_DB, "r", encoding="utf-8") as f:
        for line_num, line in enumerate(f, 1):
            try:
                record = json.loads(line.strip())
                if record.get("block_index"):
                    # Use replace_one to preserve order
                    collection.update_one(
                        {"block_index": record["block_index"]},
                        {"$set": record},
                        upsert=True
                    )
                    migrated += 1
            except Exception as e:
                errors += 1
                print(f"  ⚠️ Error on line {line_num}: {e}")
    
    print(f"  ✓ Audit chain: {migrated} blocks migrated ({errors} errors)")
    return migrated

def main():
    """Run migration"""
    print("\n" + "="*50)
    print("  MINERAL TRACE: JSON → MongoDB Migration")
    print("="*50)
    
    try:
        # Connect to MongoDB
        print("\n🔗 Connecting to MongoDB Atlas...")
        db = init_mongodb()
        
        # Run migrations
        total = 0
        total += migrate_fingerprints(db)
        total += migrate_users(db)
        total += migrate_audit_chain(db)
        
        print("\n" + "="*50)
        print(f"✅ Migration complete! ({total} total records)")
        print("="*50)
        print("\n📝 Next steps:")
        print("  1. Install dependencies: pip install -r requirements.txt")
        print("  2. Restart the API: uvicorn API.api:app --reload")
        print("  3. Test the endpoints to verify everything works")
        print("\n💾 Your JSON files are still available as backup in:")
        print(f"  - {FINGERPRINT_DB}")
        print(f"  - {USERS_DB}")
        print(f"  - {AUDIT_CHAIN_DB}")
        
    except Exception as e:
        print(f"\n❌ Migration failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
