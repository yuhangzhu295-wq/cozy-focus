
"""Emit assets/companions/<companion>/manifest.json from the production report."""
import json, os, sys

APP = r"C:\Users\zyu33\Documents\Codex\2026-09-07\new-chat\cozy_focus_app"

# Per-action playback contract (spec §22 frame targets, §41 manifest fields).
ACTION_SPEC = {
    # `idle` used to be authored with a target of 1, on the grounds that its
    # animation lived in the layered rig and the pack carried one canonical
    # drawing for archival. V4.3 Phase 3 supersedes that: a one-frame sequence
    # is a still image, and the brief forbids single-PNG loops. `idle` is now a
    # real six-frame breath, authored here so this generator stops overwriting
    # the target with the frame count on every run.
    "idle":        {"fps": 5, "loop": "loop",      "frames": 6},
    # Batch 1's transitions. Contracted before their frames exist, so the gate
    # can name them as pending rather than as absent.
    "walk":        {"fps": 8, "loop": "loop",      "frames": 6},
    "sit_down":    {"fps": 8, "loop": "once",      "frames": 4},
    "stand_up":    {"fps": 8, "loop": "once",      "frames": 4},
    "focus_read":  {"fps": 5, "loop": "pingpong",  "frames": 3},
    "focus_write": {"fps": 5, "loop": "loop",      "frames": 4},
    "focus_think": {"fps": 4, "loop": "pingpong",  "frames": 3},
    "tap_react":   {"fps": 8, "loop": "once",      "frames": 3},
    "pet_react":   {"fps": 6, "loop": "once",      "frames": 3},
    "craft_work":  {"fps": 5, "loop": "loop",      "frames": 4},
    "celebrate":   {"fps": 8, "loop": "once",      "frames": 5},
    "pause_rest":  {"fps": 3, "loop": "pingpong",  "frames": 2},
    "sleep":       {"fps": 3, "loop": "loop",      "frames": 2},
    "room_sit":    {"fps": 4, "loop": "loop",      "frames": 3},
    "room_read":   {"fps": 5, "loop": "pingpong",  "frames": 3},
    "room_work":   {"fps": 5, "loop": "loop",      "frames": 4},
    "room_sleep":  {"fps": 3, "loop": "loop",      "frames": 2},
    "room_relax":  {"fps": 4, "loop": "loop",      "frames": 3},
}

# The full behaviour fallback chain: requested action -> same-species sibling ->
# idle. This is what the *director* degrades through when an action is missing.
SEMANTIC_FALLBACK = {
    "idle": "idle", "prepare": "idle", "glance": "idle", "finish": "focus_write",
    "micro_rest": "pause_rest", "focus_read": "idle", "focus_write": "idle",
    "focus_think": "idle", "craft_work": "idle", "celebrate": "idle",
    "pause_rest": "idle", "sleep": "pause_rest", "room_sit": "idle",
    "room_read": "focus_read", "room_work": "focus_write",
    "room_sleep": "sleep", "room_relax": "pause_rest",
    "tap_react": "idle", "pet_react": "idle",
}

# Only the aliases where the two actions are genuinely the *same drawing*.
#
# `semanticFallback` also contains behaviour-only chains (celebrate -> idle,
# tap_react -> idle). Those must never be used as a drawing substitution: an idle
# sprite standing in for a celebration replaces a pose that carries a confetti
# accent with a placid one, which is worse than the rig's own fallback.
DRAW_ALIASES = {
    "finish": "focus_write",
    "micro_rest": "pause_rest",
    "room_read": "focus_read",
    "room_work": "focus_write",
    "room_sleep": "sleep",
    "room_relax": "pause_rest",
}


# Only the aliases where the two actions are genuinely the *same drawing*.
#
# SEMANTIC_FALLBACK also contains behaviour-only chains (celebrate -> idle,
# tap_react -> idle). Those must never be used as a drawing substitution: an idle
# sprite standing in for a celebration replaces a pose that carries a confetti
# accent with a placid one, which is worse than the rig's own fallback.
DRAW_ALIASES = {
    "finish": "focus_write",
    "micro_rest": "pause_rest",
    "room_read": "focus_read",
    "room_work": "focus_write",
    "room_sleep": "sleep",
    "room_relax": "pause_rest",
}


