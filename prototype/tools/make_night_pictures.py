"""Draws the 50 night-themed stage pictures (stages 51-100) and appends them to data/pictures.json.
Run once: python3 tools/make_night_pictures.py   (refuses to run if pictures.json already has 100).
Uses the Canvas helpers from make_pictures.py. The five biggest pictures become the bosses at
stages 60, 70, 80, 90 and 100; the others are ordered by size so difficulty rises."""
import json, math, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from make_pictures import Canvas

PATH = os.path.join(os.path.dirname(__file__), "..", "data", "pictures.json")


def star_poly(c, cx, cy, R, r, col, n=5):
    pts = []
    for i in range(n * 2):
        a = -math.pi / 2 + i * math.pi / n
        rr = R if i % 2 == 0 else r
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    c.poly(pts, col)


def p_star():
    c = Canvas(11, 11); star_poly(c, 5, 5.4, 5.2, 2.3, "Y"); c.px(5, 5, "W"); c.px(4, 4, "O"); return c


def p_crescent():
    c = Canvas(11, 12); c.ellipse(5, 6, 4.8, 5.4, "W")
    for y in range(12):
        for x in range(11):
            if math.hypot(x - 7.6, y - 5) <= 4.2: c.g[y][x] = "."
    c.px(8, 2, "Y"); c.px(9, 8, "Y"); c.px(8, 10, "Y"); c.px(2, 4, "P"); return c


def p_candle():
    c = Canvas(9, 13); c.rect(3, 5, 5, 11, "W"); c.rect(3, 5, 5, 6, "S"); c.rect(1, 12, 7, 12, "N")
    c.px(4, 4, "K"); c.ellipse(4, 2.2, 1.4, 2.0, "Y"); c.px(4, 2, "O"); c.px(3, 8, "S"); return c


def p_firefly():
    c = Canvas(12, 10); c.ellipse(6, 5, 3.4, 2.2, "K"); c.ellipse(8.6, 5, 2.2, 1.8, "Y"); c.px(9, 5, "W")
    c.ellipse(4.2, 1.8, 2.4, 1.3, "W"); c.ellipse(7, 1.6, 2.0, 1.2, "W"); c.px(3, 4, "R"); c.px(2, 5, "K")
    c.line(5, 8, 4, 9, "K"); c.line(7, 8, 8, 9, "K"); c.px(1, 3, "K"); return c


def p_lantern():
    c = Canvas(9, 14); c.rect(3, 0, 5, 1, "K"); c.rect(2, 2, 6, 2, "K"); c.rect(1, 3, 7, 11, "K")
    c.rect(2, 4, 6, 10, "Y"); c.rect(3, 6, 5, 9, "O"); c.px(4, 7, "W"); c.rect(1, 12, 7, 13, "K"); c.rect(4, 4, 4, 10, "K"); return c


def p_owl():
    c = Canvas(11, 12); c.ellipse(5, 6.5, 4.6, 5.0, "N"); c.poly([(1, 3), (3, 0), (4, 3)], "N"); c.poly([(9, 3), (7, 0), (6, 3)], "N")
    c.ellipse(5, 8.2, 2.6, 2.8, "W"); c.ellipse(3.2, 4.6, 1.9, 1.9, "Y"); c.ellipse(6.8, 4.6, 1.9, 1.9, "Y")
    c.px(3, 5, "K"); c.px(7, 5, "K"); c.poly([(4.4, 6), (5.6, 6), (5, 7.4)], "O"); c.rect(3, 11, 4, 11, "O"); c.rect(6, 11, 7, 11, "O"); return c


def p_bat():
    c = Canvas(14, 9); c.poly([(0, 1), (3, 3), (5, 1), (6, 4), (7, 4), (8, 1), (10, 3), (13, 1), (12, 5), (9, 7), (7, 6), (6, 6), (4, 7), (1, 5)], "P")
    c.ellipse(6.5, 4.4, 1.9, 2.4, "K"); c.poly([(5, 2), (5.4, 0), (6, 2)], "K"); c.poly([(7, 2), (7.6, 0), (8, 2)], "K"); c.px(6, 4, "R"); c.px(7, 4, "R"); return c


