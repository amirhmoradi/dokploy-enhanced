#!/usr/bin/env python3
"""
Renumber duplicate drizzle migrations to preserve all migrations.
This script finds migrations with duplicate numbers and renumbers them
to maintain sequential order without losing any migrations.
"""
import json
import os
import re
import shutil
from collections import defaultdict

def main():
    drizzle_dir = os.environ.get('DRIZZLE_DIR', '.')
    meta_dir = os.environ.get('META_DIR', '')
    journal_file = os.environ.get('JOURNAL_FILE', '')

    # Load journal
    try:
        with open(journal_file) as f:
            journal = json.load(f)
    except Exception as e:
        print(f"  Error loading journal: {e}")
        exit(1)

    entries = journal.get('entries', [])
    journal_tags = {e.get('tag') for e in entries}

    # Find all SQL files
    sql_files = []
    for f in os.listdir(drizzle_dir):
        if f.endswith('.sql'):
            sql_files.append(f)
    sql_files.sort()

    # Group by migration number
    by_number = defaultdict(list)
    for sql_file in sql_files:
        match = re.match(r'^(\d+)_(.+)\.sql$', sql_file)
        if match:
            num = int(match.group(1))
            name = match.group(2)
            tag = sql_file[:-4]  # Remove .sql
            by_number[num].append({'file': sql_file, 'tag': tag, 'name': name, 'num': num})

    # Find the highest number currently in use
    max_num = max(by_number.keys()) if by_number else -1

    # Process duplicates - renumber files not in journal
    changes_made = False
    new_entries = []

    for num in sorted(by_number.keys()):
        files = by_number[num]
        if len(files) > 1:
            print(f"  Processing {len(files)} files with number {num:04d}")
            for i, file_info in enumerate(files):
                if file_info['tag'] in journal_tags:
                    print(f"    Keeping (in journal): {file_info['file']}")
                else:
                    # Renumber this file
                    max_num += 1
                    new_tag = f"{max_num:04d}_{file_info['name']}"
                    new_file = f"{new_tag}.sql"
                    old_path = os.path.join(drizzle_dir, file_info['file'])
                    new_path = os.path.join(drizzle_dir, new_file)

                    print(f"    Renumbering: {file_info['file']} -> {new_file}")

                    # Rename SQL file
                    shutil.move(old_path, new_path)

                    # Rename snapshot if exists
                    if meta_dir:
                        old_snapshot = os.path.join(meta_dir, f"{file_info['tag']}.json")
                        new_snapshot = os.path.join(meta_dir, f"{new_tag}.json")
                        if os.path.exists(old_snapshot):
                            shutil.move(old_snapshot, new_snapshot)
                            print(f"    Renamed snapshot: {file_info['tag']}.json -> {new_tag}.json")

                    # Add new entry to journal
                    # Find the original entry to copy metadata
                    original_entry = None
                    for e in entries:
                        if e.get('tag') == file_info['tag']:
                            original_entry = e.copy()
                            break

                    if original_entry:
                        original_entry['idx'] = max_num
                        original_entry['tag'] = new_tag
                    else:
                        # Create new entry
                        original_entry = {
                            'idx': max_num,
                            'version': '7',
                            'when': int(os.path.getmtime(new_path) * 1000),
                            'tag': new_tag,
                            'breakpoints': True
                        }

                    new_entries.append(original_entry)
                    changes_made = True

    # Add new entries to journal
    if new_entries:
        entries.extend(new_entries)
        entries.sort(key=lambda x: x.get('idx', 0))
        journal['entries'] = entries

        with open(journal_file, 'w') as f:
            json.dump(journal, f, indent=2)

        print(f"  Added {len(new_entries)} renumbered migration(s) to journal")

    if changes_made:
        print("  Migrations renumbered successfully - all migrations preserved")
    else:
        print("  No renumbering needed")

if __name__ == '__main__':
    main()
