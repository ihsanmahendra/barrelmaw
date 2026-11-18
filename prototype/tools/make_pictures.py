"""Draws the 30 extra stage pictures (stages 21-50) with small shape helpers and appends them to
data/pictures.json. Run once: python3 tools/make_pictures.py   (it refuses to run twice).
Pictures are ordered by size so difficulty rises with the stage number."""
import json, math, os, sys

HERE = os.path.dirname(__file__)
PATH = os.path.join(HERE, "..", "data", "pictures.json")


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.g = [["."] * w for _ in range(h)]

    def px(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            self.g[y][x] = c

    def rect(self, x0, y0, x1, y1, c):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                self.px(x, y, c)

    def ellipse(self, cx, cy, rx, ry, c):
        for y in range(self.h):
            for x in range(self.w):
                if ((x - cx) / max(rx, 0.01)) ** 2 + ((y - cy) / max(ry, 0.01)) ** 2 <= 1.0:
                    self.px(x, y, c)

    def ring(self, cx, cy, r0, r1, c):
        for y in range(self.h):
            for x in range(self.w):
                d = math.hypot(x - cx, y - cy)
                if r0 <= d <= r1:
                    self.px(x, y, c)

    def line(self, x0, y0, x1, y1, c, t=1):
        n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
        for i in range(n + 1):
            x = x0 + (x1 - x0) * i / n
            y = y0 + (y1 - y0) * i / n
            for dx in range(t):
                for dy in range(t):
                    self.px(x + dx, y + dy, c)

    def poly(self, pts, c):
        for y in range(self.h):
            for x in range(self.w):
                inside = False
                j = len(pts) - 1
                for i in range(len(pts)):
                    xi, yi = pts[i]; xj, yj = pts[j]
                    if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-9) + xi:
                        inside = not inside
                    j = i
                if inside:
                    self.px(x, y, c)

    def mirror(self):
        for y in range(self.h):
            for x in range(self.w // 2):
                if self.g[y][x] != ".":
                    self.g[y][self.w - 1 - x] = self.g[y][x]

    def rows(self):
        return ["".join(r) for r in self.g]


def sun():
    c = Canvas(11, 11)
    for a in range(8):
        ang = a * math.pi / 4
        c.line(5 + math.cos(ang) * 3.2, 5 + math.sin(ang) * 3.2, 5 + math.cos(ang) * 5, 5 + math.sin(ang) * 5, "O")
    c.ellipse(5, 5, 3.3, 3.3, "Y")
    c.px(4, 4, "K"); c.px(6, 4, "K"); c.px(4, 6, "O"); c.px(5, 7, "O"); c.px(6, 6, "O")
    return c


def moon():
    c = Canvas(11, 12)
    c.ellipse(5, 6, 4.8, 5.4, "W")
    for y in range(12):
        for x in range(11):
            if math.hypot(x - 7.8, y - 5) <= 4.4:
                c.g[y][x] = "."
    for p in [(8, 2), (9, 7), (8, 10)]:
        c.px(*p, "Y")
    return c


def apple():
    c = Canvas(11, 12)
    c.ellipse(3.6, 6.8, 3.7, 4.4, "R"); c.ellipse(7.4, 6.8, 3.7, 4.4, "R")
    c.rect(5, 1, 5, 3, "N"); c.poly([(5, 2), (9, 0), (9, 3)], "G")
    c.px(2, 5, "W"); c.px(2, 6, "W"); c.px(3, 4, "W")
    return c


def lighthouse():
    c = Canvas(9, 14)
    c.poly([(2, 13), (6, 13), (5, 4), (3, 4)], "W")
    for y in (6, 9, 12):
        c.rect(3 if y < 8 else 2, y, 5 if y < 8 else 6, y + 1, "R")
    c.rect(3, 2, 5, 3, "Y"); c.rect(2, 1, 6, 1, "K"); c.px(4, 0, "K")
    c.rect(1, 13, 7, 13, "K")
    return c


def key():
    c = Canvas(13, 8)
    c.ring(3, 3.5, 1.4, 3.4, "Y")
    c.rect(6, 3, 12, 4, "Y"); c.rect(10, 5, 10, 6, "Y"); c.rect(12, 5, 12, 7, "Y"); c.rect(8, 5, 8, 6, "Y")
    c.rect(6, 4, 12, 4, "O")
    return c


def bottle():
    c = Canvas(7, 13)
    c.rect(2, 0, 4, 1, "N"); c.rect(2, 2, 4, 4, "G")
    c.poly([(2, 4), (4, 4), (6, 7), (6, 12), (0, 12), (0, 7)], "G")
    c.rect(1, 8, 5, 10, "W"); c.px(3, 9, "Y")
    c.px(1, 6, "W")
    return c


def compass():
    c = Canvas(12, 12)
    c.ellipse(5.5, 5.5, 5.5, 5.5, "K"); c.ellipse(5.5, 5.5, 4.4, 4.4, "W")
    c.poly([(5, 1), (7, 5), (5, 5)], "R"); c.poly([(5, 10), (3, 6), (6, 6)], "K")
    c.px(5, 5, "Y"); c.px(6, 5, "Y")
    for p in [(5, 0), (5, 11), (0, 5), (11, 5)]:
        c.px(*p, "Y")
    return c


def telescope():
    c = Canvas(14, 8)
    c.rect(1, 3, 4, 5, "N"); c.rect(5, 2, 9, 5, "N"); c.rect(10, 1, 13, 6, "N")
    for x in (4, 9):
        c.rect(x, 2 if x == 9 else 3, x, 5, "Y")
    c.rect(13, 1, 13, 6, "B"); c.rect(0, 3, 0, 5, "K")
    c.rect(2, 6, 3, 7, "N")
    return c


def pirate_hat():
    c = Canvas(13, 9)
    c.poly([(0, 6), (3, 1), (9, 1), (12, 6), (9, 8), (3, 8)], "K")
    c.rect(1, 6, 11, 6, "Y")
    c.ellipse(6, 3.4, 1.6, 1.4, "W"); c.px(5, 3, "K"); c.px(7, 3, "K"); c.px(6, 5, "W")
    c.px(4, 2, "W"); c.px(8, 2, "W")
    return c


def boot():
    c = Canvas(9, 12)
    c.rect(1, 0, 5, 7, "N"); c.poly([(1, 7), (5, 7), (8, 8), (8, 10), (1, 10)], "N")
    c.rect(0, 10, 8, 11, "K"); c.rect(1, 1, 5, 1, "Y"); c.px(3, 4, "Y"); c.px(3, 6, "Y")
    c.rect(1, 2, 1, 5, "O")
    return c


def bomb():
    c = Canvas(11, 12)
    c.ellipse(5, 7, 4.6, 4.6, "K"); c.rect(4, 1, 5, 2, "N"); c.px(6, 1, "O"); c.px(7, 0, "Y"); c.px(8, 1, "O")
    c.px(3, 5, "W"); c.px(3, 6, "W"); c.px(4, 4, "W")
    c.rect(4, 2, 6, 3, "K")
    return c


def shell():
    c = Canvas(11, 10)
    c.poly([(0, 7), (5, 0), (10, 7), (8, 9), (2, 9)], "S")
    for x in (3, 5, 7):
        c.line(5, 1, x if x != 5 else 5, 8, "W")
    c.rect(2, 9, 8, 9, "O")
    return c


def whale():
    c = Canvas(14, 9)
    c.ellipse(6.5, 5, 6.4, 3.6, "B"); c.poly([(11, 4), (13, 0), (13, 3)], "B"); c.poly([(11, 5), (13, 8), (13, 6)], "B")
    c.rect(2, 6, 9, 7, "W"); c.px(3, 4, "K"); c.rect(6, 0, 6, 1, "W"); c.px(5, 0, "W"); c.px(7, 0, "W")
    return c


def turtle():
    c = Canvas(12, 9)
    c.ellipse(5.5, 4, 4.6, 3.4, "G"); c.ellipse(5.5, 4, 2.2, 1.6, "Y")
    c.rect(10, 3, 11, 5, "G"); c.px(11, 3, "K")
    c.rect(1, 7, 2, 8, "N"); c.rect(8, 7, 9, 8, "N"); c.px(0, 4, "N")
    c.rect(2, 7, 2, 7, "G"); c.rect(8, 7, 8, 7, "G")
    return c


def palm_island():
    c = Canvas(13, 13)
    c.rect(6, 5, 6, 10, "N"); c.rect(7, 6, 7, 9, "N")
    for pts in ([(6, 4), (1, 3), (2, 5)], [(6, 4), (11, 3), (10, 5)], [(6, 4), (3, 0), (6, 2)], [(6, 4), (9, 0), (6, 2)]):
        c.poly(pts, "G")
    c.ellipse(6, 11, 5.6, 1.6, "Y"); c.rect(0, 12, 12, 12, "B")
    return c


def treasure_map():
    c = Canvas(12, 10)
    c.rect(0, 0, 11, 9, "N"); c.rect(1, 1, 10, 8, "Y")
    c.rect(1, 6, 4, 8, "B"); c.line(3, 5, 8, 2, "N"); c.px(8, 3, "R"); c.px(9, 2, "R"); c.px(7, 2, "R"); c.px(8, 1, "R"); c.px(9, 4, "R")
    return c


def skull_swords():
    c = Canvas(13, 12)
    c.line(1, 11, 11, 3, "N", 1); c.line(11, 11, 1, 3, "N", 1)
    c.ellipse(6, 4.6, 3.8, 3.5, "W"); c.rect(4, 7, 8, 9, "W")
    c.ellipse(4.5, 4.5, 1, 1, "K"); c.ellipse(7.5, 4.5, 1, 1, "K"); c.px(6, 6, "K")
    for x in (5, 7):
        c.px(x, 8, "K")
    return c


def cannon():
    c = Canvas(14, 9)
    c.poly([(1, 2), (11, 1), (13, 3), (11, 6), (1, 5)], "K"); c.rect(11, 2, 13, 5, "K")
    c.ellipse(5, 6.5, 2.2, 2.2, "N"); c.ellipse(5, 6.5, 0.8, 0.8, "Y")
    c.px(0, 1, "O"); c.px(0, 0, "Y"); c.px(1, 0, "R")
    c.px(3, 2, "N"); c.rect(4, 2, 4, 4, "N")
    return c


def coins():
    c = Canvas(12, 9)
    for cx, cy in [(3, 6), (6, 6), (9, 6), (4.5, 3.6), (7.5, 3.6), (6, 1.6)]:
        c.ellipse(cx, cy, 2.2, 1.9, "Y"); c.rect(int(cx) - 1, int(cy), int(cx) + 1, int(cy), "O")
    c.px(3, 5, "W"); c.px(6, 5, "W"); c.px(9, 5, "W")
    return c


def gem():
    c = Canvas(11, 10)
    c.poly([(2, 0), (8, 0), (10, 3), (5, 9), (0, 3)], "B")
    c.poly([(2, 0), (5, 0), (3, 3), (0, 3)], "W"); c.poly([(5, 0), (8, 0), (10, 3), (7, 3)], "P")
    c.poly([(0, 3), (3, 3), (5, 9)], "B"); c.line(7, 3, 5, 8, "P")
    return c


def ship_wheel():
    c = Canvas(13, 13)
    c.ring(6, 6, 4.4, 5.6, "N")
    for a in range(8):
        ang = a * math.pi / 4
        c.line(6 + math.cos(ang) * 1.5, 6 + math.sin(ang) * 1.5, 6 + math.cos(ang) * 6, 6 + math.sin(ang) * 6, "N")
    c.ellipse(6, 6, 1.9, 1.9, "Y"); c.px(6, 6, "K")
    return c


def flag():
    c = Canvas(12, 12)
    c.rect(1, 0, 1, 11, "N"); c.rect(0, 11, 3, 11, "N")
    c.poly([(2, 1), (11, 1), (9, 4), (11, 7), (2, 7)], "R")
    c.ellipse(5.5, 3.6, 1.5, 1.3, "W"); c.px(5, 3, "K"); c.px(6, 3, "K"); c.px(5, 5, "W"); c.px(6, 5, "W")
    return c


def dolphin():
    c = Canvas(14, 10)
    c.ellipse(6, 5, 6, 3, "B"); c.poly([(10, 4), (13, 1), (13, 5)], "B"); c.poly([(1, 5), (-1, 4), (0, 7)], "B")
    c.poly([(5, 2), (7, 0), (8, 2)], "B"); c.poly([(2, 5), (8, 8), (6, 6)], "B")
    c.rect(2, 6, 9, 6, "W"); c.px(2, 4, "K"); c.rect(0, 4, 1, 5, "B")
    return c


def seahorse():
    c = Canvas(9, 13)
    c.ellipse(4, 3, 2.4, 2.4, "O"); c.rect(5, 2, 8, 3, "O"); c.px(3, 2, "K")
    c.rect(2, 5, 5, 8, "Y"); c.rect(3, 9, 5, 10, "O"); c.rect(2, 11, 4, 12, "Y"); c.px(4, 12, "O")
    c.rect(1, 6, 1, 7, "O"); c.rect(6, 5, 6, 6, "O"); c.px(3, 0, "O"); c.px(5, 0, "O")
    return c


def jellyfish():
    c = Canvas(11, 13)
    c.ellipse(5, 4, 4.8, 3.8, "P"); c.rect(0, 4, 10, 5, "P")
    c.px(3, 2, "W"); c.px(2, 3, "W")
    for x in (1, 3, 5, 7, 9):
        c.rect(x, 6, x, 12 - (x % 4), "S")
    c.px(3, 4, "K"); c.px(7, 4, "K")
    return c


def barrel():
    c = Canvas(10, 12)
    c.ellipse(4.5, 5.5, 4.7, 5.6, "N")
    for y in (2, 9):
        c.rect(1, y, 8, y, "K")
    c.rect(4, 0, 5, 11, "N"); c.px(4, 5, "O"); c.px(5, 5, "O")
    c.rect(0, 4, 0, 7, "O"); c.rect(1, 4, 1, 7, "N")
    return c


def mug():
    c = Canvas(11, 11)
    c.rect(1, 2, 7, 10, "Y"); c.rect(1, 0, 7, 2, "W"); c.px(0, 1, "W"); c.px(8, 1, "W")
    c.ring(8.6, 6, 1.2, 2.4, "N"); c.rect(1, 8, 7, 10, "O")
    c.px(2, 5, "W"); c.px(2, 6, "W")
    return c


def sailboat():
    c = Canvas(13, 13)
    c.rect(6, 0, 6, 9, "N"); c.poly([(5, 1), (5, 8), (0, 8)], "W"); c.poly([(7, 2), (7, 8), (11, 8)], "W")
    c.poly([(6, 0), (9, 1), (6, 2)], "R"); c.poly([(1, 9), (11, 9), (9, 11), (3, 11)], "N")
    c.rect(0, 12, 12, 12, "B")
    return c


def kraken():
    c = Canvas(14, 14)
    c.ellipse(6.5, 4.5, 5.6, 4.4, "P")
    for x in (1, 3, 6, 9, 11):
        c.rect(x, 8, x, 12 + (x % 2), "P")
    for x in (0, 2, 5, 8, 10, 12):
        c.px(x, 11, "P"); c.px(x, 13, "P")
    c.ellipse(4.5, 4, 1.5, 1.5, "W"); c.ellipse(8.5, 4, 1.5, 1.5, "W"); c.px(4, 4, "K"); c.px(8, 4, "K")
    for p in [(2, 10), (3, 11), (6, 11), (9, 11), (10, 12)]:
        c.px(*p, "S")
    c.rect(5, 7, 8, 7, "K")
    return c


def hoard():
    c = Canvas(14, 14)
    c.ellipse(6.5, 10, 6.4, 3.2, "Y")
    for x, y in [(2, 8), (5, 7), (8, 7), (11, 8), (4, 10), (9, 10)]:
        c.px(x, y, "O")
    c.rect(2, 2, 11, 7, "N"); c.rect(2, 1, 11, 2, "K"); c.rect(2, 5, 11, 5, "K")
    c.rect(6, 4, 7, 6, "Y"); c.rect(1, 3, 1, 7, "K"); c.rect(12, 3, 12, 7, "K")
    c.px(3, 8, "R"); c.px(10, 8, "R"); c.px(7, 9, "R")
    return c


PICS = [
    ("Sun", sun), ("Moon", moon), ("Apple", apple), ("Lighthouse", lighthouse), ("Key", key),
    ("Bottle", bottle), ("Compass", compass), ("Telescope", telescope), ("Pirate Hat", pirate_hat),
    ("Boot", boot), ("Bomb", bomb), ("Shell", shell), ("Whale", whale), ("Turtle", turtle),
    ("Palm Island", palm_island), ("Treasure Map", treasure_map), ("Crossbones", skull_swords),
    ("Cannon", cannon), ("Coins", coins), ("Gem", gem), ("Ship Wheel", ship_wheel), ("Flag", flag),
    ("Dolphin", dolphin), ("Seahorse", seahorse), ("Jellyfish", jellyfish), ("Barrel", barrel),
    ("Mug", mug), ("Sailboat", sailboat), ("Kraken", kraken), ("Hoard", hoard),
]


def info(rows):
    cells = sum(1 for r in rows for ch in r if ch != ".")
    cols = len(set("".join(rows)) - {"."})
    return cells, cols


if __name__ == "__main__":
    data = json.load(open(PATH))
    if len(data["pictures"]) != 20:
        sys.exit("pictures.json already has %d pictures; nothing to do" % len(data["pictures"]))
    built = []
    for name, fn in PICS:
        rows = fn().rows()
        cells, cols = info(rows)
        assert cols <= 5, (name, cols)
        assert set("".join(rows)) - {"."} <= set(data["palette"]), name
        built.append((cells + 6 * cols, name, rows))
    built.sort(key=lambda b: b[0])
    # Kraken and Hoard are bosses (stages 40 and 50): keep them last.
    names = [b[1] for b in built]
    for boss in ("Kraken", "Hoard"):
        i = names.index(boss)
        built.append(built.pop(i))
        names = [b[1] for b in built]
    for score, name, rows in built:
        data["pictures"].append({"name": name, "tier": 0, "rows": rows})
        print(f"{name:14} {info(rows)}")
    json.dump(data, open(PATH, "w"), indent=1)