def p_blackcat():
    c = Canvas(12, 13); c.ellipse(5, 8.5, 3.8, 4.2, "K"); c.ellipse(5, 3.8, 3.2, 2.8, "K")
    c.poly([(2, 3), (2.4, 0), (4.4, 2)], "K"); c.poly([(8, 3), (7.6, 0), (5.6, 2)], "K")
    c.px(3, 4, "Y"); c.px(7, 4, "Y"); c.px(5, 5, "S"); c.line(8, 11, 11, 7, "K", 2); c.line(11, 7, 11, 5, "K", 1); c.rect(3, 12, 4, 12, "K"); c.rect(6, 12, 7, 12, "K"); return c


def p_toadstool():
    c = Canvas(12, 11); c.ellipse(5.5, 4, 5.4, 3.8, "P"); c.rect(0, 4, 11, 5, "P"); c.rect(4, 6, 7, 10, "W"); c.rect(3, 10, 8, 10, "W")
    for p in [(3, 2), (6, 1), (8, 3), (5, 4)]: c.ellipse(p[0], p[1], 1.1, 1.0, "W")
    return c


def p_pumpkin():
    c = Canvas(12, 11); c.ellipse(3.6, 6.4, 3.4, 4.0, "O"); c.ellipse(8.4, 6.4, 3.4, 4.0, "O"); c.ellipse(6, 6.4, 3.0, 4.2, "O")
    c.rect(5, 0, 6, 2, "G"); c.poly([(2.5, 5), (4.5, 5), (3.5, 3.4)], "K"); c.poly([(7.5, 5), (9.5, 5), (8.5, 3.4)], "K")
    c.rect(3, 8, 8, 8, "K"); c.px(4, 9, "K"); c.px(6, 9, "K"); c.px(7, 9, "K"); return c


def p_moth():
    c = Canvas(13, 10); c.poly([(6, 4), (0, 0), (1, 6), (6, 6)], "S"); c.poly([(6, 4), (12, 0), (11, 6), (6, 6)], "S")
    c.poly([(6, 6), (1, 9), (3, 6)], "P"); c.poly([(6, 6), (11, 9), (9, 6)], "P"); c.ellipse(6, 5, 1.0, 3.0, "N")
    c.px(3, 2, "W"); c.px(9, 2, "W"); c.px(5, 1, "N"); c.px(7, 1, "N"); return c


def p_wolf():
    c = Canvas(13, 12); c.poly([(2, 0), (5, 3), (8, 3), (11, 0), (12, 6), (9, 11), (6, 12), (3, 11), (0, 6)], "B")
    c.poly([(3, 6), (6, 5), (9, 6), (8, 10), (6, 11), (4, 10)], "W"); c.px(4, 5, "Y"); c.px(8, 5, "Y"); c.rect(5, 9, 7, 10, "K"); c.px(2, 2, "K"); c.px(10, 2, "K"); return c


def p_fox():
    c = Canvas(13, 11); c.poly([(0, 0), (4, 3), (8, 3), (12, 0), (11, 6), (6, 11), (1, 6)], "O")
    c.poly([(2, 6), (6, 5), (10, 6), (6, 11)], "W"); c.px(4, 4, "K"); c.px(8, 4, "K"); c.px(6, 9, "K"); c.px(6, 10, "K"); c.px(1, 1, "K"); c.px(11, 1, "K"); return c


def p_hedgehog():
    c = Canvas(13, 9); c.ellipse(6, 5, 6, 3.8, "K")
    for x in range(1, 11, 2): c.line(x, 4, x - 1, 0, "N", 1)
    c.poly([(9, 3), (13, 5), (10, 7)], "S"); c.px(11, 5, "K"); c.px(10, 4, "K"); c.rect(3, 8, 4, 8, "S"); c.rect(7, 8, 8, 8, "S"); return c


def p_spider():
    c = Canvas(13, 11); c.ellipse(6, 7, 3.0, 3.0, "K"); c.ellipse(6, 3.2, 2.0, 1.8, "K")
    for dy, dx in [(2, 4), (4, 5), (6, 5), (8, 4)]:
        c.line(4, dy + 2, 4 - dx + 2, dy, "K"); c.line(8, dy + 2, 8 + dx - 2, dy, "K")
    c.px(5, 3, "R"); c.px(7, 3, "R"); c.px(6, 6, "R"); return c


