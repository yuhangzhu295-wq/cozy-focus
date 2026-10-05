"""Negative proof for the pack geometry contract.

Run: python tools/test_manifest_geometry.py

## What this is for

`tools/manifest.py` used to write the manifest's `groundBaseline` and
`centerAnchor` as the *mean of the frames it had just measured*. That is a pack
verifying itself against itself: if every frame drifted together, the manifest
drifted with them, the two agreed, and the drift shipped.

The fix is that the expected geometry comes from the pack's own contract -
`assets/companions/<companion>/animation_manifest.json`, written before the frames
are produced - and the measurement is checked against it.

So the proof that matters is not "a correct pack passes". It is **"a pack whose
frames have all shifted by the same amount fails"**, which is precisely the case
the old code could not detect. That is the last assertion here.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import manifest  # noqa: E402  (path set up above)


def main():
    contract = manifest.load_contract("dog")
    print(f"contract for dog: {contract}")

    # 1. A pack that matches its contract passes.
    matching = {
        "groundBaseline": contract["groundBaseline"],
        "centerAnchor": contract["centerAnchor"],
        "canvas": contract["canvas"],
    }
    problems = manifest.check_geometry(measured=matching, contract=contract)
    assert problems == [], f"a matching pack must pass, got {problems}"

    # 2. A single field outside tolerance fails.
    off = dict(matching, groundBaseline=contract["groundBaseline"] + 40)
    assert manifest.check_geometry(measured=off, contract=contract), (
        "a baseline outside tolerance must fail"
    )

    # 3. A different canvas fails.
    wrong_canvas = dict(matching, canvas=[1024, 1024])
    assert manifest.check_geometry(measured=wrong_canvas, contract=contract), (
        "a canvas that disagrees with the contract must fail"
    )

    # 4. THE NEGATIVE PROOF. Every frame shifted by the same amount - which is
    #    what a consistently wrong production run produces, and what the old
    #    self-certifying code would have written straight into the manifest.
    shift = 40
    shifted = {
        "groundBaseline": contract["groundBaseline"] + shift,
        "centerAnchor": contract["centerAnchor"] + shift,
        "canvas": contract["canvas"],
    }
    problems = manifest.check_geometry(measured=shifted, contract=contract)
    assert problems, (
        "a uniformly shifted pack must fail - this is the case the manifest "
        "could previously certify against itself"
    )
    print(f"uniform shift of {shift}px correctly refused: {problems}")

    # 5. Tolerance is the contract's own, so a pack that declares a tighter one
    #    is held to it rather than to a number chosen here.
    tight = dict(contract, anchorTolerancePx=0)
    within = dict(matching, groundBaseline=contract["groundBaseline"] + 1)
    assert manifest.check_geometry(measured=within, contract=tight), (
        "a contract with zero tolerance must refuse a 1px difference"
    )

    print("OK: geometry is verified against the contract, not against itself")


if __name__ == "__main__":
    main()
