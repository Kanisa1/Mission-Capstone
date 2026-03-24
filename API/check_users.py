#!/usr/bin/env python
import os
from pathlib import Path
from dotenv import load_dotenv

# Load .env file
load_dotenv(Path(__file__).parent / ".env")

from db import init_mongodb

db = init_mongodb()
users_collection = db.get_collection('users')

count = users_collection.count_documents({})
print(f'Total users in MongoDB: {count}')

users = list(users_collection.find({}))
print(f'\nUsers found ({len(users)}):')
for u in users:
    print(f"  - {u.get('email')} ({u.get('name')}) [ID field: {u.get('id')}]")
