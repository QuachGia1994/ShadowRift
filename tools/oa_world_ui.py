"""Environment, UI and VFX generators for the OPTION A asset set."""
from __future__ import annotations

import math

from PIL import Image, ImageDraw, ImageFilter

from oa_common import (
    INK, CRIMSON, CRIMSON_DEEP, GOLD, GOLD_HI, GOLD_DEEP, SILVER, SILVER_HI,
    CYAN, CYAN_HI, VIOLET, VIOLET_HI, BONE, SS, RNG, ROOT,
    canvas, save, poly, poly_outline, ell, ell_outline, line, glow_layer,
    fill_poly_grad, vgrad, crescent,
)


# ============================================================ ENVIRONMENT ==
def gen_tiles() -> None:
    img = canvas(96, 32)
    d = ImageDraw.Draw(img)
    palettes = [
        ((16, 24, 40, 255), (10, 16, 30, 255)),    # tile 0: distant ruined brick
        ((34, 42, 56, 255), (22, 28, 40, 255)),    # tile 1: mid stone brick
        ((44, 54, 66, 255), (28, 36, 46, 255)),    # tile 2: foreground stone
    ]
    for t, (top, bottom) in enumerate(palettes):
        ox = t * 32
        grad = vgrad((32 * SS, 32 * SS), top, bottom)
        img.paste(grad, (ox * SS, 0))
        for row in range(4):
            y = row * 8
            line(d, ox, y, ox + 32, y, (0, 0, 0, 90), 0.8)
            offset = 8 if row % 2 else 0
            for bx in range(offset, 32, 16):
                line(d, ox + bx, y, ox + bx, y + 8, (0, 0, 0, 70), 0.7)
            line(d, ox, y + 0.8, ox + 32, y + 0.8, (255, 255, 255, 14), 0.5)
        for _ in range(3):
            x0 = ox + RNG.uniform(3, 29)
            y0 = RNG.uniform(2, 14)
            line(d, x0, y0, x0 + RNG.uniform(-4, 4), y0 + RNG.uniform(6, 14), (0, 0, 0, 110), 0.7)
        if t == 2:
            for x in range(0, 32, 2):
                if RNG.random() < 0.75:
                    h = RNG.uniform(1.0, 2.6)
                    line(d, ox + x, 0.4, ox + x, h, (46, 96, 62, 200), 1.4)
            line(d, ox, 0.5, ox + 32, 0.5, (96, 150, 96, 170), 0.9)
            line(d, ox, 1.6, ox + 32, 1.6, (30, 62, 44, 140), 0.8)
    save(img, 96, 32, "assets/environment/rift_zone_tiles.png")


def gen_bg_sky() -> None:
    W, H = 960, 540
    img = vgrad((W * SS, H * SS), (10, 15, 34, 255), (26, 32, 58, 255)).convert("RGBA")
    d = ImageDraw.Draw(img)
    for _ in range(140):
        x = RNG.uniform(0, W)
        y = RNG.uniform(0, 330)
        r = RNG.uniform(0.4, 1.4)
        a = RNG.randint(60, 170)
        ell(d, x, y, r, r, (200, 214, 235, a))
    mcx, mcy = 790.0, 118.0
    glow_layer(img, lambda g: ell(g, mcx, mcy, 66.0, 66.0, (150, 160, 200, 60)), 8.0, 0.8)
    ell(d, mcx, mcy, 46.0, 46.0, (188, 196, 222, 235))
    ell(d, mcx - 12.0, mcy - 10.0, 34.0, 34.0, (208, 214, 236, 255))
    for cxx, cyy, cr in [(-16, 6, 7), (10, -14, 5), (18, 12, 9), (-4, 22, 4)]:
        ell(d, mcx + cxx, mcy + cyy, cr, cr, (168, 176, 206, 220))
    crack = [(mcx - 6.0, mcy - 48.0), (mcx + 8.0, mcy - 20.0), (mcx - 10.0, mcy + 6.0),
             (mcx + 6.0, mcy + 30.0), (mcx - 2.0, mcy + 48.0)]
    glow_layer(img, lambda g: line(g, crack[0][0], crack[0][1], crack[-1][0], crack[-1][1], (140, 80, 230, 180), 5.0), 3.0)
    for i in range(len(crack) - 1):
        line(d, crack[i][0], crack[i][1], crack[i + 1][0], crack[i + 1][1], (90, 50, 160, 235), 3.0)
        line(d, crack[i][0], crack[i][1], crack[i + 1][0], crack[i + 1][1], (150, 230, 245, 160), 1.2)
    glow_layer(img, lambda g: poly(g, [(880, 300), (900, 120), (912, 120), (898, 300)], (120, 70, 200, 70)), 4.0, 0.8)
    save(img, W, H, "assets/environment/bg_sky.png")