def p_cobweb():
    c = Canvas(13, 13)
    for a in range(8):
        ang = a * math.pi / 4; c.line(6, 6, 6 + math.cos(ang) * 6, 6 + math.sin(ang) * 6, "W")
    for r in (2, 4, 6):
        pts = [(6 + math.cos(a * math.pi / 4) * r, 6 + math.sin(a * math.pi / 4) * r) for a in range(8)]
        for i in range(8): c.line(pts[i][0], pts[i][1], pts[(i + 1) % 8][0], pts[(i + 1) % 8][1], "W")
    c.px(6, 6, "S"); return c


def p_cauldron():
    c = Canvas(13, 11); c.ellipse(6, 7, 5.6, 3.6, "K"); c.rect(1, 3, 11, 6, "K"); c.ellipse(6, 3, 5.4, 1.4, "G")
    for p in [(3, 1), (6, 0), (9, 1)]: c.ellipse(p[0], p[1], 1.2, 1.0, "G")
    c.rect(2, 10, 3, 10, "N"); c.rect(9, 10, 10, 10, "N"); c.px(4, 5, "W"); return c


def p_potion():
    c = Canvas(10, 13); c.rect(4, 0, 5, 1, "N"); c.rect(3, 2, 6, 4, "W"); c.poly([(3, 4), (6, 4), (9, 8), (9, 12), (0, 12), (0, 8)], "W")
    c.poly([(1, 8), (8, 8), (8, 11), (1, 11)], "P"); c.px(3, 9, "S"); c.px(6, 10, "S"); return c


def p_tombstone():
    c = Canvas(11, 13); c.rect(1, 3, 9, 11, "K"); c.ellipse(5, 3.4, 4.4, 3.4, "K"); c.rect(0, 12, 10, 12, "G")
    c.rect(4, 3, 5, 8, "W"); c.rect(2, 5, 7, 6, "W"); c.px(1, 11, "G"); c.px(9, 11, "G"); return c


def p_raven():
    c = Canvas(13, 11); c.ellipse(5.5, 5.4, 4.2, 3.4, "K"); c.ellipse(9.8, 3.4, 2.4, 2.2, "K"); c.poly([(11.8, 3), (13, 3.6), (11.8, 4.4)], "Y")
    c.px(10, 3, "W"); c.poly([(1, 4), (-1, 8), (3, 7)], "K"); c.line(5, 9, 5, 10, "O"); c.line(7, 9, 7, 10, "O"); c.rect(3, 6, 6, 7, "P"); return c


def p_bonekey():
    c = Canvas(13, 8); c.ring(3, 3.5, 1.2, 3.2, "W"); c.rect(6, 3, 12, 4, "W"); c.rect(9, 5, 9, 6, "W"); c.rect(11, 5, 11, 7, "W"); c.px(2, 3, "K"); return c


def p_coffin():
    c = Canvas(9, 14); c.poly([(3, 0), (6, 0), (8, 4), (6, 13), (3, 13), (1, 4)], "N")
    c.rect(4, 2, 4, 9, "Y"); c.rect(3, 4, 5, 5, "Y"); c.line(2, 4, 3, 12, "K"); c.line(7, 4, 6, 12, "K"); return c


def p_angler():
    c = Canvas(14, 10); c.ellipse(7, 6, 5.8, 3.6, "B"); c.poly([(12, 5), (14, 2), (14, 9)], "B")
    c.line(6, 3, 4, 0, "K"); c.line(4, 0, 1, 0, "K"); c.ellipse(0.8, 0.8, 1.2, 1.2, "Y"); c.px(0, 0, "W")
    c.px(5, 5, "W"); c.px(5, 4, "K"); c.rect(2, 7, 3, 8, "W"); c.rect(4, 8, 5, 8, "W"); c.rect(6, 8, 7, 8, "W"); return c


def p_squid():
    c = Canvas(11, 13); c.poly([(5, 0), (9, 4), (8, 8), (2, 8), (1, 4)], "P"); c.poly([(1, 4), (-1, 5), (2, 6)], "P"); c.poly([(9, 4), (11, 5), (8, 6)], "P")
    c.px(3, 5, "W"); c.px(7, 5, "W")
    for x in (2, 4, 6, 8): c.line(x, 8, x + (1 if x % 4 == 0 else -1), 12, "S")
    return c


def p_narwhal():
    c = Canvas(14, 10); c.ellipse(7, 6, 5.6, 3.2, "B"); c.poly([(11, 5), (14, 3), (13, 9)], "B"); c.line(2, 5, -1, 1, "Y", 1)
    c.rect(4, 7, 9, 8, "W"); c.px(3, 5, "K"); c.px(6, 3, "W"); return c


