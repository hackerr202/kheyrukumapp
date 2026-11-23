#!/usr/bin/env python3
import os
import re

missing = []
for root, _, files in os.walk("lib"):
    for file in files:
        if file.endswith(".dart"):
            filepath = os.path.join(root, file)
            with open(filepath, "r", encoding="utf-8") as f:
                for line in f:
                    m = re.match(r'^\s*import\s+[\'"]([^\:\'"]+)[\'"]', line)
                    if m:
                        rel = m.group(1)
                        target = os.path.normpath(os.path.join(os.path.dirname(filepath), rel))
                        if not os.path.exists(target):
                            missing.append((filepath, rel, target))

if missing:
    print(f"Found {len(missing)} missing relative imports:")
    for item in missing:
        print(" ", item)
else:
    print("All relative imports are verified and exist!")