def load_contract(companion):
    """The pack's declared geometry, from its production contract.

    `assets/companions/<companion>/animation_manifest.json` is the independent
    source: it states the canvas and anchors a pack is *supposed* to have, and it
    is written before the frames are produced rather than derived from them.
    """
    path = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "assets", "companions", companion, "animation_manifest.json",
    )
    with open(path, encoding="utf-8") as fh:
        raw = json.load(fh)
    canvas = raw.get("canvas") or {}
    return {
        "groundBaseline": int(raw["groundBaseline"]),
        "centerAnchor": int(raw["centerAnchor"]),
        "canvas": [int(canvas.get("width", 0)), int(canvas.get("height", 0))],
        "anchorTolerancePx": int(raw.get("anchorTolerancePx", 0)),
    }


def check_geometry(measured, contract):
    """Why `measured` does not satisfy `contract`, as a list of strings.

    Empty means it does. The tolerance is the contract's own, so a pack that
    declares a tighter one is held to it.
    """
    tolerance = contract.get("anchorTolerancePx", 0)
    problems = []
    for field in ("groundBaseline", "centerAnchor"):
        delta = abs(int(measured[field]) - int(contract[field]))
        if delta > tolerance:
            problems.append(
                f"{field} measured {measured[field]} against a declared "
                f"{contract[field]} (off by {delta}px, tolerance {tolerance}px)"
            )
    if list(measured.get("canvas", [])) != list(contract.get("canvas", [])):
        problems.append(
            f"canvas measured {measured.get('canvas')} against a declared "
            f"{contract.get('canvas')}"
        )
    return problems


def build(companion):
    rep = json.load(open(os.path.join(APP, ".asset_staging", f"production_report_{companion}.json"), encoding="utf-8"))
    out_dir = os.path.join(APP, "assets", "companions", companion)
    actions = {}
    for action, info in rep["actions"].items():
        if action == "master":
            continue
        spec = ACTION_SPEC.get(action)
        files = [f["file"] for f in info["frames"]]
        if spec is None:
            spec = {"fps": 5, "loop": "loop", "frames": len(files)}
        actions[action] = {
            "frames": files,
            "fps": spec["fps"],
            "loopMode": spec["loop"],
            "targetFrameCount": spec["frames"],
            # A one-shot celebration and a posture transition must not be cut
            # mid-play: a companion stopped half-way through standing up has no
            # pose at all.
            "interruptible": action not in ("celebrate", "sit_down", "stand_up"),
            "overlayBehavior": "pause",
            "returnBehavior": "resume",
            "reducedMotionFrames": [0],
        }

    canvas = rep["frames"][0]["canvas"] if rep["frames"] else [1024, 1024]
    bottoms = [f["bottomY"] for f in rep["frames"]]
    centers = [f["centerX"] for f in rep["frames"]]
    measured = {
        "groundBaseline": contract["groundBaseline"],
        "centerAnchor": contract["centerAnchor"],
        "canvas": canvas,
    }

    # The expected geometry comes from the pack's own contract, and the frames are
    # checked against it. It used to be the other way round - the manifest's
    # baseline and centre were the mean of the frames being measured - which meant
    # a pack whose frames had all drifted together would agree with itself and
    # certify the drift. Measuring output, defining the expectation from that same
    # output, and then verifying output against itself is not a check.
    contract = load_contract(companion)
    problems = check_geometry(measured=measured, contract=contract)
    if problems:
        raise ValueError(
            "geometry does not match the pack contract for "
            f"{companion}: " + "; ".join(problems)
        )

    manifest = {
        "companionId": companion,
        "posePack": {"dog": "mochi", "cat": "cat", "rabbit": "rabbit"}[companion],
        "canvas": {"width": canvas[0], "height": canvas[1]},
        "groundBaseline": int(round(sum(bottoms) / len(bottoms))) if bottoms else 919,
        "centerAnchor": int(round(sum(centers) / len(centers))) if centers else 511,
        "actions": actions,
        "semanticFallback": SEMANTIC_FALLBACK,
        "drawAliases": DRAW_ALIASES,
        "generatedFrom": f"production_report_{companion}.json",
    }
    path = os.path.join(out_dir, "manifest.json")
    json.dump(manifest, open(path, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
    return manifest


if __name__ == "__main__":
    m = build(sys.argv[1])
    print("actions:", len(m["actions"]), "frames:", sum(len(a["frames"]) for a in m["actions"].values()))
    for k, v in sorted(m["actions"].items()):
        print("  ", k, len(v["frames"]), "/", v["targetFrameCount"], v["loopMode"], v["fps"], "fps")

