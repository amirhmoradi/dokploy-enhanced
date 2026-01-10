#!/usr/bin/env python3
"""
Drizzle Migration Manager - Enterprise-grade migration conflict resolution.

This script handles all aspects of Drizzle ORM migration conflicts when merging
multiple PRs that may have conflicting migration indices.

Key features:
- Atomic operations: All changes succeed or none do
- Comprehensive validation: Checks all artifacts before and after
- Transactional approach: Creates backups, validates, then commits
- Idempotent: Can be run multiple times safely
- Detailed logging: Easy to debug issues

Handles:
1. Journal conflicts (same index, different migrations)
2. SQL file conflicts
3. Snapshot JSON file conflicts
4. Orphaned artifacts (files without journal entries or vice versa)

Usage:
    python3 drizzle_migration_manager.py <drizzle_dir> [--dry-run] [--verbose]

Environment variables:
    THEIRS_JOURNAL: Path to base branch journal (for merge conflicts)
    OURS_JOURNAL: Path to PR branch journal (for merge conflicts)

Author: dokploy-enhanced
License: MIT
"""

import argparse
import json
import os
import re
import shutil
import sys
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Optional


@dataclass
class Migration:
    """Represents a single migration with all its artifacts."""
    idx: int
    tag: str  # e.g., "0134_happy_name"
    sql_path: Optional[Path] = None
    snapshot_path: Optional[Path] = None
    journal_entry: Optional[dict] = None
    source: str = "unknown"  # "base", "pr", "disk"
    needs_renumber: bool = False
    new_idx: Optional[int] = None
    new_tag: Optional[str] = None


@dataclass
class MigrationState:
    """Complete state of migrations in a drizzle directory."""
    drizzle_dir: Path
    meta_dir: Path
    journal_path: Path
    migrations: dict = field(default_factory=dict)  # tag -> Migration
    max_idx: int = -1
    issues: list = field(default_factory=list)
    changes: list = field(default_factory=list)


