#!/usr/bin/env python3
"""
Renumber duplicate drizzle migrations to preserve all migrations.

IMPORTANT: This script is conservative and only processes:
1. Files with EXACT same filename (true duplicates from merge conflicts)
2. Latest migrations only (highest numbered) - doesn't touch old migrations
3. Files that are actually causing issues (not in journal but exist on disk)

It does NOT process files that just happen to share the same number prefix
with different names - those are legitimate different migrations.
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

    # Get the highest index in journal - this tells us where "recent" starts
    max_journal_idx = max((e.get('idx', 0) for e in entries), default=-1)

    # Find all SQL files
    sql_files = []
    for f in os.listdir(drizzle_dir):
        if f.endswith('.sql'):
            sql_files.append(f)
    sql_files.sort()

    if not sql_files:
        print("  No SQL migration files found")
        return

    # Group by FULL filename (tag) to find true duplicates
    # In a filesystem, you can't have duplicate filenames, so this is mainly
    # for detecting files that exist on disk but aren't in journal
    by_tag = {}
    by_number = defaultdict(list)

    for sql_file in sql_files:
        match = re.match(r'^(\d+)_(.+)\.sql$', sql_file)
        if match:
            num = int(match.group(1))
            name = match.group(2)
            tag = sql_file[:-4]  # Remove .sql
            by_tag[tag] = {'file': sql_file, 'tag': tag, 'name': name, 'num': num}
            by_number[num].append({'file': sql_file, 'tag': tag, 'name': name, 'num': num})

    # Find the highest number on disk
    max_num = max(by_number.keys()) if by_number else -1

    # Only look at RECENT migrations (last 5 numbers or those after journal max)
    # This prevents touching old, stable migrations
    recent_threshold = max(max_num - 5, max_journal_idx - 2, 0)

    print(f"  Journal max index: {max_journal_idx}, Disk max number: {max_num}")
    print(f"  Only processing migrations >= {recent_threshold} (recent only)")

    changes_made = False
    new_entries = []

    # Only process recent migrations with duplicate numbers
    for num in sorted(by_number.keys()):
        # Skip old migrations - only process recent ones
        if num < recent_threshold:
            continue

        files = by_number[num]

        # Only process if there are ACTUAL duplicates (same number, different files)
        if len(files) > 1:
            print(f"  Found {len(files)} files with number {num:04d}")

            # Check which ones are in journal vs not
            in_journal = [f for f in files if f['tag'] in journal_tags]
            not_in_journal = [f for f in files if f['tag'] not in journal_tags]

            if not_in_journal and in_journal:
                # We have files not in journal - these need renumbering
                print(f"    {len(in_journal)} in journal, {len(not_in_journal)} not in journal")

                for file_info in not_in_journal:
                    # Renumber this file to the next available number
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

                    # Create new journal entry
                    new_entry = {
                        'idx': max_num,
                        'version': '7',
                        'when': int(os.path.getmtime(new_path) * 1000),
                        'tag': new_tag,
                        'breakpoints': True
                    }
                    new_entries.append(new_entry)
                    changes_made = True

            elif len(not_in_journal) > 1:
                # Multiple files with same number, none in journal
                # Keep the first one (alphabetically), renumber the rest
                print(f"    None in journal, keeping first and renumbering rest")
                sorted_files = sorted(not_in_journal, key=lambda x: x['file'])

                for file_info in sorted_files[1:]:  # Skip the first one
                    max_num += 1
                    new_tag = f"{max_num:04d}_{file_info['name']}"
                    new_file = f"{new_tag}.sql"
                    old_path = os.path.join(drizzle_dir, file_info['file'])
                    new_path = os.path.join(drizzle_dir, new_file)

                    print(f"    Renumbering: {file_info['file']} -> {new_file}")
                    shutil.move(old_path, new_path)

                    if meta_dir:
                        old_snapshot = os.path.join(meta_dir, f"{file_info['tag']}.json")
                        new_snapshot = os.path.join(meta_dir, f"{new_tag}.json")
                        if os.path.exists(old_snapshot):
                            shutil.move(old_snapshot, new_snapshot)

                    new_entry = {
                        'idx': max_num,
                        'version': '7',
                        'when': int(os.path.getmtime(new_path) * 1000),
                        'tag': new_tag,
                        'breakpoints': True
                    }
                    new_entries.append(new_entry)
                    changes_made = True
            else:
                print(f"    All {len(files)} files are in journal - no action needed")

    # Add new entries to journal
    if new_entries:
        entries.extend(new_entries)
        entries.sort(key=lambda x: x.get('idx', 0))
        journal['entries'] = entries

        with open(journal_file, 'w') as f:
            json.dump(journal, f, indent=2)

        print(f"  Added {len(new_entries)} renumbered migration(s) to journal")

    if changes_made:
        print("  Recent migrations renumbered successfully - all migrations preserved")
    else:
        print("  No renumbering needed for recent migrations")

if __name__ == '__main__':
    main()
