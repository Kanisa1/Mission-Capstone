#!/usr/bin/env python
"""
Fix all timezone-naive datetime calls to use UTC timezone-aware datetimes
"""
import re
from pathlib import Path

api_file = Path(__file__).parent / "api.py"

with open(api_file, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace all datetime.utcnow() with datetime.now(timezone.utc)
content = re.sub(r'datetime\.utcnow\(\)\.isoformat\(\)', 'datetime.now(timezone.utc).isoformat()', content)
content = re.sub(r'datetime\.utcnow\(\)', 'datetime.now(timezone.utc)', content)

# Replace datetime.now() with datetime.now(timezone.utc) ONLY in isoformat() contexts
# This avoids breaking other datetime.now() usage
content = re.sub(r'datetime\.now\(\)\.isoformat\(\)', 'datetime.now(timezone.utc).isoformat()', content)

# For datetime.now() in other contexts followed by assignment to timestamps
content = re.sub(r'datetime\.now\(\)\s*\)', 'datetime.now(timezone.utc))', content)

with open(api_file, 'w', encoding='utf-8') as f:
    f.write(content)

print("✓ Fixed all timezone-naive datetime calls to use UTC timezone-aware datetimes")
