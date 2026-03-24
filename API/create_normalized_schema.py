"""
Create normalized MongoDB schema for MineralTrace
This script creates the missing collections: mining_sites, minerals, scan_events, verification_records
And restructures fingerprints to use foreign key references
"""
import os
import json
from datetime import datetime, timedelta, timezone
from db import MongoDatabase

# CAT (Central Africa Time) is UTC+2
CAT = timezone(timedelta(hours=2))

def create_normalized_schema():
    """Create all collections with proper schema"""
    db = MongoDatabase()
    db.connect()
    
    if db.db is None:
        print("✗ Failed to connect to MongoDB")
        return False
    
    print("📊 Creating normalized MongoDB schema...")
    
    # 1. Create mining_sites collection
    print("\n1️⃣  Creating mining_sites collection...")
    try:
        # Get unique sites from fingerprints
        existing_sites = db.db.fingerprints.distinct("site")
        print(f"   Found {len(existing_sites)} unique sites in fingerprints")
        
        for site_name in existing_sites:
            site_doc = {
                "site_id": site_name.lower().replace("_", "-"),
                "site_name": site_name,
                "created_at": datetime.now(CAT).isoformat(),
            }
            # Upsert to avoid duplicates
            db.db.mining_sites.update_one(
                {"site_id": site_doc["site_id"]},
                {"$set": site_doc},
                upsert=True
            )
        
        # Create indexes
        db.db.mining_sites.create_index("site_id", unique=True, sparse=True)
        db.db.mining_sites.create_index("site_name")
        print(f"   ✓ mining_sites collection created with {db.db.mining_sites.count_documents({})} documents")
    except Exception as e:
        print(f"   ✗ Error creating mining_sites: {e}")
        return False
    
    # 2. Create minerals collection
    print("\n2️⃣  Creating minerals collection...")
    try:
        # Get unique minerals from fingerprints
        existing_minerals = db.db.fingerprints.distinct("mineral")
        print(f"   Found {len(existing_minerals)} unique minerals in fingerprints")
        
        for mineral_name in existing_minerals:
            mineral_doc = {
                "mineral_id": mineral_name.lower().replace("_", "-"),
                "mineral_name": mineral_name,
                "created_at": datetime.now(CAT).isoformat(),
            }
            # Upsert to avoid duplicates
            db.db.minerals.update_one(
                {"mineral_id": mineral_doc["mineral_id"]},
                {"$set": mineral_doc},
                upsert=True
            )
        
        # Create indexes
        db.db.minerals.create_index("mineral_id", unique=True, sparse=True)
        db.db.minerals.create_index("mineral_name")
        print(f"   ✓ minerals collection created with {db.db.minerals.count_documents({})} documents")
    except Exception as e:
        print(f"   ✗ Error creating minerals: {e}")
        return False
    
    # 3. Create scan_events collection
    print("\n3️⃣  Creating scan_events collection...")
    try:
        db.db.scan_events.create_index("scan_id", unique=True, sparse=True)
        db.db.scan_events.create_index("fingerprint_id")
        db.db.scan_events.create_index("user_id")
        db.db.scan_events.create_index("site_id")
        db.db.scan_events.create_index("scan_timestamp")
        print(f"   ✓ scan_events collection created with indexes")
    except Exception as e:
        print(f"   ✗ Error creating scan_events: {e}")
        return False
    
    # 4. Create verification_records collection
    print("\n4️⃣  Creating verification_records collection...")
    try:
        db.db.verification_records.create_index("verification_id", unique=True, sparse=True)
        db.db.verification_records.create_index("scan_id")
        db.db.verification_records.create_index("auditor_id")
        db.db.verification_records.create_index("verification_timestamp")
        print(f"   ✓ verification_records collection created with indexes")
    except Exception as e:
        print(f"   ✗ Error creating verification_records: {e}")
        return False
    
    # 5. Update fingerprints collection with site_id and mineral_id references
    print("\n5️⃣  Restructuring fingerprints collection...")
    try:
        fingerprints = list(db.db.fingerprints.find({}))
        updated_count = 0
        
        for fp in fingerprints:
            # Get site_id from mining_sites
            site_doc = db.db.mining_sites.find_one({"site_name": fp.get("site")})
            site_id = site_doc["site_id"] if site_doc else fp.get("site", "").lower().replace("_", "-")
            
            # Get mineral_id from minerals
            mineral_doc = db.db.minerals.find_one({"mineral_name": fp.get("mineral")})
            mineral_id = mineral_doc["mineral_id"] if mineral_doc else fp.get("mineral", "").lower().replace("_", "-")
            
            # Update fingerprint with references (keep original fields for backwards compatibility)
            db.db.fingerprints.update_one(
                {"_id": fp["_id"]},
                {"$set": {
                    "site_id": site_id,
                    "mineral_id": mineral_id,
                    "updated_at": datetime.now(CAT).isoformat()
                }}
            )
            updated_count += 1
        
        print(f"   ✓ Updated {updated_count} fingerprints with site_id and mineral_id references")
        
        # Add indexes
        db.db.fingerprints.create_index("site_id")
        db.db.fingerprints.create_index("mineral_id")
        print(f"   ✓ Added indexes to fingerprints collection")
    except Exception as e:
        print(f"   ✗ Error restructuring fingerprints: {e}")
        return False
    
    # Summary
    print("\n" + "="*60)
    print("✅ NORMALIZED SCHEMA CREATED SUCCESSFULLY!")
    print("="*60)
    print(f"collections overview:")
    print(f"  • users:                 {db.db.users.count_documents({})}")
    print(f"  • mining_sites:          {db.db.mining_sites.count_documents({})}")
    print(f"  • minerals:              {db.db.minerals.count_documents({})}")
    print(f"  • fingerprints:          {db.db.fingerprints.count_documents({})}")
    print(f"  • scan_events:           {db.db.scan_events.count_documents({})}")
    print(f"  • verification_records:  {db.db.verification_records.count_documents({})}")
    print(f"  • audit_chain:           {db.db.audit_chain.count_documents({})}")
    
    return True

if __name__ == "__main__":
    success = create_normalized_schema()
    exit(0 if success else 1)