def gen_bg_ruins() -> None:
    W, H = 960, 540
    img = canvas(W, H)
    d = ImageDraw.Draw(img)

    def ridge(base_y, amp, freq_k, color, towers):
        pts = [(0.0, H)]
        for x in range(0, W + 1, 8):
            y = base_y + math.sin(x / W * math.tau * freq_k) * amp + math.sin(x / W * math.tau * freq_k * 2.7 + 1.3) * amp * 0.35
            pts.append((x, y))
        pts.append((W, H))
        poly(d, pts, color)
        for tx, tw, th in towers:
            by = base_y + math.sin(tx / W * math.tau * freq_k) * amp
            poly(d, [(tx - tw / 2, by + 6), (tx - tw / 2 + 3, by - th), (tx + tw / 2 - 3, by - th - 4), (tx + tw / 2, by + 6)], color)
            poly(d, [(tx - tw / 2 + 3, by - th), (tx - tw / 2 + 6, by - th - 5), (tx - tw / 2 + 9, by - th),
                     (tx - tw / 2 + 12, by - th - 6), (tx - tw / 2 + 15, by - th)], color)

    ridge(300, 26, 2, (30, 38, 62, 255), [(140, 26, 90), (410, 34, 130), (700, 24, 80), (880, 30, 105)])
    ridge(360, 30, 3, (24, 30, 52, 255), [(260, 30, 110), (560, 26, 88), (820, 36, 140)])
    ridge(430, 22, 5, (18, 23, 42, 255), [(90, 22, 70), (330, 28, 96), (620, 24, 78), (930, 26, 92)])
    for wx, wy in [(326, 372), (616, 386), (86, 392)]:
        ell(d, wx, wy, 1.6, 2.4, (120, 190, 210, 90))
    save(img, W, H, "assets/environment/bg_ruins.png")


def gen_bg_mist() -> None:
    W, H = 960, 540
    img = canvas(W, H)
    d = ImageDraw.Draw(img)
    for i in range(14):
        x = i * 72 + RNG.uniform(-14, 14)
        h = RNG.uniform(60, 130)
        w = RNG.uniform(10, 22)
        poly(d, [(x - w / 2, H), (x - w * 0.2, H - h), (x, H - h - 12), (x + w * 0.2, H - h), (x + w / 2, H)], (10, 14, 26, 235))
    for band in range(4):
        y_base = 400.0 + band * 34
        pts = [(0.0, H)]
        for x in range(0, W + 1, 16):
            y = y_base + math.sin(x / W * math.tau * (2 + band) + band * 2.1) * (10.0 + band * 3.0)
            pts.append((x, y))
        pts.append((W, H))
        poly(d, pts, (150, 170, 200, 34 + band * 10))
    for _ in range(26):
        x = RNG.uniform(0, W)
        y = RNG.uniform(330, 520)
        ell(d, x, y, 1.4, 1.4, (110, 220, 225, 70))
        ell(d, x, y, 3.6, 3.6, (110, 220, 225, 22))
    save(img, W, H, "assets/environment/bg_foreground_mist.png")


def gen_platform() -> None:
    W, H = 64, 18
    img = canvas(W, H)
    d = ImageDraw.Draw(img)
    grad = vgrad((W * SS, H * SS), (52, 62, 76, 255), (26, 32, 44, 255))
    img.paste(grad, (0, 0))
    line(d, 0, 1.0, W, 1.0, (110, 160, 150, 200), 1.0)
    line(d, 0, 2.4, W, 2.4, (40, 70, 64, 160), 0.8)
    line(d, 0, H - 1.0, W, H - 1.0, (0, 0, 0, 160), 1.0)
    for rx in (14.0, 32.0, 50.0):
        glow_layer(img, lambda g, rx=rx: poly(g, [(rx - 2.5, 6.0), (rx + 2.5, 6.0), (rx, 13.0)], (90, 220, 235, 150)), 1.6, 0.9)
        poly(d, [(rx - 2.0, 6.5), (rx + 2.0, 6.5), (rx, 12.5)], CYAN_HI)
    line(d, 0.5, 0, 0.5, H, (0, 0, 0, 120), 0.8)
    line(d, W - 0.5, 0, W - 0.5, H, (0, 0, 0, 120), 0.8)
    save(img, W, H, "assets/environment/platform_rune.png")


