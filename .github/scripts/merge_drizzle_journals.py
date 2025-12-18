#!/usr/bin/env python3
"""
Merge drizzle migration journals from two branches.
Renumbers PR-specific migrations to continue after base migrations.
"""
import json
import os
import shutil

def main():
    try:
        with open('/tmp/theirs_journal.json') as f:
            theirs = json.load(f)
        with open('/tmp/ours_journal.json') as f:
            ours = json.load(f)
    except Exception as e:
        print(f"Error loading journals: {e}")
        exit(1)

    theirs_entries = theirs.get('entries', [])
    ours_entries = ours.get('entries', [])

    # Find the highest index in theirs
    base_max_idx = max((e.get('idx', 0) for e in theirs_entries), default=-1)

    # Get tags from theirs to identify what's already in base
    theirs_tags = {e.get('tag') for e in theirs_entries}

    # Find entries unique to ours (PR's new migrations)
    pr_entries = [e for e in ours_entries if e.get('tag') not in theirs_tags]

    if pr_entries:
        print(f"Found {len(pr_entries)} PR-specific migration(s) to renumber")

        # Create mapping for renumbering
        rename_map = {}

        for i, entry in enumerate(pr_entries):
            old_idx = entry.get('idx', 0)
            new_idx = base_max_idx + 1 + i
            old_tag = entry.get('tag', '')

            # Parse old tag to get the name part (after the number prefix)
            if '_' in old_tag:
                name_part = '_'.join(old_tag.split('_')[1:])
            else:
                name_part = old_tag

            # Create new tag with new index
            new_tag = f"{new_idx:04d}_{name_part}"

            print(f"  Renumbering: {old_tag} -> {new_tag}")

            # Update entry
            entry['idx'] = new_idx
            entry['tag'] = new_tag

            # Track file renames needed
            rename_map[old_tag] = new_tag

        # Write the rename map for shell script to use
        with open('/tmp/drizzle_rename_map.txt', 'w') as f:
            for old, new in rename_map.items():
                f.write(f"{old}|{new}\n")

        # Merge entries: theirs + renumbered PR entries
        merged_entries = theirs_entries + pr_entries
        merged_entries.sort(key=lambda x: x.get('idx', 0))

        # Write merged journal
        merged = {
            'version': theirs.get('version', '7'),
            'dialect': theirs.get('dialect', 'postgresql'),
            'entries': merged_entries
        }
        with open('/tmp/merged_journal.json', 'w') as f:
            json.dump(merged, f, indent=2)

        print("Merged journal created successfully")
    else:
        print("No PR-specific migrations found, using base journal")
        shutil.copy('/tmp/theirs_journal.json', '/tmp/merged_journal.json')
        with open('/tmp/drizzle_rename_map.txt', 'w') as f:
            pass  # Empty file

if __name__ == '__main__':
    main()
