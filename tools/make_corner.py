"""Erzeugt media/corner<r>.tga und media/ring<r>.tga fuer r = 3..8: Ecken (oben links) fuer runde Leisten.

corner<r>: weiss, Deckkraft 1 ausserhalb eines Viertelkreises, 0 darin (deckt die Ecke in der Farbe des Untergrunds ab)
ring<r>:   weiss, Deckkraft 1 auf dem Kreisbogen (Randlinie, 1 px breit), sonst 0

Jede Groesse ist auf ihren Radius abgestimmt (4 Texel je Pixel, vorab geglaettet): eine einzige grosse Textur auf
wenige Pixel verkleinert wirkt treppig. SexyEditMode:ShineBar legt vier gespiegelte Kopien auf die Ecken einer Leiste.
"""
import struct

PER = 4    # Texel je Bildschirmpixel
SS = 8     # Ueberabtastung fuer glatte Kanten

def write(name, n, alpha_fn):
    rows = []
    for y in range(n):
        row = bytearray()
        for x in range(n):
            hit = 0
            for sy in range(SS):
                for sx in range(SS):
                    px = x + (sx + 0.5) / SS
                    py = y + (sy + 0.5) / SS
                    d = ((n - px) ** 2 + (n - py) ** 2) ** 0.5   # Abstand zum Kreismittelpunkt unten rechts
                    if alpha_fn(d, n):
                        hit += 1
            a = round(255 * hit / (SS * SS))
            row += bytes((255, 255, 255, a))   # B, G, R, A
        rows.append(bytes(row))
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, n, n, 32, 0x28)
    with open(name, "wb") as f:
        f.write(header)
        for r in rows:
            f.write(r)

for r in range(3, 9):
    n = r * PER
    write("media/corner%d.tga" % r, n, lambda d, n: d > n)
    write("media/ring%d.tga" % r, n, lambda d, n: n - PER <= d <= n)
    print(r, n)