def gen_hazard() -> None:
    W, H = 104, 36
    img = canvas(W, H)
    d = ImageDraw.Draw(img)
    cx, base = 52.0, 34.0
    poly(d, [(cx - 52, base), (cx + 52, base), (cx + 52, base - 8), (cx - 52, base - 8)], (40, 12, 18, 220))
    line(d, cx - 52, base - 8, cx + 52, base - 8, (150, 40, 46, 120), 1.0)
    for i in range(-2, 3):
        x = cx + i * 20.0
        h = 26.0 if i % 2 == 0 else 21.0
        pts = [(x - 7.5, base - 6.0), (x, base - 6.0 - h), (x + 7.5, base - 6.0)]
        fill_poly_grad(img, pts, BONE, (110, 84, 88, 255))
        poly_outline(d, pts, INK, 1.1)
        line(d, x, base - 10.0 - h * 0.55, x, base - 8.0, (250, 210, 200, 150), 1.0)
        tip_y = base - 6.0 - h
        glow_layer(img, lambda g, x=x, ty=tip_y: ell(g, x, ty + 2.0, 2.4, 2.4, (255, 90, 80, 110)), 1.4, 0.9)
        ell(d, x, tip_y + 2.0, 1.6, 1.6, (255, 120, 100, 200))
    save(img, W, H, "assets/environment/hazard_spikes.png")


# ==================================================================== UI ==
def gen_hud_frame() -> None:
    W, H = 302, 108
    img = canvas(W, H)
    d = ImageDraw.Draw(img)
    poly(d, [(2, 2), (W - 2, 2), (W - 2, H - 2), (2, H - 2)], (16, 24, 40, 232))
    inner = vgrad((W * SS, H * SS), (22, 32, 52, 235), (12, 18, 32, 235))
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rectangle([SS * 4, SS * 4, SS * (W - 4), SS * (H - 4)], fill=255)
    img.paste(inner, (0, 0), mask)
    poly_outline(d, [(2, 2), (W - 2, 2), (W - 2, H - 2), (2, H - 2)], GOLD_DEEP, 1.6)
    poly_outline(d, [(5, 5), (W - 5, 5), (W - 5, H - 5), (5, H - 5)], GOLD, 1.0)
    for cxx, cyy, sx, sy in [(6, 6, 1, 1), (W - 6, 6, -1, 1), (6, H - 6, 1, -1), (W - 6, H - 6, -1, -1)]:
        line(d, cxx, cyy, cxx + 10 * sx, cyy, GOLD_HI, 1.6)
        line(d, cxx, cyy, cxx, cyy + 10 * sy, GOLD_HI, 1.6)
        ell(d, cxx + 2 * sx, cyy + 2 * sy, 1.4, 1.4, GOLD_HI)
    line(d, 6, 6.5, W - 6, 6.5, (255, 255, 255, 26), 1.0)
    save(img, W, H, "assets/ui/hud_frame.png")


def gen_bar_under() -> None:
    W, H = 232, 18
    img = canvas(W, H)
    d = ImageDraw.Draw(img)
    poly(d, [(1, 1), (W - 1, 1), (W - 1, H - 1), (1, H - 1)], (10, 14, 24, 240))
    poly_outline(d, [(1, 1), (W - 1, 1), (W - 1, H - 1), (1, H - 1)], GOLD_DEEP, 1.2)
    poly_outline(d, [(3, 3), (W - 3, 3), (W - 3, H - 3), (3, H - 3)], (70, 60, 40, 200), 0.8)
    save(img, W, H, "assets/ui/bar_under.png")


def gen_bar_fill(name: str, c_hi, c_mid, c_low) -> None:
    W, H = 228, 14
    img = canvas(W, H)
    grad = vgrad((W * SS, H * SS), c_hi, c_mid)
    img.paste(grad, (0, 0))
    d = ImageDraw.Draw(img)
    line(d, 0, H - 2.0, W, H - 2.0, c_low, 2.0)
    line(d, 0, 1.2, W, 1.2, (255, 255, 255, 70), 0.9)
    save(img, W, H, f"assets/ui/{name}.png")


