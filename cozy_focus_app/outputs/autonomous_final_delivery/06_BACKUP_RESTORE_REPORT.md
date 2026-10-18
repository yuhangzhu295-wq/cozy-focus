# 06 — Local backup and restore

**Status: implemented, unit-tested in isolation, and walked end to end on the
emulator. Not cloud sync, and it does not claim to be.**

## What it is

A single versioned JSON file the user saves where they choose. It contains the
18 business tables of the local database and the writable companion-pack root.
It contains no credentials, no caches and no `sync_outbox`.

```
format            "cozyfocus.backup"
formatVersion     1
appSchemaVersion  11
appVersion        1.0.0+1
exportedAt        ISO-8601, UTC
tables            { tableName: [row, ...] }   (18 tables)
packs             { ids: [...], files: { relativePath: base64 } }
checksum          sha256 over the canonical JSON of everything above
```

`sync_outbox` is deliberately absent. It holds pending writes, not user data;
replaying queued operations into a restored world would undo the restore.

## Why JSON and not a copy of the `.sqlite` file

A database copy couples a backup to SQLite's page layout, WAL state and the
exact schema. The envelope names its own format version and the app schema
version, so an older app can refuse it in words instead of failing inside
SQLite. The cost is size and speed; the file measured **2.2 KB** on the device,
which is not a problem worth trading correctness for.

## Export

1. `BackupService.export` reads every table with `SELECT * … ORDER BY rowid`.
2. The writable pack root is read recursively and base64-encoded, capped at
   32 MB / 2000 files so a pathological directory cannot become an unbounded
   allocation.
3. The checksum is computed over a canonical encoding (map keys sorted at every
   depth), so the same data hashes the same regardless of column order.
4. `BackupFileService.save` opens the platform file UI. On Android that is
   `ACTION_CREATE_DOCUMENT` in `MainActivity`, which grants access to the one
   file the user picked and requires **no storage permission**. Elsewhere it is
   `file_selector`.
5. The UI reports the byte count and the exact location, or "已取消" if the user
   backed out.

## Restore

The order is the safety property:

1. **Size** (≤ 64 MB) and **JSON parse**.
2. **Envelope**: `format`, `formatVersion` (1 only; a newer file is refused with
   "please update the app"), `appSchemaVersion` (must equal 11; V1 refuses
   cross-version restores rather than migrating blind).
3. **Checksum**: recomputed over the payload without the checksum field.
4. **Shape**: every table present, every row a map, every pack path relative and
   free of `..`.
5. **Preview** shown to the user: export time, total rows, per-table counts,
   pack count.
6. **Explicit confirmation** ("当前数据会被完整替换，且无法撤销").
7. **Live-session check** — re-run immediately before writing. A running,
   paused or restored focus session refuses the restore.
8. **Column check** against `PRAGMA table_info` before any delete. A backup that
   names a column this build does not have is refused.
9. **Pack staging**: files are written to a sibling `.cozy_restore_*` directory,
   with the decoded size estimated **before** decoding and the path checked
   again after canonicalisation.
10. **One database transaction**: re-check unsettled work, write the journal
    (epoch, old root, staging root, `hadLive`), swap the packs, delete
    children-first (including `sync_outbox`), insert parents-first, verify every
    table's row count, and write the epoch marker — all before commit. The swap
    is inside the transaction so SQLite serialises it against every other
    writer. A mismatch throws, the transaction rolls back, and the packs are
    swapped back.
11. **Cleanup**: the old root and the journal are deleted; a cleanup failure is
    harmless because the committed state already agrees.
13. **Crash recovery** (`recoverInterruptedRestore`, called from `main()` before
    the app opens its connection): if the journal's epoch is in `app_settings`,
    the data committed and the new packs stay; if not, the old packs are
    restored and the staging directory removed. A crash before the first rename
    leaves the live root untouched.

The UI then invalidates the data controllers (`home`, `craft`, `growth`,
`records`, `analytics`, `timeline`, `today plan`, `distraction`, `rest`,
`tasks`, preferences, installed packs, selection, room simulation) so every page
re-reads the restored rows instead of showing a cached total.

## Tests

`test/data/backup/backup_round_trip_test.dart` — **24 tests**, all isolated
(in-memory database, temporary directories):

| Test | What it proves |
|---|---|
| empty database round-trips | a backup of nothing is valid and restores |
| populated database round-trips table by table | 18 tables, byte-identical rows |
| a changed byte is refused and the target is untouched | checksum catches tampering; no write happens |
| a newer format version is refused | forward compatibility is explicit |
| a different schema version is refused | no silent migration |
| a restore is refused while a focus session is live | the timer's row is never replaced under it |
| a backup naming a column this build does not have is refused | schema-shape check |
| a failure halfway through rolls the whole replacement back | duplicate unique key → original rows survive |
| restoring the same backup twice is idempotent | no duplication |
| custom packs travel and are replaced, not merged | stale files are gone |
| the checksum is stable across two exports | canonical encoding |
| a pack path that escapes the root is refused on every platform | six shapes, including the Windows backslash case |
| a finishing session refuses the restore | its unsaved focus time is protected |
| a running rest refuses the restore | the rest row is protected |
| a restore clears the target device pending outbox | no pre-restore write is replayed |
| crash: data committed | new packs kept, old dropped, journal cleared |
| crash: data not committed | old packs restored, journal cleared |
| crash on the first restore, after the swap | the new root is removed, journal cleared |
| crash before the swap | live root untouched, staging removed |
| a stale journal (swap marker disagrees) | nothing deleted, journal kept |
| an unreadable journal | kept, not cleared |
| a refused restore | staging directory removed |

## Device walk

Performed on `emulator-5554`, package `com.yuhangzhu295.cozyfocus`:

1. Settings → 数据与同步 → 导出备份.
2. The system save dialog opened with
   `cozyfocus-20261017-1810.cozybackup`; saved to Downloads.
   `adb shell ls -l /sdcard/Download/` showed **2207 bytes**.
3. Created a task `backup-test` after the export.
4. 从备份恢复 → picked the file → preview: *备份时间 2026-10-17 18:10, 共 10 条记录*.
5. Confirmed → *恢复完成, 已写入 10 条记录*.
6. Opened the task list: **empty** — the task created after the backup was gone,
   so the restore replaced rather than merged.

Screenshots: `device/01_data_sync_page.png`, `device/02_export_save_dialog.png`,
`device/03_restore_preview.png`.

## What is not done, and is not claimed

- **No cloud sync.** The page still says so.
- **No merge.** V1 replaces. The confirmation says so.
- **No backup encryption.** The file is plain JSON; the user chooses where it
  goes. Encrypting it would require a key-management decision that is not in the
  V1 brief.
- **No scheduled/automatic backup.** Not requested, and a background writer
  would need its own retention policy.
- **Restore does not migrate an old schema.** It refuses, which the brief allows.
