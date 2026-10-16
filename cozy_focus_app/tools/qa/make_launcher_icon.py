"""Draw the launcher-icon candidate: Mochi's sprout on a warm cream field.

## Why this is drawn rather than generated

The release audit lists the launcher icon as `BLOCKED_EXTERNAL` because it needs
*owner-approved artwork*. The brief for this round asks for an **original
candidate** consistent with the Mochi brand, explicitly not marked as final.

The image-generation tool was unavailable this session (see
`ROOM_CANDIDATE_RECOMMENDATION.md` §1 — the desktop app could not receive input
and every API key is rejected), so the candidate is drawn, which is also how the
rest of this app's art is made.

## What the mark is

The companion's own silhouette and its most recognisable feature: a rounded white
head with the two-leaf sprout it grows. Nothing is traced from a board and no
third-party asset is used.

It is deliberately simple, because a launcher icon is seen at 48dp: a silhouette
and one green accent survive that size, and anything finer turns to mush.

## Sizes

Android needs one PNG per density. `mdpi` is 48dp, and the densities are the
usual 1x/1.5x/2x/3x/4x.

Usage:
    python tools/qa/make_launcher_icon.py
"""
import os

from PIL import Image, ImageDraw, ImageFilter

APP = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(APP, "outputs", "launcher_icon_candidate")

# From the app's own palette: the warm page background and the two greens the
# sprout uses, so the icon and the product are the same family.
CREAM_TOP = (251, 248, 242)
CREAM_BOTTOM = (240, 228, 208)
HEAD = (255, 252, 246)
HEAD_SHADE = (233, 220, 199)
HEAD_EDGE = (214, 196, 170)
BLUSH = (246, 208, 196)
INK = (92, 74, 58)
LEAF = (94, 138, 82)
LEAF_DARK = (68, 113, 75)
LEAF_LIGHT = (123, 164, 105)

# mdpi first; the rest are the standard density multipliers.
DENSITIES = {"mdpi": 1.0, "hdpi": 1.5, "xhdpi": 2.0, "xxhdpi": 3.0, "xxxhdpi": 4.0}
BASE = 48
STORE = 512


def _leaf(draw, base, tip, width, colour, curve=0.34):
    """One leaf: a lens shape between `base` and `tip`, bowed to one side."""
    (bx, by), (tx, ty) = base, tip
    mx, my = (bx + tx) / 2, (by + ty) / 2
    dx, dy = tx - bx, ty - by
    nx, ny = -dy, dx
    norm = (nx * nx + ny * ny) ** 0.5 or 1.0
    nx, ny = nx / norm, ny / norm
    ox, oy = nx * width, ny * width
    draw.polygon(
        [
            (bx, by),
            (mx + ox * curve * 2, my + oy * curve * 2),
            (tx, ty),
            (mx - ox * curve * 2, my - oy * curve * 2),
        ],
        fill=colour,
    )


def draw_icon(size):
    """One icon at `size` px, drawn at 4x and downsampled for clean edges.

    ## The first draft failed and this is the fix

    It drew the head as one white ellipse with a crescent of shade. At 48dp that
    is a featureless white blob with a bite out of it - it reads as a broken egg,
    not a companion, because a silhouette with no face is not recognisable and
    the shade crescent read as damage rather than as light.

    A launcher icon has room for about four things. This uses them on the two that
    identify this companion: **the floppy ears and the sprout**, plus the closed
    happy eyes that are its expression everywhere else in the app. The head fills
    the disc instead of floating inside it, so nothing is clipped.
    """
    s = size * 4
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))

    # Background: a warm cream disc, the app's own page tone.
    grad = Image.new("RGBA", (s, s))
    gd = ImageDraw.Draw(grad)
    for i in range(s):
        t = i / max(1, s - 1)
        c = tuple(int(CREAM_TOP[j] + (CREAM_BOTTOM[j] - CREAM_TOP[j]) * t)
                  for j in range(3))
        gd.line([(0, i), (s, i)], fill=c + (255,))
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, s - 1, s - 1], fill=255)
    im = Image.composite(grad, im, mask)

    d = ImageDraw.Draw(im)

    def px(v):
        return s * v

    # Soft shadow under the head so the mark sits on the disc.
    shadow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse(
        [px(0.20), px(0.74), px(0.80), px(0.90)], fill=(96, 74, 50, 80))
    im.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(px(0.030))))

    # Ears first, so the head overlaps their tops and they read as hanging from
    # it rather than being stuck on.
    for sign in (-1, 1):
        cx = px(0.5) + sign * px(0.30)
        d.ellipse([cx - px(0.115), px(0.40), cx + px(0.115), px(0.80)],
                  fill=HEAD, outline=HEAD_EDGE, width=max(1, int(px(0.014))))

    # Head: a wide rounded mound that fills the disc. Wide rather than tall,
    # which is this companion's own proportion.
    head = [px(0.14), px(0.34), px(0.86), px(0.86)]
    d.ellipse(head, fill=HEAD, outline=HEAD_EDGE, width=max(1, int(px(0.016))))

    # Cheeks, low and wide, so the face has a lower half.
    for sign in (-1, 1):
        cx = px(0.5) + sign * px(0.21)
        d.ellipse([cx - px(0.058), px(0.64), cx + px(0.058), px(0.73)],
                  fill=BLUSH)

    # Eyes: the closed happy arcs used throughout the app. Two thick strokes,
    # which is what makes the blob a character at 48dp.
    for sign in (-1, 1):
        cx = px(0.5) + sign * px(0.145)
        d.arc([cx - px(0.072), px(0.50), cx + px(0.072), px(0.63)],
              200, 340, fill=INK, width=max(2, int(px(0.026))))

    # Mouth: a small open smile under and between the eyes.
    d.arc([px(0.455), px(0.60), px(0.545), px(0.70)],
          200, 340, fill=INK, width=max(2, int(px(0.018))))

    # The sprout: stem plus two leaves, the feature that names this companion.
    stem = (px(0.50), px(0.38))
    d.line([stem, (px(0.50), px(0.16))], fill=LEAF_DARK, width=max(2, int(px(0.030))))
    _leaf(d, stem, (px(0.20), px(0.055)), px(0.100), LEAF)
    _leaf(d, stem, (px(0.80), px(0.055)), px(0.100), LEAF)
    _leaf(d, stem, (px(0.25), px(0.085)), px(0.045), LEAF_LIGHT)

    return im.resize((size, size), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    written = []
    for name, mult in DENSITIES.items():
        px = int(round(BASE * mult))
        path = os.path.join(OUT, f"ic_launcher_{name}_{px}.png")
        draw_icon(px).save(path)
        written.append(path)
    store = os.path.join(OUT, f"ic_launcher_store_{STORE}.png")
    draw_icon(STORE).save(store)
    written.append(store)

    print(f"wrote {len(written)} files to {OUT}")
    for p in written:
        with Image.open(p) as im:
            print(f"  {os.path.basename(p):34s} {im.size}")
    print()
    print("CANDIDATE ONLY. The shipped icon is still the stock Flutter logo; "
          "nothing in android/ was touched, and this is not approved art.")


if __name__ == "__main__":
    main()
