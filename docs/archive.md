# Archived project history

The November 9 consolidation replaces hundreds of overlapping milestone notes with the [topic guides](README.md). The originals are preserved byte-for-byte in one [ZIP archive](archive/project-notes-2026-11-09.zip). The [manifest](archive/manifest.json) records original paths, titles, sizes, SHA-256 values and topic destinations.

All 990 original files were read back and hash-verified before removal. The archive includes the pre-cleanup versions of retained guides as well. This preserves existing staged/unstaged Markdown content without treating contradictory historical statuses as current.

## Read a note

From the repository root:

```powershell
.\scripts\read-archived-note.ps1 -Path godot-client/NATIVE-SPECIAL-ATTACKS.md
.\scripts\read-archived-note.ps1 -List '*level-up*'
```

The reader verifies the archive and selected file hash. It prints text and does not restore files.

For a historical checkpoint requiring files on disk, extract into a new scratch directory:

```powershell
Expand-Archive -LiteralPath docs/archive/project-notes-2026-11-09.zip -DestinationPath .cache/historical-notes-2026-11-09
```

That directory is historical input, not the current project. Do not overwrite active source/docs, change old receipt pins, or interpret a recovered “pass” as acceptance of later code.

## What remains live

Current topic guides; the two short launch overviews; entity API and generated flags; extension/performance-queue instructions; a compact current performance goal; and a small set of tool-pinned notes remain Markdown.

Three short compatibility pointers preserve links from a hash-pinned camera/lifecycle reference. They intentionally point to canonical guides rather than reproducing the removed logs.

The cleanup leaves runtime code, native libraries, original resources, raw reports, fixture histories, caches, backups and third-party dependencies alone. Some old checkpoint/sealing scripts intentionally refer to archived paths and require their historical input tree.

## Historical test workbenches

The November 12 cleanup preserves 264 historical test and workbench files in [one ZIP](archive/test-workbenches-2026-11-12.zip), with original paths, sizes and SHA-256 hashes in the [test manifest](archive/test-workbenches-manifest.json). All entries were read back and hash-verified before removal. Retained harnesses and build tools keep their referenced dependencies; recently active NWN-62, NWN-64 and NWN-71 work remains live.

Read or find a source file without restoring it:

```powershell
.\scripts\read-archived-note.ps1 -Collection tests -List '*nwn61*'
.\scripts\read-archived-note.ps1 -Collection tests -Path godot-client/tests/nwn61_entity_entry_test.gd
```

For historical reproduction, extract into a new scratch directory:

```powershell
Expand-Archive -LiteralPath docs/archive/test-workbenches-2026-11-12.zip -DestinationPath .cache/historical-tests-2026-11-12
```

The archive contains selected historical sources, not a self-contained runnable project. Supply their pinned source versions, local fixtures and runtime separately. Do not overwrite active files or change historical receipt hashes.

## Documentation policy

Update one existing topic guide and the appropriate Linear issue. Record run-specific detail in JSON/log receipts. Add a separate Markdown document only for a durable operational API/contract that cannot fit an existing guide. Avoid new per-turn goals, handoffs, acceptance summaries or duplicate “latest status” files.
