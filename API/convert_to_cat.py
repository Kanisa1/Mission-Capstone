"""Convert all UTC timezone instances to CAT (Central Africa Time)"""
import re

# Read the file
with open('api.py', 'r') as f:
    content = f.read()

# Replace all instances of timezone.utc with CAT
replaced_count = 0

# Replace in datetime.now() calls
pattern = r'datetime\.now\(timezone\.utc\)'
replacement = 'datetime.now(CAT)'
new_content = re.sub(pattern, replacement, content)
replaced_count = len(re.findall(pattern, content))

# Write back
with open('api.py', 'w') as f:
    f.write(new_content)

print(f"✓ Replaced {replaced_count} instances of timezone.utc with CAT")
print("✓ All timestamps now use CAT (Central Africa Time, UTC+2)")
