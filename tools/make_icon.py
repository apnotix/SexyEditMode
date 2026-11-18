"""Erzeugt icon.png (CurseForge, 512 px) und icon.tga (Spiel, 256 px).

Aufruf:  python tools/make_icon.py
Look der Sexy-Addons: dunkelbraune Fläche, Goldrand, goldenes Vierwege-Kreuz (Verschieben).
Benötigt Pillow.
"""
import os

from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SIZE = 1024          # intern groß zeichnen, dann verkleinern (glatte Kanten)
BG = (36, 26, 17, 255)
BG2 = (58, 43, 27, 255)
GOLD = (232, 194, 106, 255)
EDGE = (200, 162, 74, 255)


def draw():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = SIZE // 7
    d.rounded_rectangle((0, 0, SIZE - 1, SIZE - 1), r, fill=EDGE)
    d.rounded_rectangle((SIZE // 40, SIZE // 40, SIZE - SIZE // 40 - 1, SIZE - SIZE // 40 - 1), r - 8, fill=BG)
    # Titelband oben
    d.rounded_rectangle((SIZE // 40, SIZE // 40, SIZE - SIZE // 40 - 1, SIZE // 5), r - 8, fill=BG2)
    d.rectangle((SIZE // 40, SIZE // 8, SIZE - SIZE // 40 - 1, SIZE // 5), fill=BG2)

    # Vierwege-Pfeil in der Mitte
    cx, cy = SIZE // 2, int(SIZE * 0.56)
    arm, thick, head, headw = int(SIZE * 0.27), int(SIZE * 0.05), int(SIZE * 0.10), int(SIZE * 0.10)
    d.rectangle((cx - arm, cy - thick // 2, cx + arm, cy + thick // 2), fill=GOLD)
    d.rectangle((cx - thick // 2, cy - arm, cx + thick // 2, cy + arm), fill=GOLD)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        tip = (cx + dx * (arm + head), cy + dy * (arm + head))
        bx, by = cx + dx * arm, cy + dy * arm
        if dx:
            pts = [tip, (bx, by - headw), (bx, by + headw)]
        else:
            pts = [tip, (bx - headw, by), (bx + headw, by)]
        d.polygon(pts, fill=GOLD)
    d.ellipse((cx - thick, cy - thick, cx + thick, cy + thick), fill=GOLD)
    return img


def main():
    img = draw()
    img.resize((512, 512), Image.LANCZOS).save(os.path.join(ROOT, "icon.png"))
    img.resize((256, 256), Image.LANCZOS).save(os.path.join(ROOT, "icon.tga"))


if __name__ == "__main__":
    main()
