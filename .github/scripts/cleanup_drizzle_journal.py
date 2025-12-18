#!/usr/bin/env python3
"""
Clean up orphaned drizzle journal entries.
Removes journal entries that don't have corresponding SQL files.
"""
import json
import os

def main():
    journal_file = os.environ.get('JOURNAL_FILE', '')
    drizzle_dir = os.environ.get('DRIZZLE_DIR', '.')

    try:
        with open(journal_file) as f:
            journal = json.load(f)
    except:
        exit(0)

    entries = journal.get('entries', [])
    valid_entries = []
    removed = 0

    for entry in entries:
        tag = entry.get('tag', '')
        sql_path = os.path.join(drizzle_dir, f"{tag}.sql")
        if os.path.exists(sql_path):
            valid_entries.append(entry)
        else:
            print(f"    Removing orphaned journal entry: {tag}")
            removed += 1

    if removed > 0:
        journal['entries'] = valid_entries
        with open(journal_file, 'w') as f:
            json.dump(journal, f, indent=2)
        print(f"  Removed {removed} orphaned journal entries")

if __name__ == '__main__':
    main()
