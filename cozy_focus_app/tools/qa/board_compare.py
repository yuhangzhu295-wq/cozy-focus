"""Build a side-by-side of a design board and the app's device screenshot.

Both are scaled to the same height so element positions can be compared directly.
The board goes on the left, the app on the right, with a divider.
"""
import argparse
import os
import sys

from PIL import Image

DEV = r'C:\Users\zyu33\Downloads\CozyFocus_2_0_Zxode_DevPack_v2\CozyFocus_2_0_Zxode_DevPack_v2\01_FINAL_16_DESIGNS'
APP = r'C:\Users\zyu33\Documents\Codex\2026-09-07\new-chat\cozy_focus_app'
OUT = os.path.join(APP, 'outputs', 'visual_qa', 'compare')

BOARDS = {
    'home': '01_HOME_OPTIMIZED.png',
    'tasks': '02_TASK_LIST.png',
    'today': '03_TODAY_PLAN.png',
    'focus': '04_FOCUS_MODE.png',
    'capture': '05_DISTRACTION_CAPTURE.png',
    'review': '06_FOCUS_REVIEW.png',
    'records': '07_ANALYTICS_LITE.png',
    'rest': '08_FREE_TIME.png',
    'timeline': '09_TIMELINE.png',
    'growth': '10_PET_ROOM_OPTIMIZED.png',
    'create_task': '11_CREATE_TASK.png',
    'task_detail': '12_TASK_DETAIL.png',
    'inbox': '13_DISTRACTION_INBOX.png',
    'schedule': '14_SCHEDULE_TO_TODAY.png',
    'settings': '15_SETTINGS_LITE.png',
    'empty': '16_EMPTY_STATE.png',
}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('key', help='board key, e.g. home')
    ap.add_argument('--app', required=True, help='path to the app screenshot')
    ap.add_argument('--height', type=int, default=1400)
    a = ap.parse_args()

    if a.key not in BOARDS:
        print(f'unknown key; known: {", ".join(sorted(BOARDS))}', file=sys.stderr)
        return 2

    board = Image.open(os.path.join(DEV, BOARDS[a.key])).convert('RGB')
    shot = Image.open(a.app).convert('RGB')

    def fit(im):
        w = round(im.width * a.height / im.height)
        return im.resize((w, a.height), Image.LANCZOS)

    b, s = fit(board), fit(shot)
    canvas = Image.new('RGB', (b.width + s.width + 16, a.height), (255, 255, 255))
    canvas.paste(b, (0, 0))
    canvas.paste(s, (b.width + 16, 0))

    os.makedirs(OUT, exist_ok=True)
    dest = os.path.join(OUT, f'{a.key}_vs_board.png')
    canvas.save(dest)
    print(f'{dest}  board {board.size} -> {b.size}, app {shot.size} -> {s.size}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
