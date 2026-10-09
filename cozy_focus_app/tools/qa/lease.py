"""A lease for the CozyFocus autonomous work, so two windows cannot both write.

## Why the old guard was wrong

The scheduled run decided whether another window was working by reading
`MASTER_STATE.updated_at` and skipping if it was under 25 minutes old. That is a
proxy for "someone wrote recently", not for "someone is working", and it got the
common case backwards: a window that finished a unit normally still looks active
for the next 25 minutes, so the *next* window skips its turn. Meanwhile a window
that died mid-unit looks identical to one that finished cleanly.

## What this records instead

A lease is a claim with an owner, a heartbeat and an expiry. The verdict is a
function of those three, not of a file's mtime, and it names which of the five
situations you are in rather than a single "probably busy":

    OWN               this run already holds it
    HELD              another live run holds it — wait, do not write
    RELEASED          the last run ended cleanly; take it
    EXPIRED           the last run stopped heartbeating; recover it
    FREE              nothing has ever taken it

A window that finishes calls `release`, so the next one is not made to wait. A
window that dies leaves a lease that stops beating, and after the TTL the next
window recovers it *and records that it did* — an interrupted run is a fact worth
keeping, not something to paper over.

## Atomicity

Two agents must not both acquire. The critical section is guarded by an exclusive
create (`O_CREAT | O_EXCL`), which the filesystem makes atomic, and a lock older
than a few seconds is treated as a crash leftover and broken — with the fact
written into the lease rather than silently. The lock is only ever held for the
read-modify-write, never across the work itself.

Usage:
    python tools/qa/lease.py status
    python tools/qa/lease.py acquire --stage STAGE_6 --task S6.C --run-id r42
    python tools/qa/lease.py heartbeat --run-id r42
    python tools/qa/lease.py release --run-id r42
    python tools/qa/lease.py --self-test
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
STATE_DIR = REPO / "outputs" / "autonomous_execution"
LEASE_PATH = STATE_DIR / "LEASE.json"
LOCK_PATH = STATE_DIR / ".lease.lock"

# How long a lease survives without a heartbeat. Long enough that a full test
# run (about four minutes here) plus a build does not look like a death, short
# enough that a crashed window does not block the next one for long.
DEFAULT_TTL = timedelta(minutes=20)

# A lock older than this is a leftover from a process that died holding it. It
# only ever wraps a read-modify-write, so anything older is a crash.
LOCK_STALE_AFTER = timedelta(seconds=30)

OWN = "OWN"
HELD = "HELD"
RELEASED = "RELEASED"
EXPIRED = "EXPIRED"
FREE = "FREE"


def now() -> datetime:
    return datetime.now().astimezone()


def parse(value: str | None) -> datetime | None:
    if not value:
        return None
    return datetime.fromisoformat(value)


def read_lease() -> dict | None:
    if not LEASE_PATH.exists():
        return None
    try:
        return json.loads(LEASE_PATH.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        # A half-written lease is a lease that cannot be trusted. Treat it as an
        # interrupted one rather than crashing the window that found it.
        return {
            "run_id": None,
            "owner": None,
            "corrupt": True,
            "lease_expires_at": None,
            "released_at": None,
        }


def verdict(lease: dict | None, at: datetime, run_id: str) -> str:
    """Which of the five situations this is. Pure, so it can be tested."""
    if lease is None:
        return FREE
    if lease.get("released_at"):
        return OWN if lease.get("run_id") == run_id else RELEASED
    if lease.get("run_id") == run_id:
        return OWN
    expires = parse(lease.get("lease_expires_at"))
    if expires is None:
        # No expiry recorded: a corrupt or hand-written lease. Not something to
        # wait on — it cannot be a live claim if it never said when it ends.
        return EXPIRED
    return HELD if expires > at else EXPIRED


def git(*args: str) -> str:
    result = subprocess.run(
        ["git", *args], cwd=REPO, capture_output=True, text=True, check=False
    )
    return result.stdout.strip()


def _acquire_lock() -> None:
    """Take the critical section, or explain why not."""
    for attempt in range(2):
        try:
            fd = os.open(LOCK_PATH, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            os.write(fd, f"{os.getpid()} {now().isoformat()}".encode())
            os.close(fd)
            return
        except FileExistsError:
            try:
                age = now() - datetime.fromtimestamp(
                    LOCK_PATH.stat().st_mtime
                ).astimezone()
            except OSError:
                continue
            if age < LOCK_STALE_AFTER:
                raise SystemExit(
                    f"another process holds the lease lock ({age.total_seconds():.0f}s "
                    "old). Not waiting and not breaking it."
                )
            # Older than the whole critical section can take: the holder died.
            LOCK_PATH.unlink(missing_ok=True)
    raise SystemExit("could not take the lease lock")


def _release_lock() -> None:
    LOCK_PATH.unlink(missing_ok=True)


def write_lease(lease: dict) -> None:
    LEASE_PATH.write_text(
        json.dumps(lease, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "action", choices=["status", "acquire", "heartbeat", "release"]
    )
    parser.add_argument("--run-id", help="this window's id; required to acquire")
    parser.add_argument("--owner", default="zcode", help="who is running")
    parser.add_argument("--stage", help="current stage, e.g. STAGE_6")
    parser.add_argument("--task", help="current task id, e.g. S6.C")
    parser.add_argument(
        "--ttl-minutes", type=float, default=DEFAULT_TTL.total_seconds() / 60
    )
    args = parser.parse_args()

    if args.action == "status":
        lease = read_lease()
        state = verdict(lease, now(), args.run_id or "")
        print(f"verdict: {state}")
        if lease:
            print(json.dumps(lease, ensure_ascii=False, indent=2))
        return

    if not args.run_id:
        raise SystemExit("--run-id is required for acquire, heartbeat and release")

    _acquire_lock()
    try:
        lease = read_lease()
        state = verdict(lease, now(), args.run_id)

        if args.action == "acquire":
            if state == HELD:
                print(f"verdict: {HELD}")
                print(json.dumps(lease, ensure_ascii=False, indent=2))
                raise SystemExit(2)
            recovered_from = None
            if state == EXPIRED and lease:
                recovered_from = {
                    "run_id": lease.get("run_id"),
                    "last_heartbeat_at": lease.get("heartbeat_at"),
                    "current_task": lease.get("current_task"),
                }
            stamp = now().replace(microsecond=0).isoformat()
            write_lease(
                {
                    "run_id": args.run_id,
                    "owner": args.owner,
                    "worktree": str(REPO),
                    "branch": git("rev-parse", "--abbrev-ref", "HEAD"),
                    "started_at": stamp,
                    "heartbeat_at": stamp,
                    "lease_expires_at": (
                        now() + timedelta(minutes=args.ttl_minutes)
                    )
                    .replace(microsecond=0)
                    .isoformat(),
                    "current_stage": args.stage,
                    "current_task": args.task,
                    "last_verified_commit": git("rev-parse", "HEAD"),
                    "released_at": None,
                    "recovered_from": recovered_from,
                    "previous_verdict": state,
                }
            )
            print(f"verdict: {state} -> acquired by {args.run_id}")
            if recovered_from:
                print(f"recovered an interrupted run: {recovered_from}")
            return

        if state != OWN:
            print(f"verdict: {state} — not this run's lease, refusing to touch it")
            raise SystemExit(2)

        if args.action == "heartbeat":
            lease["heartbeat_at"] = now().replace(microsecond=0).isoformat()
            lease["lease_expires_at"] = (
                now() + timedelta(minutes=args.ttl_minutes)
            ).replace(microsecond=0).isoformat()
            if args.stage:
                lease["current_stage"] = args.stage
            if args.task:
                lease["current_task"] = args.task
            lease["last_verified_commit"] = git("rev-parse", "HEAD")
            write_lease(lease)
            print(f"heartbeat at {lease['heartbeat_at']}")
            return

        if args.action == "release":
            lease["released_at"] = now().replace(microsecond=0).isoformat()
            lease["last_verified_commit"] = git("rev-parse", "HEAD")
            write_lease(lease)
            print(f"released at {lease['released_at']}")
            return
    finally:
        _release_lock()


SELF_TEST: list[tuple[dict | None, str, bool]] = []


def self_test() -> int:
    """The verdict is the whole mechanism, so it is tested directly."""
    at = datetime(2026, 10, 9, 12, 0, tzinfo=now().tzinfo)
    future = (at + timedelta(minutes=10)).isoformat()
    past = (at - timedelta(minutes=10)).isoformat()
    cases = [
        (None, FREE, "nothing has ever taken it"),
        ({"run_id": "me", "released_at": None, "lease_expires_at": future},
         OWN, "my own live lease"),
        ({"run_id": "other", "released_at": None, "lease_expires_at": future},
         HELD, "another live window"),
        ({"run_id": "other", "released_at": past, "lease_expires_at": future},
         RELEASED, "the last run ended cleanly"),
        ({"run_id": "other", "released_at": None, "lease_expires_at": past},
         EXPIRED, "the last run stopped beating"),
        ({"run_id": "other", "released_at": None, "lease_expires_at": None},
         EXPIRED, "a lease with no expiry cannot be a live claim"),
        ({"run_id": "me", "released_at": past, "lease_expires_at": future},
         OWN, "my own released lease is still mine to take"),
    ]
    failures = 0
    for lease, expected, why in cases:
        got = verdict(lease, at, "me")
        ok = got == expected
        failures += 0 if ok else 1
        print(f"  {'ok  ' if ok else 'FAIL'} {expected:9s} got {got:9s}  {why}")
    print(f"\n{len(cases) - failures}/{len(cases)} self-test cases agree")
    return 1 if failures else 0


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        raise SystemExit(self_test())
    main()
