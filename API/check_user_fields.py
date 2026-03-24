#!/usr/bin/env python
import os
from pathlib import Path
from dotenv import load_dotenv

# Load .env file
load_dotenv(Path(__file__).parent / ".env")

from db import init_mongodb

db = init_mongodb()
users_collection = db.get_collection('users')

# Check all fields in first document
first_user = users_collection.find_one({})
if first_user:
    print("First user document fields:")
    for key, value in first_user.items():
        if key != '_id':
            print(f"  {key}: {value}")

# Check if there are any documents with "user_id" field
user_id_docs = list(users_collection.find({"user_id": {"$exists": True}}))
print(f"\nDocuments with 'user_id' field: {len(user_id_docs)}")

# Check if there are any documents with "id" field
id_docs = list(users_collection.find({"id": {"$exists": True}}))
print(f"Documents with 'id' field: {len(id_docs)}")

# Check total documents
print(f"\nTotal documents in users collection: {users_collection.count_documents({})}")