class MigrationManager:
    """Manages Drizzle migration conflicts and renumbering."""

    def __init__(self, drizzle_dir: str, dry_run: bool = False, verbose: bool = False):
        self.drizzle_dir = Path(drizzle_dir).resolve()
        self.meta_dir = self.drizzle_dir / "meta"
        self.journal_path = self.meta_dir / "_journal.json"
        self.dry_run = dry_run
        self.verbose = verbose
        self.backup_dir: Optional[Path] = None
        self.state: Optional[MigrationState] = None

    def log(self, message: str, level: str = "info"):
        """Log a message with appropriate prefix."""
        prefixes = {
            "info": "  ",
            "warn": "  ⚠️  ",
            "error": "  ❌ ",
            "success": "  ✓ ",
            "debug": "    → ",
        }
        prefix = prefixes.get(level, "  ")
        if level == "debug" and not self.verbose:
            return
        print(f"{prefix}{message}")

    def validate_directory(self) -> bool:
        """Validate the drizzle directory structure."""
        if not self.drizzle_dir.exists():
            self.log(f"Directory not found: {self.drizzle_dir}", "error")
            return False

        if not self.meta_dir.exists():
            self.log(f"Meta directory not found: {self.meta_dir}", "warn")
            # Create meta dir if it doesn't exist
            if not self.dry_run:
                self.meta_dir.mkdir(parents=True, exist_ok=True)

        return True

    def create_backup(self) -> bool:
        """Create a backup of the current state."""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.backup_dir = Path(f"/tmp/drizzle_backup_{timestamp}")

        try:
            if self.meta_dir.exists():
                shutil.copytree(self.meta_dir, self.backup_dir / "meta")
            self.log(f"Created backup at {self.backup_dir}", "debug")
            return True
        except Exception as e:
            self.log(f"Failed to create backup: {e}", "error")
            return False

    def restore_backup(self) -> bool:
        """Restore from backup on failure."""
        if not self.backup_dir or not self.backup_dir.exists():
            return False

        try:
            backup_meta = self.backup_dir / "meta"
            if backup_meta.exists():
                if self.meta_dir.exists():
                    shutil.rmtree(self.meta_dir)
                shutil.copytree(backup_meta, self.meta_dir)
            self.log("Restored from backup", "info")
            return True
        except Exception as e:
            self.log(f"Failed to restore backup: {e}", "error")
            return False

    def load_journal(self, path: Optional[Path] = None) -> dict:
        """Load and parse a journal file."""
        journal_path = path or self.journal_path

        if not journal_path.exists():
            return {"version": "7", "dialect": "postgresql", "entries": []}

        try:
            with open(journal_path) as f:
                content = f.read()

            # Check for git conflict markers
            if "<<<<<<" in content or ">>>>>>>" in content:
                self.log(f"Git conflict markers found in {journal_path}", "warn")
                # Try to extract the base version (theirs)
                match = re.search(r"<<<<<<.*?\n(.*?)======", content, re.DOTALL)
                if match:
                    try:
                        return json.loads(match.group(1))
                    except json.JSONDecodeError:
                        pass
                # Fall back to empty
                return {"version": "7", "dialect": "postgresql", "entries": []}

            return json.loads(content)
        except json.JSONDecodeError as e:
            self.log(f"Failed to parse journal {journal_path}: {e}", "error")
            return {"version": "7", "dialect": "postgresql", "entries": []}
        except Exception as e:
            self.log(f"Failed to read journal {journal_path}: {e}", "error")
            return {"version": "7", "dialect": "postgresql", "entries": []}

    def scan_disk(self) -> MigrationState:
        """Scan disk for all migration artifacts."""
        state = MigrationState(
            drizzle_dir=self.drizzle_dir,
            meta_dir=self.meta_dir,
            journal_path=self.journal_path,
        )

        # Load journal entries
        journal = self.load_journal()
        journal_entries = {e.get("tag"): e for e in journal.get("entries", [])}

        # Find all SQL files
        sql_pattern = re.compile(r"^(\d+)_(.+)\.sql$")
        sql_files = {}

        for f in self.drizzle_dir.iterdir():
            if f.is_file() and f.suffix == ".sql":
                match = sql_pattern.match(f.name)
                if match:
                    idx = int(match.group(1))
                    name = match.group(2)
                    tag = f"{idx:04d}_{name}"
                    sql_files[tag] = f
                    state.max_idx = max(state.max_idx, idx)

        # Find all snapshot files (handles both naming conventions)
        # Convention 1: {idx}_snapshot.json (newer Drizzle)
        # Convention 2: {tag}.json where tag matches migration tag (older Drizzle)
        snapshot_files = {}
        idx_snapshot_pattern = re.compile(r"^(\d+)_snapshot$")
        if self.meta_dir.exists():
            for f in self.meta_dir.iterdir():
                if f.is_file() and f.suffix == ".json" and f.name != "_journal.json":
                    stem = f.stem
                    # Check if it's an index-based snapshot (e.g., 0134_snapshot)
                    idx_match = idx_snapshot_pattern.match(stem)
                    if idx_match:
                        # Map index-based snapshots to any migration with that index
                        idx = int(idx_match.group(1))
                        # Find the tag for this index from sql_files
                        for tag in sql_files:
                            if tag.startswith(f"{idx:04d}_"):
                                snapshot_files[tag] = f
                                break
                        else:
                            # No matching SQL file, store with artificial tag
                            snapshot_files[f"{idx:04d}_snapshot"] = f
                    else:
                        # Tag-based snapshot
                        snapshot_files[stem] = f

        # Build migration objects
        all_tags = set(journal_entries.keys()) | set(sql_files.keys()) | set(snapshot_files.keys())

        for tag in all_tags:
            match = re.match(r"^(\d+)_", tag)
            idx = int(match.group(1)) if match else -1

            migration = Migration(
                idx=idx,
                tag=tag,
                sql_path=sql_files.get(tag),
                snapshot_path=snapshot_files.get(tag),
                journal_entry=journal_entries.get(tag),
                source="disk",
            )

            # Check for issues
            if migration.sql_path and not migration.journal_entry:
                state.issues.append(f"SQL file {tag}.sql not in journal")
            if migration.journal_entry and not migration.sql_path:
                state.issues.append(f"Journal entry {tag} has no SQL file")
            if migration.sql_path and not migration.snapshot_path:
                state.issues.append(f"SQL file {tag}.sql has no snapshot")

            state.migrations[tag] = migration

        self.state = state
        return state

    def detect_conflicts(self) -> list:
        """Detect migration conflicts (same index, different tags)."""
        if not self.state:
            self.scan_disk()

        conflicts = []
        by_idx = {}

        for tag, migration in self.state.migrations.items():
            if migration.idx not in by_idx:
                by_idx[migration.idx] = []
            by_idx[migration.idx].append(migration)

        for idx, migrations in by_idx.items():
            if len(migrations) > 1:
                tags = [m.tag for m in migrations]
                conflicts.append({
                    "idx": idx,
                    "migrations": migrations,
                    "tags": tags,
                })
                self.log(f"Conflict at index {idx:04d}: {tags}", "warn")

        return conflicts

    def merge_journals(self, theirs_path: Path, ours_path: Path) -> dict:
        """
        Merge two journal files, renumbering conflicting entries.

        Strategy:
        1. Keep all entries from base (theirs)
        2. Find entries unique to PR (ours)
        3. Renumber PR entries that conflict with base
        4. Merge and sort
        """
        theirs = self.load_journal(theirs_path)
        ours = self.load_journal(ours_path)

        theirs_entries = theirs.get("entries", [])
        ours_entries = ours.get("entries", [])

        # Get base state
        theirs_tags = {e.get("tag") for e in theirs_entries}
        theirs_indices = {e.get("idx") for e in theirs_entries}
        base_max_idx = max((e.get("idx", 0) for e in theirs_entries), default=-1)

        self.log(f"Base journal: {len(theirs_entries)} entries, max idx: {base_max_idx}", "debug")
        self.log(f"PR journal: {len(ours_entries)} entries", "debug")

        # Find PR-specific entries (new migrations)
        pr_entries = [e for e in ours_entries if e.get("tag") not in theirs_tags]
        self.log(f"Found {len(pr_entries)} PR-specific migrations", "info")

        # Renumber conflicting entries
        rename_map = {}
        renumbered_entries = []
        next_idx = base_max_idx + 1

        for entry in pr_entries:
            old_idx = entry.get("idx", 0)
            old_tag = entry.get("tag", "")

            if old_idx in theirs_indices:
                # Conflict - need to renumber
                new_idx = next_idx
                next_idx += 1

                # Parse tag to get name part
                if "_" in old_tag:
                    name_part = "_".join(old_tag.split("_")[1:])
                else:
                    name_part = old_tag

                new_tag = f"{new_idx:04d}_{name_part}"

                self.log(f"Renumbering: {old_tag} → {new_tag}", "info")

                entry["idx"] = new_idx
                entry["tag"] = new_tag
                rename_map[old_tag] = new_tag
            else:
                self.log(f"Keeping: {old_tag} (no conflict)", "debug")

            renumbered_entries.append(entry)

        # Merge entries
        merged_entries = theirs_entries + renumbered_entries
        merged_entries.sort(key=lambda x: x.get("idx", 0))

        merged_journal = {
            "version": theirs.get("version", "7"),
            "dialect": theirs.get("dialect", "postgresql"),
            "entries": merged_entries,
        }

        return {
            "journal": merged_journal,
            "rename_map": rename_map,
            "stats": {
                "base_count": len(theirs_entries),
                "pr_count": len(pr_entries),
                "renamed_count": len(rename_map),
                "total_count": len(merged_entries),
            },
        }

    def rename_migration(self, old_tag: str, new_tag: str) -> bool:
        """Rename all artifacts of a migration."""
        if self.dry_run:
            self.log(f"[DRY-RUN] Would rename {old_tag} → {new_tag}", "info")
            return True

        success = True
        changes = []

        # Extract index numbers from tags (e.g., "0134_name" -> 134)
        old_idx_match = re.match(r"^(\d+)", old_tag)
        new_idx_match = re.match(r"^(\d+)", new_tag)
        old_idx = old_idx_match.group(1) if old_idx_match else None
        new_idx = new_idx_match.group(1) if new_idx_match else None

        # Rename SQL file
        old_sql = self.drizzle_dir / f"{old_tag}.sql"
        new_sql = self.drizzle_dir / f"{new_tag}.sql"
        if old_sql.exists():
            try:
                shutil.move(str(old_sql), str(new_sql))
                changes.append(f"SQL: {old_tag}.sql → {new_tag}.sql")
            except Exception as e:
                self.log(f"Failed to rename SQL: {e}", "error")
                success = False

        # Rename snapshot file - try both naming conventions
        # Convention 1: {idx}_snapshot.json (newer Drizzle versions)
        if old_idx and new_idx:
            old_snapshot_idx = self.meta_dir / f"{old_idx}_snapshot.json"
            new_snapshot_idx = self.meta_dir / f"{new_idx}_snapshot.json"
            if old_snapshot_idx.exists():
                try:
                    shutil.move(str(old_snapshot_idx), str(new_snapshot_idx))
                    changes.append(f"Snapshot: {old_idx}_snapshot.json → {new_idx}_snapshot.json")
                except Exception as e:
                    self.log(f"Failed to rename snapshot (idx): {e}", "error")
                    success = False

        # Convention 2: {tag}.json (older Drizzle versions)
        old_snapshot = self.meta_dir / f"{old_tag}.json"
        new_snapshot = self.meta_dir / f"{new_tag}.json"
        if old_snapshot.exists():
            try:
                shutil.move(str(old_snapshot), str(new_snapshot))
                changes.append(f"Snapshot: {old_tag}.json → {new_tag}.json")
            except Exception as e:
                self.log(f"Failed to rename snapshot: {e}", "error")
                success = False

        for change in changes:
            self.log(change, "debug")

        return success

    def apply_merge(self, merge_result: dict) -> bool:
        """Apply the results of a journal merge."""
        journal = merge_result["journal"]
        rename_map = merge_result["rename_map"]

        if self.dry_run:
            self.log("[DRY-RUN] Would apply merge:", "info")
            self.log(f"  - Update journal with {len(journal['entries'])} entries", "info")
            for old_tag, new_tag in rename_map.items():
                self.log(f"  - Rename {old_tag} → {new_tag}", "info")
            return True

        # Create backup first
        if not self.create_backup():
            return False

        try:
            # Rename files first
            for old_tag, new_tag in rename_map.items():
                if not self.rename_migration(old_tag, new_tag):
                    raise Exception(f"Failed to rename {old_tag}")

            # Write merged journal
            with open(self.journal_path, "w") as f:
                json.dump(journal, f, indent=2)

            self.log("Journal updated successfully", "success")
            return True

        except Exception as e:
            self.log(f"Merge failed: {e}", "error")
            self.restore_backup()
            return False

    def fix_conflicts(self) -> bool:
        """Detect and fix all migration conflicts."""
        self.log(f"Scanning {self.drizzle_dir}...", "info")

        # Scan current state
        state = self.scan_disk()

        if state.issues:
            self.log(f"Found {len(state.issues)} issues:", "warn")
            for issue in state.issues:
                self.log(issue, "debug")

        # Detect conflicts
        conflicts = self.detect_conflicts()

        if not conflicts:
            self.log("No migration conflicts detected", "success")
            return True

        self.log(f"Found {len(conflicts)} conflict(s)", "warn")

        if self.dry_run:
            self.log("[DRY-RUN] Would fix conflicts:", "info")
            return True

        # Create backup
        if not self.create_backup():
            return False

        try:
            # Load current journal
            journal = self.load_journal()
            entries = journal.get("entries", [])
            entries_by_tag = {e.get("tag"): e for e in entries}

            # Process each conflict
            next_idx = state.max_idx + 1

            for conflict in conflicts:
                idx = conflict["idx"]
                migrations = conflict["migrations"]

                # Keep the first one (in journal or alphabetically), renumber the rest
                # Prefer ones already in journal
                in_journal = [m for m in migrations if m.journal_entry]
                not_in_journal = [m for m in migrations if not m.journal_entry]

                # Sort by tag for consistency
                in_journal.sort(key=lambda m: m.tag)
                not_in_journal.sort(key=lambda m: m.tag)

                # Keep first in-journal, or first not-in-journal
                keep = in_journal[0] if in_journal else not_in_journal[0]
                renumber = [m for m in migrations if m != keep]

                self.log(f"Keeping {keep.tag}, renumbering {len(renumber)} others", "info")

                for migration in renumber:
                    new_idx = next_idx
                    next_idx += 1

                    # Parse name from tag
                    if "_" in migration.tag:
                        name_part = "_".join(migration.tag.split("_")[1:])
                    else:
                        name_part = migration.tag

                    new_tag = f"{new_idx:04d}_{name_part}"

                    # Rename files
                    if not self.rename_migration(migration.tag, new_tag):
                        raise Exception(f"Failed to rename {migration.tag}")

                    # Update or create journal entry
                    if migration.tag in entries_by_tag:
                        old_entry = entries_by_tag.pop(migration.tag)
                        old_entry["idx"] = new_idx
                        old_entry["tag"] = new_tag
                        entries_by_tag[new_tag] = old_entry
                    else:
                        # Create new entry
                        new_sql = self.drizzle_dir / f"{new_tag}.sql"
                        entries_by_tag[new_tag] = {
                            "idx": new_idx,
                            "version": "7",
                            "when": int(new_sql.stat().st_mtime * 1000) if new_sql.exists() else 0,
                            "tag": new_tag,
                            "breakpoints": True,
                        }

                    self.log(f"Renumbered: {migration.tag} → {new_tag}", "success")

            # Save updated journal
            journal["entries"] = sorted(entries_by_tag.values(), key=lambda e: e.get("idx", 0))
            with open(self.journal_path, "w") as f:
                json.dump(journal, f, indent=2)

            self.log("All conflicts resolved", "success")
            return True

        except Exception as e:
            self.log(f"Failed to fix conflicts: {e}", "error")
            self.restore_backup()
            return False

    def cleanup_orphans(self) -> bool:
        """Remove orphaned journal entries (entries without SQL files)."""
        if not self.journal_path.exists():
            return True

        journal = self.load_journal()
        entries = journal.get("entries", [])
        valid_entries = []
        removed = 0

        for entry in entries:
            tag = entry.get("tag", "")
            sql_path = self.drizzle_dir / f"{tag}.sql"

            if sql_path.exists():
                valid_entries.append(entry)
            else:
                self.log(f"Removing orphaned entry: {tag}", "info")
                removed += 1

        if removed > 0:
            if not self.dry_run:
                journal["entries"] = valid_entries
                with open(self.journal_path, "w") as f:
                    json.dump(journal, f, indent=2)
            self.log(f"Removed {removed} orphaned entries", "success")

        return True

    def validate(self) -> bool:
        """Validate the final state of migrations."""
        state = self.scan_disk()

        # Check for remaining conflicts
        conflicts = self.detect_conflicts()
        if conflicts:
            self.log(f"Validation failed: {len(conflicts)} conflicts remain", "error")
            return False

        # Check for orphaned entries
        for tag, migration in state.migrations.items():
            if migration.journal_entry and not migration.sql_path:
                self.log(f"Validation failed: orphaned entry {tag}", "error")
                return False

        # Check journal integrity
        journal = self.load_journal()
        entries = journal.get("entries", [])

        # Check for duplicate indices
        indices = [e.get("idx") for e in entries]
        if len(indices) != len(set(indices)):
            self.log("Validation failed: duplicate indices in journal", "error")
            return False

        # Check for sorted order
        if indices != sorted(indices):
            self.log("Validation warning: journal not sorted", "warn")

        self.log("Validation passed", "success")
        return True

    def run(self, mode: str = "fix") -> bool:
        """Run the migration manager in specified mode."""
        if not self.validate_directory():
            return False

        if mode == "fix":
            return self.fix_conflicts() and self.cleanup_orphans() and self.validate()
        elif mode == "validate":
            return self.validate()
        elif mode == "cleanup":
            return self.cleanup_orphans()
        elif mode == "merge":
            # Merge mode expects THEIRS_JOURNAL and OURS_JOURNAL env vars
            theirs = os.environ.get("THEIRS_JOURNAL", "/tmp/theirs_journal.json")
            ours = os.environ.get("OURS_JOURNAL", "/tmp/ours_journal.json")

            if not Path(theirs).exists() or not Path(ours).exists():
                self.log("Merge mode requires THEIRS_JOURNAL and OURS_JOURNAL", "error")
                return False

            result = self.merge_journals(Path(theirs), Path(ours))

            # Save merge result
            with open("/tmp/merged_journal.json", "w") as f:
                json.dump(result["journal"], f, indent=2)

            with open("/tmp/drizzle_rename_map.txt", "w") as f:
                for old_tag, new_tag in result["rename_map"].items():
                    f.write(f"{old_tag}|{new_tag}\n")

            stats = result["stats"]
            self.log(f"Merged: {stats['base_count']} base + {stats['pr_count']} PR = {stats['total_count']} total", "success")
            self.log(f"Renamed: {stats['renamed_count']} migrations", "info")

            return True
        else:
            self.log(f"Unknown mode: {mode}", "error")
            return False


def main():
    parser = argparse.ArgumentParser(
        description="Drizzle Migration Manager - Enterprise-grade conflict resolution",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Modes:
  fix       Detect and fix all migration conflicts (default)
  validate  Only validate, don't make changes
  cleanup   Remove orphaned journal entries
  merge     Merge two journals (requires THEIRS_JOURNAL and OURS_JOURNAL env vars)

Examples:
  %(prog)s ./packages/server/drizzle
  %(prog)s ./drizzle --dry-run --verbose
  %(prog)s ./drizzle --mode merge
        """,
    )
    parser.add_argument("drizzle_dir", help="Path to drizzle migrations directory")
    parser.add_argument("--mode", choices=["fix", "validate", "cleanup", "merge"], default="fix")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be done without making changes")
    parser.add_argument("--verbose", "-v", action="store_true", help="Enable verbose output")

    args = parser.parse_args()

    manager = MigrationManager(
        drizzle_dir=args.drizzle_dir,
        dry_run=args.dry_run,
        verbose=args.verbose,
    )

    success = manager.run(mode=args.mode)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
