
"""Emit assets/companions/<companion>/manifest.json from the production report."""
import json, os, sys

APP = r"C:\Users\zyu33\Documents\Codex\2026-09-07\new-chat\cozy_focus_app"

# Per-action playback contract (spec §22 frame targets, §41 manifest fields).
ACTION_SPEC = {
    # `idle` is rendered by the approved layered rig, whose whole content is
    # micro-motion (breathe, blink, ear twitch, sprout sway) and whose cadence
    # comes from the real growth stage. The pack carries one canonical idle
    # drawing for archival and fallback use, so its target is 1, not 3: the
    # animation for this action lives in the renderer, not in a frame sequence.
    "idle":        {"fps": 5, "loop": "loop",      "frames": 1},
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
            "interruptible": action not in ("celebrate",),
            "overlayBehavior": "pause",
            "returnBehavior": "resume",
            "reducedMotionFrames": [0],
        }

    canvas = rep["frames"][0]["canvas"] if rep["frames"] else [1024, 1024]
    bottoms = [f["bottomY"] for f in rep["frames"]]
    centers = [f["centerX"] for f in rep["frames"]]
    manifest = {
        "companionId": companion,
        "posePack": {"dog": "mochi", "cat": "cat", "rabbit": "rabbit"}[companion],
        "canvas": {"width": canvas[0], "height": canvas[1]},
        "groundBaseline": int(round(sum(bottoms) / len(bottoms))) if bottoms else 919,
        "centerAnchor": int(round(sum(centers) / len(centers))) if centers else 511,
        "actions": actions,
        "semanticFallback": SEMANTIC_FALLBACK,
        "drawAliases": DRAW_ALIASES,
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

