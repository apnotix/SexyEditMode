"""Erzeugt media/bar.tga: Leistentextur fuer SexyEditMode:ShineBar (Fuellung von StatusBars).

Weiss mit senkrechtem Helligkeitsverlauf: helle Kante oben, nach unten dunkler, ganz unten eine feine Aufhellung.
Die Leiste faerbt sie ueber SetStatusBarColor ein.
"""
import struct

W, H = 64, 32

def brightness(y):
    if y == 0:
        return 1.0
    if y == 1:
        return 0.97
    if y >= H - 1:
        return 0.80   # feine Spiegelung ganz unten
    t = (y - 2) / (H - 4)
    return 0.95 - (0.95 - 0.66) * (t ** 0.9)

rows = []
for y in range(H):
    v = round(255 * brightness(y))
    rows.append(bytes((v, v, v, 255)) * W)   # B, G, R, A

header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, W, H, 32, 0x28)
with open("media/bar.tga", "wb") as f:
    f.write(header)
    for r in rows:
        f.write(r)
print("media/bar.tga", W, "x", H)
