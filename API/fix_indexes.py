#!/usr/bin/env python
"""Fix MongoDB indexes for users collection"""
import os
from pathlib import Path
from dotenv import load_dotenv

# Load .env file
load_dotenv(Path(__file__).parent / ".env")

from db import init_mongodb

db = init_mongodb()
users_collection = db.get_collection('users')

# Get all indexes
print("Current indexes:")
for index_info in users_collection.list_indexes():
    print(f"  - {index_info['name']}: {index_info['key']}")

# Drop problematic user_id index if it exists
try:
    users_collection.drop_index('user_id_1')
    print("\n✓ Dropped 'user_id_1' index")
except Exception as e:
    print(f"\nℹ️  Could not drop user_id index: {e}")

# Drop all indexes except _id
print("\n✓ Dropping all indexes except _id...")
try:
    users_collection.drop_indexes()
    print("✓ All indexes dropped")
except Exception as e:
    print(f"ℹ️  {e}")

# Recreate indexes with correct field names
print("\n✓ Creating new indexes with correct field names...")
users_collection.create_index("id", unique=True, sparse=True)
users_collection.create_index("email", unique=True, sparse=True)
print("✓ New indexes created: id (unique), email (unique)")

print("\nFinal indexes:")
for index_info in users_collection.list_indexes():
    print(f"  - {index_info['name']}: {index_info['key']}")