def _icon_socket(d, img):
    ell(d, 16, 16, 14.5, 14.5, (14, 20, 34, 245))
    ell_outline(d, 16, 16, 14.5, 14.5, GOLD_DEEP, 1.4)
    ell_outline(d, 16, 16, 12.5, 12.5, GOLD, 0.9)


def icon_rust_blade(d, img):
    _icon_socket(d, img)
    line(d, 9, 23, 22, 10, INK, 4.0)
    line(d, 9, 23, 22, 10, (140, 110, 88, 255), 2.6)
    line(d, 10.5, 21.5, 21, 11, (176, 146, 112, 255), 1.0)
    ell(d, 15, 17, 1.1, 1.1, (14, 20, 34, 255))
    ell(d, 19, 13, 0.9, 0.9, (14, 20, 34, 255))
    line(d, 7, 21, 11, 25, GOLD, 2.2)
    line(d, 6, 24, 9, 27, (90, 70, 40, 255), 2.0)


def icon_rift_saber(d, img):
    _icon_socket(d, img)
    glow_layer(img, lambda g: line(g, 9, 23, 24, 8, (90, 220, 240, 200), 5.0), 2.0, 0.9)
    line(d, 9, 23, 24, 8, INK, 3.6)
    line(d, 9, 23, 24, 8, CYAN, 2.4)
    line(d, 9, 23, 24, 8, CYAN_HI, 1.0)
    line(d, 7, 21, 11, 25, GOLD, 2.2)
    line(d, 6, 24, 9, 27, (90, 70, 40, 255), 2.0)


def icon_ash_vest(d, img):
    _icon_socket(d, img)
    pts = [(11, 9), (21, 9), (24, 14), (22, 25), (10, 25), (8, 14)]
    poly(d, pts, (96, 100, 110, 255))
    poly_outline(d, pts, INK, 1.1)
    line(d, 16, 9, 16, 25, (60, 64, 74, 255), 1.6)
    line(d, 8, 14, 24, 14, (130, 134, 146, 255), 1.0)


def icon_warden_mail(d, img):
    _icon_socket(d, img)
    pts = [(11, 9), (21, 9), (24, 14), (22, 25), (10, 25), (8, 14)]
    poly(d, pts, (110, 26, 40, 255))
    poly_outline(d, pts, INK, 1.1)
    line(d, 16, 9, 16, 25, (70, 14, 24, 255), 1.6)
    line(d, 8, 14, 24, 14, GOLD, 1.2)
    ell(d, 16, 19, 2.0, 2.0, GOLD_HI)


def gen_joystick() -> None:
    W = 176
    img = canvas(W, W)
    d = ImageDraw.Draw(img)
    c = W / 2.0
    glow_layer(img, lambda g: ell(g, c, c, 80.0, 80.0, (30, 44, 70, 90)), 4.0, 0.8)
    ell(d, c, c, 78.0, 78.0, (12, 18, 32, 200))
    ell(d, c, c, 72.0, 72.0, (24, 34, 56, 225))
    ell_outline(d, c, c, 72.0, 72.0, GOLD_DEEP, 2.4)
    ell_outline(d, c, c, 68.0, 68.0, GOLD, 1.4)
    for ang in range(4):
        a = ang * math.pi / 2.0
        line(d, c + math.cos(a) * 46.0, c + math.sin(a) * 46.0, c + math.cos(a) * 56.0, c + math.sin(a) * 56.0, (170, 184, 205, 90), 2.0)
    save(img, W, W, "assets/ui/joystick_base.png")

    W = 72
    img = canvas(W, W)
    d = ImageDraw.Draw(img)
    c = W / 2.0
    ell(d, c, c + 2.0, 30.0, 30.0, (60, 46, 26, 255))
    ell(d, c, c, 28.0, 28.0, GOLD)
    ell(d, c - 6.0, c - 7.0, 12.0, 10.0, GOLD_HI)
    ell(d, c + 8.0, c + 9.0, 10.0, 8.0, GOLD_DEEP)
    ell_outline(d, c, c, 28.0, 28.0, (60, 46, 22, 255), 1.6)
    save(img, W, W, "assets/ui/joystick_knob.png")


