"""Drop all indexes and recreate them with correct specifications"""
from db import MongoDatabase

db = MongoDatabase()
db.connect()

# Drop all indexes (except _id index which cannot be dropped)
try:
    db.db.users.drop_indexes()
    print("✓ Dropped all users indexes")
except Exception as e:
    print(f"Note: {e}")

try:
    db.db.fingerprints.drop_indexes()
    print("✓ Dropped all fingerprints indexes")
except Exception as e:
    print(f"Note: {e}")

try:
    db.db.audit_chain.drop_indexes()
    print("✓ Dropped all audit_chain indexes")
except Exception as e:
    print(f"Note: {e}")

# Now recreate indexes with correct specifications
try:
    # Fingerprints indexes
    db.db.fingerprints.create_index("sample_id", unique=True)
    db.db.fingerprints.create_index("site")
    db.db.fingerprints.create_index("mineral")
    db.db.fingerprints.create_index("timestamp")
    print("✓ Created fingerprints indexes")
    
    # Users indexes
    db.db.users.create_index("email", unique=True, sparse=True)
    db.db.users.create_index("id", unique=True, sparse=True)
    db.db.users.create_index("role")
    print("✓ Created users indexes")
    
    # Audit trail indexes
    db.db.audit_chain.create_index("block_index", unique=True)
    db.db.audit_chain.create_index("timestamp")
    db.db.audit_chain.create_index("action")
    print("✓ Created audit_chain indexes")
    
    print("\n✓ All indexes successfully recreated!")
except Exception as e:
    print(f"✗ Error creating indexes: {e}")
