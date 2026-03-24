#!/usr/bin/env python
"""Simple check for user count in MongoDB"""
import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv(Path(__file__).parent / ".env")

from db import init_mongodb

db = init_mongodb()
count = db.get_collection('users').count_documents({})
print(f"Users in MongoDB: {count}")

if count == 6:
    print("✓ SUCCESS: All 6 users migrated!")
elif count == 0:
    print("❌ FAILED: No users migrated")
else:
    print(f"⚠️  PARTIAL: {count} of 6 users migrated")