def _button_base(d, img, ring):
    W = 96
    c = W / 2.0
    glow_layer(img, lambda g: ell(g, c, c, 44.0, 44.0, ring), 3.0, 0.5)
    ell(d, c, c, 42.0, 42.0, (14, 20, 34, 225))
    ell(d, c, c + 3.0, 36.0, 36.0, (8, 12, 22, 200))
    ell(d, c, c, 36.0, 36.0, (26, 34, 54, 235))
    ell_outline(d, c, c, 42.0, 42.0, GOLD_DEEP, 2.2)
    ell_outline(d, c, c, 38.5, 38.5, ring, 2.0)


def glyph_attack(d, img):
    c = 48.0
    glow_layer(img, lambda g: line(g, c - 14, c + 14, c + 14, c - 14, (255, 120, 110, 180), 6.0), 2.0, 0.8)
    line(d, c - 14, c + 14, c + 14, c - 14, SILVER_HI, 4.0)
    line(d, c - 14, c + 14, c + 14, c - 14, (255, 230, 230, 255), 1.4)
    line(d, c - 18, c + 6, c - 6, c + 18, GOLD, 3.4)
    line(d, c + 6, c - 18, c + 18, c - 6, (150, 150, 160, 255), 3.0)


def glyph_jump(d, img):
    c = 48.0
    for i, (dy, wdt, col) in enumerate([(6, 5.0, CYAN), (-4, 4.0, CYAN_HI), (-13, 3.0, (230, 250, 255, 255))]):
        line(d, c - 16 + i * 2, c + 10 + dy, c, c + dy - 2, col, wdt)
        line(d, c + 16 - i * 2, c + 10 + dy, c, c + dy - 2, col, wdt)


def glyph_skill_one(d, img):
    c = 48.0
    glow_layer(img, lambda g: ell(g, c, c, 12.0, 12.0, (90, 200, 245, 200)), 2.4, 0.9)
    ell(d, c, c, 9.0, 9.0, (40, 120, 190, 255))
    ell(d, c, c, 6.0, 6.0, CYAN_HI)
    for a in range(8):
        ang = a * math.tau / 8.0 + 0.4
        line(d, c + math.cos(ang) * 12.0, c + math.sin(ang) * 12.0, c + math.cos(ang) * 18.0, c + math.sin(ang) * 18.0, CYAN, 2.0)


def glyph_skill_two(d, img):
    c = 48.0
    glow_layer(img, lambda g: ell(g, c, c, 12.0, 12.0, (180, 120, 250, 200)), 2.4, 0.9)
    ell(d, c, c, 9.0, 9.0, (90, 40, 160, 255))
    ell(d, c, c, 6.0, 6.0, VIOLET_HI)
    for a in range(8):
        ang = a * math.tau / 8.0
        line(d, c + math.cos(ang) * 12.0, c + math.sin(ang) * 12.0, c + math.cos(ang) * 18.0, c + math.sin(ang) * 18.0, VIOLET, 2.0)


def gen_pause() -> None:
    W = 64
    img = canvas(W, W)
    d = ImageDraw.Draw(img)
    c = W / 2.0
    ell(d, c, c, 28.0, 28.0, (12, 18, 32, 225))
    ell_outline(d, c, c, 28.0, 28.0, (170, 184, 205, 230), 1.8)
    ell_outline(d, c, c, 25.0, 25.0, (90, 100, 120, 180), 1.0)
    line(d, c - 6.0, c - 9.0, c - 6.0, c + 9.0, (235, 240, 248, 255), 4.0)
    line(d, c + 6.0, c - 9.0, c + 6.0, c + 9.0, (235, 240, 248, 255), 4.0)
    save(img, W, W, "assets/ui/button_pause.png")


# =================================================================== VFX ==
def gen_slash(name: str, size: int, a0, a1, color, color_hi, width: float) -> None:
    img = canvas(size, size)
    d = ImageDraw.Draw(img)
    c = size / 2.0
    glow_layer(img, lambda g: crescent(g, c, c, size * 0.30, a0, a1, color, width * 1.6), size * 0.05, 0.85)
    crescent(d, c, c, size * 0.30, a0, a1, color, width)
    crescent(d, c, c, size * 0.30, a0 + 0.06, a1 - 0.06, color_hi, width * 0.4)
    save(img, size, size, f"assets/vfx/{name}.png")


