#!/usr/bin/env python
"""Clear MongoDB users collection"""
import os
from pathlib import Path
from dotenv import load_dotenv

# Load .env file
load_dotenv(Path(__file__).parent / ".env")

from db import init_mongodb

db = init_mongodb()
users_collection = db.get_collection('users')

# Clear collection
result = users_collection.delete_many({})
print(f'✓ Users collection cleared - {result.deleted_count} documents removed')