def p_sharkfin():
    c = Canvas(13, 11); c.poly([(2, 0), (4, 0), (7, 6), (8, 9), (0, 9)], "B"); c.poly([(2, 0), (4, 0), (6, 3), (4, 3)], "W")
    for y, k in ((10, "W"), (9, "B")): c.rect(0, y, 12, y, k)
    c.rect(8, 8, 12, 9, "B"); return c


def p_hook():
    c = Canvas(9, 14); c.rect(3, 0, 5, 3, "N"); c.rect(2, 3, 6, 4, "K"); c.line(4, 5, 4, 10, "K", 2)
    c.ring(4.5, 10, 2, 3.5, "K")
    for y in range(8, 14):
        for x in range(0, 3): c.g[y][x] = "." if (x == 0 and y > 8) else c.g[y][x]
    c.poly([(0, 9), (2, 7), (2, 9)], "K"); return c


def p_hourglass():
    c = Canvas(9, 14); c.rect(0, 0, 8, 1, "N"); c.rect(0, 12, 8, 13, "N"); c.poly([(1, 2), (7, 2), (5, 6), (7, 11), (1, 11), (3, 6)], "W")
    c.poly([(2, 3), (6, 3), (4, 5)], "Y"); c.poly([(2, 10), (6, 10), (4, 8)], "Y"); c.line(0, 2, 0, 11, "N"); c.line(8, 2, 8, 11, "N"); return c


def p_sextant():
    c = Canvas(13, 11); c.poly([(1, 10), (12, 10), (6, 0)], "Y"); c.poly([(3, 9), (10, 9), (6, 3)], "K"); c.line(6, 9, 3, 3, "Y"); c.px(6, 8, "W"); c.rect(0, 10, 12, 10, "N"); return c


def p_dagger():
    c = Canvas(7, 14); c.poly([(2, 0), (4, 0), (5, 8), (1, 8)], "W"); c.rect(0, 8, 6, 9, "K")
    c.rect(2, 10, 4, 12, "N"); c.px(3, 8, "R"); c.rect(2, 13, 4, 13, "Y"); return c


def p_rum():
    c = Canvas(8, 14); c.rect(2, 0, 4, 1, "N"); c.rect(2, 2, 4, 4, "G"); c.poly([(2, 4), (5, 4), (7, 7), (7, 13), (0, 13), (0, 7)], "G")
    c.rect(1, 8, 6, 11, "W"); c.px(3, 9, "R"); c.px(4, 10, "R"); c.px(1, 6, "W"); return c


def p_pegleg():
    c = Canvas(9, 14); c.rect(2, 0, 6, 5, "R"); c.rect(1, 5, 7, 6, "K"); c.rect(3, 7, 5, 12, "N"); c.rect(2, 13, 6, 13, "K"); c.rect(3, 1, 4, 3, "Y"); return c


def p_lighthouse_n():
    c = Canvas(13, 14); c.poly([(4, 13), (9, 13), (8, 4), (5, 4)], "W"); c.rect(5, 6, 8, 7, "R"); c.rect(4, 10, 9, 11, "R")
    c.rect(4, 2, 9, 3, "Y"); c.rect(3, 1, 10, 1, "K"); c.px(6, 0, "K"); c.px(7, 0, "K")
    c.poly([(10, 2), (13, 0), (13, 4)], "Y"); c.poly([(3, 2), (0, 0), (0, 4)], "Y"); c.rect(3, 13, 10, 13, "K"); return c


def p_mermaid():
    c = Canvas(11, 14); c.ellipse(4, 4, 2.2, 2.2, "S"); c.rect(2, 1, 6, 2, "O"); c.rect(1, 3, 2, 8, "O"); c.rect(3, 6, 5, 8, "S")
    c.poly([(2, 8), (7, 8), (8, 12), (10, 13), (7, 13), (4, 13), (1, 13), (3, 12)], "G"); c.px(3, 4, "K"); c.px(5, 4, "K"); return c


