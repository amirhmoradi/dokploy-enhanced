#!/usr/bin/env python3
"""
Merge drizzle migration journals from two branches.
Renumbers PR-specific migrations to continue after base migrations.

IMPORTANT: This script is conservative and only processes:
1. Migrations that are unique to the PR (not in base)
2. Latest migrations only - doesn't touch old, stable migrations
3. Exact conflicts where the same migration index is used by different migrations
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

    # Find the highest index in theirs (base)
    base_max_idx = max((e.get('idx', 0) for e in theirs_entries), default=-1)

    # Get tags from theirs to identify what's already in base
    theirs_tags = {e.get('tag') for e in theirs_entries}

    # Get indices used in theirs
    theirs_indices = {e.get('idx') for e in theirs_entries}

    # Find entries unique to ours (PR's new migrations)
    # These are entries with tags not in theirs
    pr_entries = [e for e in ours_entries if e.get('tag') not in theirs_tags]

    # Also check for index conflicts - same index but different tag
    # This is the key conflict scenario we need to handle
    conflicting_entries = []
    for entry in pr_entries:
        if entry.get('idx') in theirs_indices:
            conflicting_entries.append(entry)

    if pr_entries:
        print(f"Found {len(pr_entries)} PR-specific migration(s)")
        if conflicting_entries:
            print(f"  {len(conflicting_entries)} have index conflicts with base")

        # Create mapping for renumbering - only renumber if there's an actual conflict
        rename_map = {}
        renumbered_entries = []

        for i, entry in enumerate(pr_entries):
            old_idx = entry.get('idx', 0)
            old_tag = entry.get('tag', '')

            # Only renumber if this index conflicts with base
            if old_idx in theirs_indices:
                new_idx = base_max_idx + 1 + i

                # Parse old tag to get the name part (after the number prefix)
                if '_' in old_tag:
                    name_part = '_'.join(old_tag.split('_')[1:])
                else:
                    name_part = old_tag

                # Create new tag with new index
                new_tag = f"{new_idx:04d}_{name_part}"

                print(f"  Renumbering (index conflict): {old_tag} -> {new_tag}")

                # Update entry
                entry['idx'] = new_idx
                entry['tag'] = new_tag

                # Track file renames needed
                rename_map[old_tag] = new_tag
                base_max_idx = new_idx  # Update for next iteration
            else:
                # No conflict, keep original
                print(f"  Keeping (no conflict): {old_tag}")

            renumbered_entries.append(entry)

        # Write the rename map for shell script to use
        with open('/tmp/drizzle_rename_map.txt', 'w') as f:
            for old, new in rename_map.items():
                f.write(f"{old}|{new}\n")

        # Merge entries: theirs + renumbered PR entries
        merged_entries = theirs_entries + renumbered_entries
        merged_entries.sort(key=lambda x: x.get('idx', 0))

        # Write merged journal
        merged = {
            'version': theirs.get('version', '7'),
            'dialect': theirs.get('dialect', 'postgresql'),
            'entries': merged_entries
        }
        with open('/tmp/merged_journal.json', 'w') as f:
            json.dump(merged, f, indent=2)

        if rename_map:
            print(f"Merged journal created with {len(rename_map)} renumbered migration(s)")
        else:
            print("Merged journal created (no renumbering needed)")
    else:
        print("No PR-specific migrations found, using base journal")
        shutil.copy('/tmp/theirs_journal.json', '/tmp/merged_journal.json')
        with open('/tmp/drizzle_rename_map.txt', 'w') as f:
            pass  # Empty file

if __name__ == '__main__':
    main()
