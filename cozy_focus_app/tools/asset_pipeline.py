
"""Cozy Focus companion asset pipeline: flat-background extraction + canvas normalisation."""
import json, os, sys
from collections import deque
import numpy as np
from PIL import Image, ImageFilter

CANVAS = 1024
SUBJECT_HEIGHT_FRACTION = 0.78   # of canvas
BASELINE_Y_FRACTION = 0.90       # of canvas


def estimate_background(arr):
    h, w, _ = arr.shape
    k = max(4, min(h, w) // 40)
    corners = np.concatenate([
        arr[:k, :k].reshape(-1, 3), arr[:k, -k:].reshape(-1, 3),
        arr[-k:, :k].reshape(-1, 3), arr[-k:, -k:].reshape(-1, 3),
    ])
    return np.median(corners, axis=0)


def extract_alpha(path, tol=26, feather=1.2):
    im = Image.open(path).convert("RGB")
    arr = np.asarray(im).astype(np.int16)
    bg = estimate_background(arr)
    dist = np.sqrt(((arr - bg) ** 2).sum(axis=2))
    similar = dist < tol

    h, w = similar.shape
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
        for dy, dx in ((1,0),(-1,0),(0,1),(0,-1)):
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
    target_h = int(canvas * SUBJECT_HEIGHT_FRACTION)
    scale = target_h / crop.height
    if crop.width * scale > canvas * 0.96:
        scale = (canvas * 0.96) / crop.width
    nw, nh = max(1, round(crop.width * scale)), max(1, round(crop.height * scale))
    crop = crop.resize((nw, nh), Image.LANCZOS)
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    x = (canvas - nw) // 2
    y = int(canvas * BASELINE_Y_FRACTION) - nh
    out.alpha_composite(crop, (max(0, x), max(0, y)))
    return out


def measure(png):
    a = np.asarray(png.split()[-1])
    ys, xs = np.nonzero(a > 8)
    return {
        "canvas": [png.width, png.height],
        "visualBounds": [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())],
        "centerX": float((xs.min() + xs.max()) / 2),
        "bottomY": int(ys.max()),
        "visualWidth": int(xs.max() - xs.min() + 1),
        "visualHeight": int(ys.max() - ys.min() + 1),
        "opaqueFraction": float((a > 200).mean()),
    }


if __name__ == "__main__":
    src, dst, meta_out = sys.argv[1], sys.argv[2], sys.argv[3]
    rgba, bg = extract_alpha(src)
    norm = normalise(rgba)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    norm.save(dst)
    m = measure(norm)
    m["source"] = os.path.basename(src)
    m["estimatedBackground"] = [float(v) for v in bg]
    json.dump(m, open(meta_out, "w", encoding="utf-8"), indent=2)
    print(json.dumps(m, indent=2))