def p_serpent():
    c = Canvas(14, 12)
    for i in range(14):
        c.rect(i, 6 + 3 * math.sin(i * 0.9) - 1, i, 6 + 3 * math.sin(i * 0.9) + 1, "G")
    c.ellipse(12.4, 3.4, 1.8, 1.6, "G"); c.px(12, 3, "Y"); c.px(13, 4, "R"); c.line(0, 10, 13, 10, "B")
    for x in range(0, 14, 3): c.px(x, 9, "W")
    return c


def p_rowboat():
    c = Canvas(14, 9); c.poly([(0, 3), (13, 3), (11, 7), (2, 7)], "N"); c.rect(1, 3, 12, 3, "Y"); c.line(6, 3, 12, 0, "N"); c.rect(0, 8, 13, 8, "B")
    for x in (2, 6, 10): c.px(x, 7, "W")
    return c


def p_harpoon():
    c = Canvas(14, 7); c.line(0, 3, 10, 3, "N", 1); c.poly([(10, 0), (13, 3), (10, 6), (11, 3)], "W"); c.px(1, 2, "R"); c.px(2, 4, "R"); return c


def p_skulllantern():
    c = Canvas(11, 12); c.ellipse(5, 4.4, 4.4, 4.0, "W"); c.rect(2, 7, 8, 10, "W"); c.ellipse(3.2, 4.4, 1.5, 1.5, "Y"); c.ellipse(6.8, 4.4, 1.5, 1.5, "Y")
    c.px(5, 6, "K"); c.rect(3, 9, 7, 9, "K"); c.px(4, 10, "K"); c.px(6, 10, "K"); c.px(3, 4, "O"); c.px(7, 4, "O"); c.rect(4, 0, 6, 0, "K"); return c


def p_eyepatch():
    c = Canvas(13, 9); c.ellipse(6, 5, 3.6, 3.2, "K"); c.line(0, 2, 5, 3, "K", 1); c.line(12, 2, 7, 3, "K", 1); c.px(5, 4, "W"); c.px(6, 4, "W"); return c


def p_moonship():
    c = Canvas(13, 13); c.ellipse(6, 6, 6, 6, "W"); c.ellipse(6, 6, 5, 5, "W")
    c.poly([(1, 9), (11, 9), (9, 12), (3, 12)], "K"); c.line(6, 9, 6, 3, "K"); c.poly([(7, 3), (10, 8), (7, 8)], "K"); c.poly([(5, 4), (2, 8), (5, 8)], "K"); c.px(3, 2, "Y"); c.px(10, 3, "P"); return c


def p_galleon():
    c = Canvas(14, 14); c.rect(7, 0, 7, 9, "N"); c.poly([(6, 1), (6, 8), (1, 8)], "W"); c.poly([(8, 2), (8, 8), (13, 8)], "W"); c.poly([(7, 0), (10, 1), (7, 2)], "R")
    c.poly([(0, 9), (13, 9), (11, 12), (2, 12)], "K"); c.rect(0, 13, 13, 13, "B"); c.rect(3, 10, 4, 10, "Y"); c.rect(8, 10, 9, 10, "Y"); return c


def p_anchorglow():
    c = Canvas(11, 13); c.ring(5, 1.6, 0.8, 1.9, "Y"); c.rect(5, 3, 5, 11, "K"); c.rect(3, 4, 7, 4, "K")
    c.line(0, 8, 5, 12, "K", 1); c.line(10, 8, 5, 12, "K", 1); c.px(0, 7, "K"); c.px(1, 7, "K"); c.px(10, 7, "K"); c.px(9, 7, "K")
    c.line(1, 8, 4, 11, "W"); c.px(5, 5, "Y"); c.px(5, 8, "Y"); return c


def p_openchest():
    c = Canvas(13, 11); c.poly([(1, 4), (3, 0), (10, 0), (12, 4)], "N"); c.rect(0, 5, 12, 10, "N"); c.rect(0, 5, 12, 5, "K"); c.rect(0, 10, 12, 10, "K")
    c.ellipse(6, 4, 4.4, 1.6, "Y"); c.rect(5, 6, 7, 8, "Y"); c.px(3, 3, "W"); c.px(9, 3, "W"); c.px(6, 2, "O"); return c


def p_bonecrown():
    c = Canvas(13, 10)
    for x in (1, 4, 7, 10): c.poly([(x, 0), (x + 2, 0), (x + 1, 5)], "W")
    c.rect(0, 5, 12, 8, "W"); c.rect(0, 9, 12, 9, "K"); c.px(3, 6, "K"); c.px(6, 6, "R"); c.px(9, 6, "K"); return c


