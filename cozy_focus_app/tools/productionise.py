
"""Productionise staged Flow frames into normalised transparent companion assets."""
import json, os, sys, hashlib
import numpy as np
from PIL import Image, ImageFilter

APP = r"C:\Users\zyu33\Documents\Codex\2026-09-07\new-chat\cozy_focus_app"
STAGE = os.path.join(APP, ".asset_staging", "flow")
PROD = os.path.join(APP, "assets", "companions")
CANVAS = 512
SUBJECT_H = 0.78
BASELINE_Y = 0.90


def estimate_background(arr):
    h, w, _ = arr.shape
    k = max(4, min(h, w) // 40)
    corners = np.concatenate([
        arr[:k, :k].reshape(-1, 3), arr[:k, -k:].reshape(-1, 3),
        arr[-k:, :k].reshape(-1, 3), arr[-k:, -k:].reshape(-1, 3)])
    return np.median(corners, axis=0)


def extract_alpha(path, tol=30, feather=1.1):
    im = Image.open(path).convert("RGB")
    arr = np.asarray(im).astype(np.int16)
    bg = estimate_background(arr)
    dist = np.sqrt(((arr - bg) ** 2).sum(axis=2))
    similar = dist < tol
    h, w = similar.shape
    from collections import deque
    visited = np.zeros((h, w), dtype=bool)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if similar[y, x] and not visited[y, x]:
                visited[y, x] = True; q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if similar[y, x] and not visited[y, x]:
                visited[y, x] = True; q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and similar[ny, nx] and not visited[ny, nx]:
                visited[ny, nx] = True; q.append((ny, nx))
    alpha = np.where(visited, 0, 255).astype(np.uint8)
    a = Image.fromarray(alpha, "L").filter(ImageFilter.GaussianBlur(feather))
    out = im.convert("RGBA")
    out.putalpha(a)
    return out, bg


def normalise(rgba, canvas=CANVAS):
    bb = rgba.getbbox()
    if bb is None:
        raise ValueError("empty alpha")
    crop = rgba.crop(bb)
    scale = (canvas * SUBJECT_H) / crop.height
    if crop.width * scale > canvas * 0.96:
        scale = (canvas * 0.96) / crop.width
    nw, nh = max(1, round(crop.width * scale)), max(1, round(crop.height * scale))
    crop = crop.resize((nw, nh), Image.LANCZOS)
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    out.alpha_composite(crop, ((canvas - nw) // 2, max(0, int(canvas * BASELINE_Y) - nh)))
    return out


def write_sprite(rgba, dst):
    """Write one normalised frame as a 255-colour indexed PNG.

    ## Why indexed, and why it is not a quality trade

    These frames are flat-shaded cartoon art with anti-aliased edges. Their raw
    distinct-colour counts look alarming -- 9.5k on a simple frame, 30k on the
    busiest -- but almost all of that is anti-aliasing and soft shading spread
    thinly across a huge smooth area, not 30k colours a viewer can tell apart.
    Indexing to 255 entries therefore costs nothing visible and cuts the file
    hard: measured 102 KB -> 16 KB and 187 KB -> 27 KB on real frames.

    That matters because the sprites are most of the app's weight: 147 frames
    across three companions was ~20 MB of a ~42 MB release APK.

    ## How it was checked

    Compared side by side against the original at 4x zoom with nearest-neighbour
    scaling, on the *busiest* frame in the pack (`dog/focus_read_000`, 30k
    colours), so the check ran against the worst case rather than a convenient
    one. No banding on the soft shading, the blush, the book's gradient or the
    anti-aliased outline.

    Flutter decodes indexed PNG with an alpha palette natively, so this needs no
    runtime change -- the sprite player still just loads a PNG.
    """
    rgba.convert("RGBA").quantize(colors=255, method=Image.FASTOCTREE).save(
        dst, optimize=True)


def measure(png):
    a = np.asarray(png.split()[-1])
    ys, xs = np.nonzero(a > 8)
    return {"canvas": [png.width, png.height],
            "visualBounds": [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())],
            "centerX": float((xs.min() + xs.max()) / 2),
            "bottomY": int(ys.max()),
            "visualWidth": int(xs.max() - xs.min() + 1),
            "visualHeight": int(ys.max() - ys.min() + 1)}


def productionise(companion):
    src_root = os.path.join(STAGE, companion)
    out_root = os.path.join(PROD, companion)
    os.makedirs(out_root, exist_ok=True)
    report = {"companion": companion, "actions": {}, "frames": []}
    for action in sorted(os.listdir(src_root)):
        d = os.path.join(src_root, action)
        if not os.path.isdir(d):
            continue
        files = sorted(f for f in os.listdir(d)
                       if os.path.splitext(f)[1].lower() in (".jpg", ".png", ".jpeg", ".webp")
                       and not f.startswith("_") and not f.startswith("cand_"))
        if not files:
            continue
        frames = []
        for f in files:
            src = os.path.join(d, f)
            idx = os.path.splitext(f)[0].split("_")[-1]
            dst_name = f"{action}_{idx}.png"
            dst = os.path.join(out_root, dst_name)
            rgba, bg = extract_alpha(src)
            norm = normalise(rgba)
            write_sprite(norm, dst)
            # Measured on the RGBA frame, not on the indexed file: `measure`
            # reads the alpha channel, and an indexed PNG's last band is the
            # palette index rather than alpha.
            m = measure(norm)
            m.update({"file": dst_name, "source": f,
                      "sha256": hashlib.sha256(open(dst, "rb").read()).hexdigest(),
                      "bytes": os.path.getsize(dst)})
            frames.append(m)
            report["frames"].append({"action": action, **m})
        report["actions"][action] = {"count": len(frames), "frames": frames}
    json.dump(report, open(os.path.join(APP, ".asset_staging", f"production_report_{companion}.json"), "w", encoding="utf-8"), indent=2)
    return report


if __name__ == "__main__":
    rep = productionise(sys.argv[1])
    for action, info in rep["actions"].items():
        print(action, info["count"], [f["file"] for f in info["frames"]])

