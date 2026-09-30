"""Build the approved Cozy Focus master identity reference.

The reference is the approved V4.1 Mochi rig — the seven transparent layers under
assets/mochi/base/ — composited onto one square canvas. It is deliberately *not* a
crop of a design page: a page crop carries scene background and UI text by
construction, which the asset brief forbids.
"""
import json, os, sys

from PIL import Image

APP = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(APP, "assets", "mochi", "base")
CANVAS = 1024
SUBJECT_HEIGHT_FRACTION = 0.70


def composite() -> Image.Image:
    meta = json.load(open(os.path.join(BASE, "layers.json"), encoding="utf-8"))
    canvas = None
    for name in meta["z_order"]:
        path = os.path.join(BASE, os.path.basename(meta["layers"][name]["file"]))
        layer = Image.open(path).convert("RGBA")
        canvas = layer if canvas is None else Image.alpha_composite(canvas, layer)
    if canvas is None:
        raise SystemExit("no layers found")
    return canvas


def square_reference(rgba: Image.Image, background):
    bbox = rgba.getbbox()
    crop = rgba.crop(bbox)
    scale = (CANVAS * SUBJECT_HEIGHT_FRACTION) / crop.height
    size = (max(1, round(crop.width * scale)), max(1, round(crop.height * scale)))
    crop = crop.resize(size, Image.LANCZOS)
    inner = crop.getbbox()
    out = Image.new("RGBA", (CANVAS, CANVAS), background)
    out.alpha_composite(
        crop,
        ((CANVAS - (inner[2] - inner[0])) // 2 - inner[0],
         (CANVAS - (inner[3] - inner[1])) // 2 - inner[1]),
    )
    return out


if __name__ == "__main__":
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(APP, ".asset_staging", "refs")
    os.makedirs(out_dir, exist_ok=True)
    rig = composite()
    square_reference(rig, (255, 255, 255, 255)).convert("RGB").save(
        os.path.join(out_dir, "mochi_master_ref_white.png"))
    square_reference(rig, (0, 0, 0, 0)).save(
        os.path.join(out_dir, "mochi_master_ref_alpha.png"))
    print("wrote master reference to", out_dir)