def p_spyglass():
    c = Canvas(14, 8); c.rect(0, 3, 3, 5, "Y"); c.rect(4, 2, 8, 5, "N"); c.rect(9, 1, 13, 6, "N"); c.rect(13, 1, 13, 6, "B"); c.rect(8, 2, 8, 5, "Y"); c.rect(3, 3, 3, 5, "K"); return c


def p_firefly_jar():
    c = Canvas(10, 13); c.rect(2, 0, 7, 2, "N"); c.rect(1, 3, 8, 11, "W"); c.rect(2, 4, 7, 10, "K")
    for p in [(3, 5), (6, 7), (4, 8), (7, 5)]: c.px(p[0], p[1], "Y")
    c.px(3, 8, "O"); c.rect(1, 12, 8, 12, "N"); return c


def p_campfire():
    c = Canvas(13, 12); c.poly([(6, 0), (10, 5), (9, 10), (3, 10), (2, 5)], "R"); c.poly([(6, 3), (8, 6), (7, 10), (5, 10), (4, 6)], "O"); c.poly([(6, 6), (7, 8), (6, 10), (5, 8)], "Y")
    c.line(0, 11, 12, 9, "N", 1); c.line(0, 9, 12, 11, "N", 1); return c


def p_hut():
    c = Canvas(14, 12); c.poly([(0, 5), (7, 0), (13, 5)], "N"); c.rect(1, 5, 12, 11, "N"); c.rect(1, 5, 12, 5, "K")
    c.rect(2, 7, 5, 9, "Y"); c.px(3, 8, "O"); c.rect(8, 7, 11, 11, "K"); c.rect(0, 11, 13, 11, "G"); c.px(10, 9, "Y"); return c


def p_ghostship():
    c = Canvas(14, 14); c.rect(7, 0, 7, 9, "W"); c.poly([(6, 1), (6, 8), (1, 8)], "W"); c.poly([(8, 2), (8, 8), (13, 8)], "W")
    c.poly([(0, 9), (13, 9), (11, 12), (2, 12)], "P"); c.rect(0, 13, 13, 13, "B")
    for p in [(3, 4), (4, 5), (10, 5), (9, 4)]: c.px(*p, "K")
    c.px(5, 10, "Y"); c.px(8, 10, "Y"); c.poly([(7, 0), (10, 1), (7, 2)], "P"); return c


def p_treasuremoon():
    c = Canvas(14, 14); c.ellipse(7, 5, 6, 5, "W"); c.ellipse(7, 5, 5, 4, "W")
    c.ellipse(5, 3, 1.4, 1.2, "B"); c.ellipse(9, 6, 1.6, 1.3, "B"); c.ellipse(4, 7, 1.0, 0.9, "B")
    c.ellipse(7, 11, 6.4, 3.0, "Y"); c.rect(2, 9, 11, 10, "Y"); c.px(4, 10, "O"); c.px(8, 9, "O"); c.px(10, 11, "O"); c.px(6, 12, "R"); c.px(3, 12, "R"); return c


def p_dragon_moon():
    c = Canvas(14, 13); c.ellipse(7, 6, 5.6, 5.0, "W")
    c.poly([(2, 9), (6, 6), (9, 7), (12, 4), (13, 8), (10, 11), (4, 12)], "P"); c.px(11, 5, "Y"); c.px(12, 6, "R"); c.rect(2, 11, 4, 12, "P"); c.px(9, 3, "K"); return c


def p_island_night():
    c = Canvas(14, 12); c.ellipse(7, 10, 7, 2.6, "Y"); c.rect(0, 11, 13, 11, "B"); c.rect(6, 4, 7, 9, "N")
    c.poly([(6, 4), (0, 3), (2, 5)], "G"); c.poly([(7, 4), (13, 3), (11, 5)], "G"); c.poly([(6, 4), (3, 0), (6, 2)], "G"); c.poly([(7, 4), (10, 0), (7, 2)], "G"); c.ellipse(11, 1.4, 1.6, 1.6, "W"); return c


def p_kraken_eye():
    c = Canvas(14, 14); c.ellipse(7, 6, 6.4, 5.4, "P"); c.ellipse(7, 6, 3.6, 3.4, "Y"); c.rect(5, 4, 9, 8, "Y")
    c.ellipse(7, 6, 1.4, 2.8, "K")
    for x in (1, 4, 7, 10, 12): c.line(x, 10, x + (1 if x % 2 else -1), 13, "S")
    return c