def gen_projectile() -> None:
    W, H = 48, 24
    img = canvas(W, H)
    d = ImageDraw.Draw(img)
    cy = 12.0
    glow_layer(img, lambda g: poly(g, [(2, cy), (30, cy - 4.0), (30, cy + 4.0)], (120, 70, 210, 130)), 2.0, 0.9)
    poly(d, [(2, cy), (30, cy - 3.0), (30, cy + 3.0)], (110, 60, 190, 200))
    poly(d, [(6, cy), (28, cy - 1.6), (28, cy + 1.6)], (170, 120, 240, 220))
    glow_layer(img, lambda g: ell(g, 34.0, cy, 9.0, 7.0, (90, 220, 240, 190)), 2.4, 0.9)
    ell(d, 34.0, cy, 7.5, 6.0, (60, 170, 210, 235))
    ell(d, 35.0, cy, 4.5, 3.6, CYAN_HI)
    ell(d, 36.0, cy, 2.0, 1.8, (255, 255, 255, 240))
    save(img, W, H, "assets/vfx/skill_two_projectile.png")


def gen_hit_spark() -> None:
    W = 48
    img = canvas(W, W)
    d = ImageDraw.Draw(img)
    c = W / 2.0
    glow_layer(img, lambda g: ell(g, c, c, 14.0, 14.0, (255, 220, 140, 180)), 3.0, 0.9)
    for a in range(6):
        ang = a * math.tau / 6.0 + 0.3
        r_out = 20.0 if a % 2 == 0 else 13.0
        poly(d, [(c + math.cos(ang - 0.10) * 4.0, c + math.sin(ang - 0.10) * 4.0),
                 (c + math.cos(ang) * r_out, c + math.sin(ang) * r_out),
                 (c + math.cos(ang + 0.10) * 4.0, c + math.sin(ang + 0.10) * 4.0)], GOLD_HI)
    ell(d, c, c, 6.0, 6.0, (255, 252, 240, 255))
    save(img, W, W, "assets/vfx/hit_spark.png")


def gen_dust() -> None:
    W = 32
    img = canvas(W, W)
    d = ImageDraw.Draw(img)
    for cx, cy, r, a in [(13, 20, 6.0, 120), (21, 18, 5.0, 100), (17, 13, 4.0, 80), (25, 22, 3.4, 70)]:
        ell(d, cx, cy, r, r * 0.8, (168, 160, 148, a))
    img = img.filter(ImageFilter.GaussianBlur(SS * 0.8))
    save(img, W, W, "assets/vfx/dust.png")


def build_all() -> None:
    gen_tiles()
    gen_bg_sky()
    gen_bg_ruins()
    gen_bg_mist()
    gen_platform()
    gen_hazard()
    gen_hud_frame()
    gen_bar_under()
    gen_bar_fill("hp_fill", (232, 74, 84, 255), (150, 22, 36, 255), (86, 10, 20, 255))
    gen_bar_fill("mp_fill", (110, 190, 245, 255), (30, 110, 190, 255), (14, 60, 120, 255))
    gen_bar_fill("exp_fill", (240, 196, 110, 255), (180, 130, 44, 255), (110, 76, 24, 255))
    gen_bar_fill("boss_fill", (220, 60, 90, 255), (140, 16, 40, 255), (80, 8, 26, 255))
    for name, painter in [("icon_rust_blade", icon_rust_blade), ("icon_rift_saber", icon_rift_saber),
                          ("icon_ash_vest", icon_ash_vest), ("icon_warden_mail", icon_warden_mail)]:
        img = canvas(32, 32)
        d = ImageDraw.Draw(img)
        painter(d, img)
        save(img, 32, 32, f"assets/ui/{name}.png")
    gen_joystick()
    for name, ring, glyph in [("button_attack", (210, 60, 66, 255), glyph_attack),
                              ("button_jump", (60, 170, 205, 255), glyph_jump),
                              ("button_skill_1", (70, 140, 220, 255), glyph_skill_one),
                              ("button_skill_2", (150, 90, 220, 255), glyph_skill_two)]:
        img = canvas(96, 96)
        d = ImageDraw.Draw(img)
        _button_base(d, img, ring)
        glyph(d, img)
        save(img, 96, 96, f"assets/ui/{name}.png")
    gen_pause()
    gen_slash("slash_1", 64, -2.4, 0.6, (255, 200, 90, 220), (255, 246, 210, 255), 7.0)
    gen_slash("slash_2", 64, 0.7, 3.6, (255, 214, 120, 220), (255, 248, 220, 255), 7.0)
    gen_slash("skill_one_slash", 96, -2.2, 0.8, (90, 210, 235, 230), (200, 250, 255, 255), 11.0)
    gen_projectile()
    gen_hit_spark()
    gen_dust()


def main() -> int:
    build_all()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