PICS = [
    ("Night Star", p_star), ("Crescent", p_crescent), ("Candle", p_candle), ("Firefly", p_firefly), ("Lantern", p_lantern),
    ("Owl", p_owl), ("Bat", p_bat), ("Black Cat", p_blackcat), ("Toadstool", p_toadstool), ("Pumpkin", p_pumpkin),
    ("Moth", p_moth), ("Wolf", p_wolf), ("Fox", p_fox), ("Hedgehog", p_hedgehog), ("Spider", p_spider),
    ("Cobweb", p_cobweb), ("Cauldron", p_cauldron), ("Potion", p_potion), ("Tombstone", p_tombstone), ("Raven", p_raven),
    ("Bone Key", p_bonekey), ("Coffin", p_coffin), ("Anglerfish", p_angler), ("Squid", p_squid), ("Narwhal", p_narwhal),
    ("Shark Fin", p_sharkfin), ("Hook", p_hook), ("Hourglass", p_hourglass), ("Sextant", p_sextant), ("Dagger", p_dagger),
    ("Rum", p_rum), ("Peg Leg", p_pegleg), ("Night Light", p_lighthouse_n), ("Mermaid", p_mermaid), ("Sea Serpent", p_serpent),
    ("Rowboat", p_rowboat), ("Harpoon", p_harpoon), ("Skull Lantern", p_skulllantern), ("Eye Patch", p_eyepatch), ("Moon Ship", p_moonship),
    ("Galleon", p_galleon), ("Ghost Anchor", p_anchorglow), ("Open Chest", p_openchest), ("Bone Crown", p_bonecrown), ("Spyglass", p_spyglass),
    ("Firefly Jar", p_firefly_jar), ("Campfire", p_campfire), ("Hut", p_hut), ("Ghost Ship", p_ghostship), ("Treasure Moon", p_treasuremoon),
]
BOSS_NAMES = ["Kraken Eye", "Moon Dragon", "Night Isle", "Ghost Ship", "Treasure Moon"]
EXTRA = [("Kraken Eye", p_kraken_eye), ("Moon Dragon", p_dragon_moon), ("Night Isle", p_island_night)]


def fit5(rows):
    """Merges the rarest colors into the most common one until at most 5 colors remain."""
    while True:
        counts = {}
        for r in rows:
            for ch in r:
                if ch != ".": counts[ch] = counts.get(ch, 0) + 1
        if len(counts) <= 5: return rows
        rare = min(counts, key=counts.get); common = max(counts, key=counts.get)
        rows = [r.replace(rare, common) for r in rows]


def info(rows):
    cells = sum(1 for r in rows for ch in r if ch != ".")
    return cells, len(set("".join(rows)) - {"."})


if __name__ == "__main__":
    data = json.load(open(PATH))
    if len(data["pictures"]) != 50:
        sys.exit("pictures.json has %d pictures; expected 50" % len(data["pictures"]))
    skip = {"Ghost Ship", "Treasure Moon", "Hook", "Harpoon", "Eye Patch"}
    bosses = [("Kraken Eye", p_kraken_eye), ("Moon Dragon", p_dragon_moon), ("Night Isle", p_island_night), ("Ghost Ship", p_ghostship), ("Treasure Moon", p_treasuremoon)]
    normal = []
    for n, f in PICS:
        if n in skip:
            continue
        rows = fit5(f().rows())
        cells, cols = info(rows)
        assert set("".join(rows)) - {"."} <= set(data["palette"]), n
        normal.append((cells + 6 * cols, n, rows))
    normal.sort(key=lambda b: b[0])
    assert len(normal) == 45, len(normal)
    out = []
    ni = 0
    for slot in range(50):
        if slot % 10 == 9:
            n, f = bosses[slot // 10]
            out.append((n, fit5(f().rows())))
        else:
            _, n, rows = normal[ni]
            ni += 1
            out.append((n, rows))
    for n, rows in out:
        data["pictures"].append({"name": n, "tier": 0, "rows": rows})
    json.dump(data, open(PATH, "w"), indent=1)
    for i, (n, rows) in enumerate(out):
        print(51 + i, n, info(rows))
