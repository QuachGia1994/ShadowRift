"""Character frame renderers: Hero, Warden, Wraith, Rift Warden boss.

All characters are drawn FACING RIGHT; Godot flips via flip_h.
Canvas pivots: hero/warden/wraith 64x64, boss 128x128, feet near bottom.
"""
from __future__ import annotations

import math

from PIL import Image

from oa_common import (
    INK, CHARCOAL_HI, NAVY_DEEP, CRIMSON, CRIMSON_HI, CRIMSON_DEEP, GOLD, GOLD_HI,
    GOLD_DEEP, SILVER, SILVER_HI, CYAN, CYAN_HI, VIOLET, VIOLET_HI, BONE,
    OBSIDIAN_HI, SS, canvas, poly, poly_outline, ell, ell_outline, line,
    glow_layer, fill_poly_grad, tint_flash, apply_alpha, crescent, compose_sheet,
)

SHEET_COLS = 8


# =================================================================== HERO ==
def draw_hero(p: dict) -> Image.Image:
    from PIL.ImageDraw import Draw as _D
    img = canvas(64, 64)
    d = _D(img)
    bob = p.get("bob", 0.0)
    lean = p.get("lean", 0.0)
    cape = p.get("cape", 0.0)
    leg_f = p.get("leg_f", 0.0)
    leg_b = p.get("leg_b", 0.0)
    crouch = p.get("crouch", 0.0)
    sword_a = p.get("sword_a", -0.45)
    sword_len = p.get("sword_len", 26.0)
    glow = p.get("glow")
    eye = p.get("eye", 1.0)
    apply_alpha(img, p.get("alpha", 1.0))

    hip_y = 44.0 + bob + crouch * 6.0
    shoulder_y = 27.0 + bob + crouch * 3.0
    head_y = 19.5 + bob + crouch * 3.0
    cx = 32.0 + lean

    if not p.get("no_shadow"):
        sw = 11.0 if p.get("airborne") else 15.0
        sa = int((150 if p.get("airborne") else 88) * p.get("alpha", 1.0))
        ell(d, 32.0, 61.0, sw, 3.0, (0, 0, 0, sa))

    # cape behind body
    cape_pts = [(cx - 4.0, shoulder_y + 2.0), (cx - 15.0 - cape * 4.0, shoulder_y + 10.0 + cape * 2.0),
                (12.0 - cape * 6.0, hip_y + 8.0 + cape * 3.0), (cx - 2.0, hip_y + 2.0)]
    fill_poly_grad(img, cape_pts, CRIMSON_HI, CRIMSON_DEEP)
    poly_outline(d, cape_pts, INK, 1.1)

    # legs + boots
    line(d, cx - 3.0, hip_y, cx - 4.0 + leg_b, 58.0 + bob * 0.4, INK, 5.4)
    line(d, cx - 3.0, hip_y, cx - 4.0 + leg_b, 57.0 + bob * 0.4, (34, 44, 66, 255), 3.4)
    line(d, cx + 3.0, hip_y, cx + 4.0 + leg_f, 58.0 + bob * 0.4, INK, 5.8)
    line(d, cx + 3.0, hip_y, cx + 4.0 + leg_f, 57.0 + bob * 0.4, (40, 52, 78, 255), 3.8)
    ell(d, cx - 4.0 + leg_b, 58.5 + bob * 0.4, 3.4, 2.2, INK)
    ell(d, cx + 4.0 + leg_f, 58.5 + bob * 0.4, 3.6, 2.3, (52, 44, 40, 255))

    # torso
    torso = [(cx - 8.0, shoulder_y), (cx + 8.0, shoulder_y), (cx + 9.0, hip_y + 2.0), (cx - 9.0, hip_y + 2.0)]
    fill_poly_grad(img, torso, CHARCOAL_HI, NAVY_DEEP)
    poly_outline(d, torso, INK, 1.2)
    line(d, cx - 6.0, shoulder_y + 3.0, cx + 7.0, hip_y - 2.0, CRIMSON_DEEP, 2.6)
    line(d, cx - 8.0, hip_y - 4.0, cx + 8.0, hip_y - 4.0, GOLD, 2.4)
    ell(d, cx, hip_y - 4.0, 2.0, 2.0, GOLD_HI)

    # back arm
    line(d, cx - 5.0, shoulder_y + 4.0, cx - 10.0, hip_y - 2.0, INK, 4.6)

    # hooded head + glowing eye
    hood = [(cx - 8.0, head_y + 6.0), (cx - 7.0, head_y - 4.0), (cx + 1.0, head_y - 8.5),
            (cx + 8.0, head_y - 3.0), (cx + 8.5, head_y + 6.0)]
    fill_poly_grad(img, hood, CHARCOAL_HI, NAVY_DEEP)
    poly_outline(d, hood, INK, 1.2)
    ell(d, cx + 3.4, head_y + 1.0, 4.4, 4.6, (16, 12, 16, 255))
    if eye > 0.0:
        ell(d, cx + 4.6, head_y + 0.6, 1.5, 1.2, (255, 196, 92, int(230 * eye)))
        glow_layer(img, lambda g: ell(g, cx + 4.6, head_y + 0.6, 2.6, 2.2, (255, 170, 60, int(110 * eye))), 1.6)
    line(d, cx - 7.0, head_y - 3.4, cx + 7.6, head_y - 3.4, GOLD_DEEP, 1.6)

    # front arm to grip
    grip = (cx + 10.0 + math.cos(sword_a) * 4.0, hip_y - 8.0 + math.sin(sword_a) * 4.0 + crouch * 2.0)
    line(d, cx + 5.0, shoulder_y + 5.0, grip[0], grip[1], INK, 5.0)
    line(d, cx + 5.0, shoulder_y + 5.0, grip[0], grip[1], (46, 58, 86, 255), 3.0)

    # sword
    tip = (grip[0] + math.cos(sword_a) * sword_len, grip[1] + math.sin(sword_a) * sword_len)
    if glow is not None:
        glow_layer(img, lambda g: line(g, grip[0], grip[1], tip[0], tip[1], glow, 7.0), 2.6, 0.8)
    line(d, grip[0], grip[1], tip[0], tip[1], INK, 4.2)
    line(d, grip[0], grip[1], tip[0], tip[1], SILVER, 2.6)
    line(d, grip[0], grip[1], tip[0], tip[1], SILVER_HI, 1.1)
    perp = sword_a + math.pi / 2.0
    line(d, grip[0] - math.cos(perp) * 3.4, grip[1] - math.sin(perp) * 3.4,
         grip[0] + math.cos(perp) * 3.4, grip[1] + math.sin(perp) * 3.4, GOLD, 2.6)
    line(d, grip[0] - math.cos(sword_a) * 3.6, grip[1] - math.sin(sword_a) * 3.6, grip[0], grip[1], (60, 40, 30, 255), 2.6)

    tint_flash(img, (14, 8, 52, 62), p.get("flash", 0.0))
    return img


def hero_frames() -> list:
    frames = []
    for i, bob in enumerate([0.0, -0.8, -1.6, -0.8]):  # idle
        frames.append(draw_hero({"bob": bob, "cape": 0.5 + 0.3 * math.sin(i * 1.4), "sword_a": -0.9, "sword_len": 20.0}))
    for i in range(6):  # move
        ph = i / 6.0 * math.tau
        frames.append(draw_hero({"bob": -abs(math.sin(ph)) * 1.8, "lean": 2.2, "cape": 2.2 + math.sin(ph) * 0.6,
                                 "leg_f": math.sin(ph) * 7.0, "leg_b": -math.sin(ph) * 7.0,
                                 "sword_a": -0.35 + math.sin(ph) * 0.1, "sword_len": 22.0}))
    frames.append(draw_hero({"bob": -1.0, "leg_f": -5.0, "leg_b": 3.0, "cape": -2.5, "sword_a": -1.1,
                             "sword_len": 20.0, "airborne": True}))  # jump rise
    frames.append(draw_hero({"bob": 0.5, "leg_f": 4.0, "leg_b": -2.0, "cape": 3.4, "sword_a": -0.7,
                             "sword_len": 20.0, "airborne": True}))  # jump fall
    frames.append(draw_hero({"lean": -1.5, "sword_a": -2.4, "sword_len": 26.0, "cape": -1.0}))  # attack1 windup
    frames.append(draw_hero({"lean": 3.0, "sword_a": 0.55, "sword_len": 28.0, "cape": 3.0, "leg_f": 5.0}))  # slash
    frames.append(draw_hero({"lean": 2.0, "sword_a": 0.9, "sword_len": 26.0, "cape": 2.0, "leg_f": 3.0}))  # recover
    frames.append(draw_hero({"lean": 2.5, "sword_a": 1.2, "sword_len": 26.0, "cape": 2.5}))  # attack2 windup
    frames.append(draw_hero({"lean": -1.0, "sword_a": -1.9, "sword_len": 28.0, "cape": -1.5, "bob": -1.5}))  # rising cut
    frames.append(draw_hero({"lean": -0.5, "sword_a": -1.4, "sword_len": 25.0, "cape": -0.5}))  # recover
    frames.append(draw_hero({"lean": -2.0, "sword_a": -2.6, "sword_len": 27.0, "glow": (90, 220, 235, 200), "cape": -2.0}))  # skill_one charge
    frames.append(draw_hero({"lean": 3.5, "sword_a": 0.7, "sword_len": 30.0, "glow": (120, 235, 245, 230), "cape": 3.5, "leg_f": 6.0}))  # heavy slash
    frames.append(draw_hero({"lean": 2.5, "sword_a": 1.0, "sword_len": 28.0, "glow": (90, 200, 235, 150), "cape": 2.5}))  # hold
    frames.append(draw_hero({"lean": -1.0, "sword_a": -1.2, "sword_len": 18.0, "glow": (170, 110, 240, 190)}))  # skill_two cast up
    frames.append(draw_hero({"lean": 1.5, "sword_a": -0.6, "sword_len": 16.0, "glow": (190, 130, 250, 230), "bob": -1.0}))  # release
    frames.append(draw_hero({"lean": 2.0, "sword_a": -0.4, "sword_len": 16.0, "glow": (150, 100, 230, 120)}))  # follow
    frames.append(draw_hero({"lean": -3.5, "bob": 1.0, "flash": 1.0, "sword_a": -1.6, "cape": -2.0}))  # hurt
    frames.append(draw_hero({"lean": -2.0, "bob": 0.5, "flash": 0.45, "sword_a": -1.3, "cape": -1.0}))
    frames.append(draw_hero({"lean": -4.0, "bob": 2.0, "flash": 0.6, "crouch": 0.4, "sword_a": -1.8, "cape": -1.0}))  # death stagger
    frames.append(draw_hero({"lean": -5.0, "bob": 4.0, "crouch": 1.0, "sword_a": -2.2, "cape": 0.0, "eye": 0.4}))  # kneel
    fallen = draw_hero({"lean": 0.0, "crouch": 1.4, "sword_a": -2.6, "cape": 1.0, "eye": 0.2, "no_shadow": True})
    fallen = fallen.rotate(-78, expand=True, resample=Image.BICUBIC)
    lie = canvas(64, 64)
    lie.alpha_composite(fallen, (int(2 * SS), int(24 * SS)))
    from oa_common import ell as _ell
    from PIL.ImageDraw import Draw as _D2
    _ell(_D2(lie), 32.0, 60.0, 17.0, 3.0, (0, 0, 0, 80))
    frames.append(lie)  # fallen
    frames.append(lie)  # rest
    return frames


# ================================================================= WARDEN ==
def draw_warden(p: dict) -> Image.Image:
    from PIL.ImageDraw import Draw as _D
    img = canvas(64, 64)
    d = _D(img)
    bob = p.get("bob", 0.0)
    lean = p.get("lean", 0.0)
    leg_f = p.get("leg_f", 0.0)
    leg_b = p.get("leg_b", 0.0)
    arm_a = p.get("arm_a", 0.5)
    shield = p.get("shield", 1.0)
    eye = p.get("eye", 1.0)
    apply_alpha(img, p.get("alpha", 1.0))

    ell(d, 32.0, 61.0, 15.0, 3.0, (0, 0, 0, 92))
    hip_y = 42.0 + bob
    shoulder_y = 24.0 + bob
    cx = 32.0 + lean

    line(d, cx - 4.0, hip_y, cx - 5.0 + leg_b, 58.0, INK, 6.4)
    line(d, cx - 4.0, hip_y, cx - 5.0 + leg_b, 57.0, (36, 34, 48, 255), 4.2)
    line(d, cx + 4.0, hip_y, cx + 5.0 + leg_f, 58.0, INK, 6.8)
    line(d, cx + 4.0, hip_y, cx + 5.0 + leg_f, 57.0, (46, 42, 60, 255), 4.6)
    ell(d, cx - 5.0 + leg_b, 58.5, 3.8, 2.4, INK)
    ell(d, cx + 5.0 + leg_f, 58.5, 4.0, 2.5, (54, 40, 38, 255))

    torso = [(cx - 10.0, shoulder_y), (cx + 10.0, shoulder_y), (cx + 12.0, hip_y + 3.0), (cx - 12.0, hip_y + 3.0)]
    fill_poly_grad(img, torso, OBSIDIAN_HI, (14, 12, 22, 255))
    poly_outline(d, torso, INK, 1.3)
    tab = [(cx - 4.0, shoulder_y + 2.0), (cx + 4.0, shoulder_y + 2.0), (cx + 5.0, hip_y + 6.0), (cx - 5.0, hip_y + 6.0)]
    fill_poly_grad(img, tab, CRIMSON, CRIMSON_DEEP)
    poly_outline(d, tab, INK, 1.0)
    line(d, cx - 10.0, hip_y - 1.0, cx + 10.0, hip_y - 1.0, GOLD_DEEP, 2.2)
    line(d, cx - 9.0, shoulder_y + 1.5, cx + 9.0, shoulder_y + 1.5, GOLD, 1.8)

    helm = [(cx - 8.0, shoulder_y + 1.0), (cx - 8.5, shoulder_y - 8.0), (cx - 3.0, shoulder_y - 13.0),
            (cx + 4.0, shoulder_y - 13.0), (cx + 8.5, shoulder_y - 8.0), (cx + 8.0, shoulder_y + 1.0)]
    fill_poly_grad(img, helm, OBSIDIAN_HI, (16, 14, 26, 255))
    poly_outline(d, helm, INK, 1.3)
    poly(d, [(cx - 1.5, shoulder_y - 16.0), (cx + 2.5, shoulder_y - 16.0), (cx + 1.0, shoulder_y - 9.0), (cx - 2.0, shoulder_y - 9.0)], CRIMSON)
    line(d, cx - 1.0, shoulder_y - 6.0, cx + 8.0, shoulder_y - 6.0, (8, 6, 10, 255), 2.6)
    if eye > 0.0:
        ell(d, cx + 5.4, shoulder_y - 6.0, 1.6, 1.2, (255, 46, 56, int(235 * eye)))
        glow_layer(img, lambda g: ell(g, cx + 5.4, shoulder_y - 6.0, 2.8, 2.2, (255, 40, 50, int(120 * eye))), 1.8)

    sh_top = shoulder_y + 2.0 - shield * 3.0
    shield_pts = [(cx + 9.0, sh_top - 4.0), (cx + 19.0, sh_top - 1.0), (cx + 19.0, hip_y + 8.0), (cx + 9.0, hip_y + 10.0)]
    fill_poly_grad(img, shield_pts, (52, 48, 66, 255), (18, 16, 28, 255))
    poly_outline(d, shield_pts, INK, 1.3)
    line(d, cx + 14.0, sh_top + 1.0, cx + 14.0, hip_y + 6.0, CRIMSON, 2.2)
    ell(d, cx + 14.0, (sh_top + hip_y) / 2.0 + 2.0, 2.0, 2.0, GOLD)

    elbow = (cx - 10.0, shoulder_y + 6.0)
    hand = (elbow[0] + math.cos(arm_a) * 12.0, elbow[1] - math.sin(arm_a) * 12.0)
    line(d, elbow[0], elbow[1], hand[0], hand[1], INK, 5.6)
    line(d, elbow[0], elbow[1], hand[0], hand[1], (40, 36, 54, 255), 3.6)
    ha = arm_a + 0.5
    haft_tip = (hand[0] + math.cos(ha) * 16.0, hand[1] - math.sin(ha) * 16.0)
    line(d, hand[0] - math.cos(ha) * 5.0, hand[1] + math.sin(ha) * 5.0, haft_tip[0], haft_tip[1], (74, 56, 40, 255), 2.8)
    blade = [(haft_tip[0] + math.cos(ha + 1.5) * 7.0, haft_tip[1] - math.sin(ha + 1.5) * 7.0),
             (haft_tip[0] + math.cos(ha) * 11.0, haft_tip[1] - math.sin(ha) * 11.0),
             (haft_tip[0] + math.cos(ha - 1.2) * 6.0, haft_tip[1] - math.sin(ha - 1.2) * 6.0)]
    poly(d, blade, SILVER)
    poly_outline(d, blade, INK, 1.0)

    tint_flash(img, (12, 6, 54, 62), p.get("flash", 0.0))
    return img


def warden_frames() -> list:
    frames = []
    for i in range(4):  # patrol
        ph = i / 4.0 * math.tau
        frames.append(draw_warden({"bob": -abs(math.sin(ph)) * 1.4, "leg_f": math.sin(ph) * 5.0,
                                   "leg_b": -math.sin(ph) * 5.0, "lean": 1.0}))
    frames.append(draw_warden({"lean": 2.0}))   # aggro
    frames.append(draw_warden({"lean": 3.0, "bob": -1.0}))
    frames.append(draw_warden({"arm_a": 1.9, "shield": 0.6, "lean": -1.0}))  # attack windup
    frames.append(draw_warden({"arm_a": -0.6, "shield": 0.2, "lean": 4.0, "leg_f": 6.0}))  # smash
    frames.append(draw_warden({"arm_a": -0.2, "lean": 3.0}))  # hold
    frames.append(draw_warden({"flash": 1.0, "lean": -3.0}))  # hurt
    frames.append(draw_warden({"flash": 0.4, "lean": -2.0}))
    frames.append(draw_warden({"lean": -4.0, "bob": 3.0, "eye": 0.5}))  # death
    frames.append(draw_warden({"lean": -6.0, "bob": 6.0, "eye": 0.2}))
    kneel = draw_warden({"lean": -2.0, "bob": 8.0, "eye": 0.0})
    kneel = kneel.rotate(-70, expand=True, resample=Image.BICUBIC)
    down = canvas(64, 64)
    down.alpha_composite(kneel, (int(4 * SS), int(22 * SS)))
    from oa_common import ell as _ell
    from PIL.ImageDraw import Draw as _D
    _ell(_D(down), 32.0, 61.0, 17.0, 3.0, (0, 0, 0, 80))
    frames.append(down)
    frames.append(down)
    return frames


# ================================================================= WRAITH ==
def draw_wraith(p: dict) -> Image.Image:
    from PIL.ImageDraw import Draw as _D
    img = canvas(64, 64)
    d = _D(img)
    bob = p.get("bob", 0.0)
    stretch = p.get("stretch", 0.0)
    tail = p.get("tail", 0.0)
    apply_alpha(img, p.get("alpha", 1.0))

    cy = 30.0 + bob
    cx = 32.0 + stretch * 4.0

    glow_layer(img, lambda g: ell(g, cx, cy, 16.0 + stretch * 4.0, 18.0, (110, 60, 190, 70)), 3.0, 0.9)

    robe = [(cx - 1.0, cy - 16.0), (cx + 10.0 - stretch * 2.0, cy - 6.0), (cx + 12.0 - stretch * 3.0, cy + 8.0),
            (cx + 6.0, cy + 14.0 + tail), (cx + 2.0, cy + 9.0 + tail * 0.4), (cx - 3.0, cy + 15.0 - tail),
            (cx - 8.0, cy + 9.0 - tail * 0.5), (cx - 11.0, cy + 13.0 + tail * 0.6),
            (cx - 12.0, cy - 2.0), (cx - 8.0, cy - 12.0)]
    fill_poly_grad(img, robe, (86, 44, 140, 255), (36, 18, 66, 255))
    poly_outline(d, robe, (18, 10, 30, 255), 1.2)

    hood = [(cx - 8.0, cy - 10.0), (cx - 6.0, cy - 19.0), (cx + 2.0, cy - 22.0), (cx + 9.0, cy - 15.0), (cx + 8.0, cy - 6.0)]
    fill_poly_grad(img, hood, (60, 30, 100, 255), (30, 14, 54, 255))
    poly_outline(d, hood, (18, 10, 30, 255), 1.2)
    ell(d, cx + 2.0, cy - 12.5, 5.0, 5.4, (8, 6, 14, 255))
    for ex in (cx - 0.5, cx + 5.0):
        ell(d, ex, cy - 13.0, 1.4, 1.1, CYAN_HI)
    glow_layer(img, lambda g: [ell(g, cx - 0.5, cy - 13.0, 2.4, 2.0, (90, 220, 235, 120)),
                               ell(g, cx + 5.0, cy - 13.0, 2.4, 2.0, (90, 220, 235, 120))], 1.8)

    line(d, cx + 6.0, cy - 2.0, cx + 13.0 + stretch * 3.0, cy + 4.0 + tail, (40, 20, 70, 255), 3.0)
    line(d, cx - 6.0, cy - 1.0, cx - 12.0, cy + 5.0 - tail, (40, 20, 70, 255), 3.0)

    tint_flash(img, (14, 6, 52, 58), p.get("flash", 0.0))
    return img


def wraith_frames() -> list:
    frames = []
    for i in range(4):  # hover
        ph = i / 4.0 * math.tau
        frames.append(draw_wraith({"bob": math.sin(ph) * 2.4, "tail": math.sin(ph + 1.0) * 2.2}))
    frames.append(draw_wraith({"stretch": 1.0, "tail": -2.0}))   # dash_attack
    frames.append(draw_wraith({"stretch": 1.6, "tail": -3.0, "bob": -1.0}))
    frames.append(draw_wraith({"stretch": 0.6, "tail": -1.0}))
    frames.append(draw_wraith({"flash": 1.0, "bob": 1.0}))       # hurt
    frames.append(draw_wraith({"flash": 0.4}))
    frames.append(draw_wraith({"alpha": 0.75, "bob": 2.0, "tail": 2.0}))  # death dissolve
    frames.append(draw_wraith({"alpha": 0.5, "bob": 4.0, "tail": 3.5}))
    frames.append(draw_wraith({"alpha": 0.28, "bob": 6.0, "tail": 4.5}))
    frames.append(draw_wraith({"alpha": 0.0}))
    return frames


# =================================================================== BOSS ==
def draw_boss(p: dict) -> Image.Image:
    from PIL.ImageDraw import Draw as _D
    img = canvas(128, 128)
    d = _D(img)
    bob = p.get("bob", 0.0)
    lean = p.get("lean", 0.0)
    leg_f = p.get("leg_f", 0.0)
    leg_b = p.get("leg_b", 0.0)
    arm_a = p.get("arm_a", 0.35)
    charge = p.get("charge", 0.0)
    eye = p.get("eye", 1.0)
    apply_alpha(img, p.get("alpha", 1.0))

    ell(d, 64.0, 122.0, 30.0, 5.0, (0, 0, 0, 100))
    hip_y = 88.0 + bob
    shoulder_y = 52.0 + bob
    head_y = 38.0 + bob
    cx = 64.0 + lean

    if charge > 0.0:
        ca = int(120 * charge)
        glow_layer(img, lambda g: ell(g, cx, (shoulder_y + hip_y) / 2.0, 46.0, 50.0, (200, 30, 60, ca)), 5.0, 0.9)

    line(d, cx - 12.0, hip_y, cx - 15.0 + leg_b, 116.0, INK, 12.0)
    line(d, cx - 12.0, hip_y, cx - 15.0 + leg_b, 114.0, (44, 30, 48, 255), 8.0)
    line(d, cx + 12.0, hip_y, cx + 15.0 + leg_f, 116.0, INK, 13.0)
    line(d, cx + 12.0, hip_y, cx + 15.0 + leg_f, 114.0, (58, 38, 52, 255), 9.0)
    poly(d, [(cx - 21.0 + leg_b, 118.0), (cx - 8.0 + leg_b, 118.0), (cx - 10.0 + leg_b, 113.0), (cx - 19.0 + leg_b, 113.0)], (26, 18, 28, 255))
    poly(d, [(cx + 8.0 + leg_f, 118.0), (cx + 21.0 + leg_f, 118.0), (cx + 19.0 + leg_f, 113.0), (cx + 10.0 + leg_f, 113.0)], (26, 18, 28, 255))

    torso = [(cx - 22.0, shoulder_y), (cx + 22.0, shoulder_y), (cx + 26.0, hip_y + 6.0), (cx - 26.0, hip_y + 6.0)]
    fill_poly_grad(img, torso, (52, 34, 62, 255), (20, 12, 30, 255))
    poly_outline(d, torso, INK, 1.6)
    core_y = (shoulder_y + hip_y) / 2.0 + 2.0
    ell(d, cx, core_y, 7.0, 9.0, CRIMSON_DEEP)
    ell(d, cx, core_y, 4.0, 5.5, CRIMSON)
    glow_layer(img, lambda g: ell(g, cx, core_y, 8.0, 10.0, (230, 40, 70, 90)), 3.0)
    line(d, cx - 22.0, hip_y - 2.0, cx + 22.0, hip_y - 2.0, GOLD_DEEP, 3.4)
    line(d, cx - 20.0, shoulder_y + 2.0, cx + 20.0, shoulder_y + 2.0, GOLD, 2.6)

    head = [(cx - 13.0, head_y + 10.0), (cx - 12.0, head_y - 4.0), (cx - 4.0, head_y - 11.0),
            (cx + 6.0, head_y - 11.0), (cx + 13.0, head_y - 3.0), (cx + 13.0, head_y + 10.0)]
    fill_poly_grad(img, head, (58, 38, 66, 255), (24, 14, 34, 255))
    poly_outline(d, head, INK, 1.6)
    for side in (-1, 1):
        horn = [(cx + side * 3.0, head_y + 2.0), (cx + side * 13.0, head_y - 2.0), (cx + side * 24.0, head_y - 14.0),
                (cx + side * 28.0, head_y - 26.0), (cx + side * 14.0, head_y - 12.0)]
        fill_poly_grad(img, horn, (150, 34, 52, 255), (70, 14, 26, 255))
        poly_outline(d, horn, INK, 1.2)
    if eye > 0.0:
        for ex in (cx - 6.0, cx + 6.0):
            ell(d, ex, head_y - 1.0, 2.6, 1.8, (255, 40, 56, int(240 * eye)))
        glow_layer(img, lambda g: [ell(g, cx - 6.0, head_y - 1.0, 4.4, 3.2, (255, 36, 56, int(130 * eye))),
                                   ell(g, cx + 6.0, head_y - 1.0, 4.4, 3.2, (255, 36, 56, int(130 * eye)))], 2.4)
    poly(d, [(cx - 7.0, head_y + 5.0), (cx + 7.0, head_y + 5.0), (cx + 4.0, head_y + 9.0), (cx - 4.0, head_y + 9.0)], (10, 6, 12, 255))

    line(d, cx - 16.0, shoulder_y + 8.0, cx - 26.0, hip_y + 2.0, INK, 11.0)
    line(d, cx - 16.0, shoulder_y + 8.0, cx - 26.0, hip_y + 2.0, (46, 30, 52, 255), 7.5)
    ell(d, cx - 27.0, hip_y + 4.0, 7.0, 6.0, (40, 26, 46, 255))
    ell_outline(d, cx - 27.0, hip_y + 4.0, 7.0, 6.0, INK, 1.2)

    shoulder = (cx + 16.0, shoulder_y + 8.0)
    hand = (shoulder[0] + math.cos(arm_a) * 22.0, shoulder[1] - math.sin(arm_a) * 22.0)
    line(d, shoulder[0], shoulder[1], hand[0], hand[1], INK, 12.0)
    line(d, shoulder[0], shoulder[1], hand[0], hand[1], (56, 36, 60, 255), 8.5)
    ell(d, hand[0], hand[1], 6.5, 5.5, (48, 30, 52, 255))
    ca = arm_a + 0.35
    tip = (hand[0] + math.cos(ca) * 28.0, hand[1] - math.sin(ca) * 28.0)
    # screen-space perpendicular of (cos ca, -sin ca) is (sin ca, cos ca)
    perp = (math.sin(ca), math.cos(ca))
    blade = [(hand[0] + perp[0] * 5.0, hand[1] + perp[1] * 5.0),
             (tip[0] + perp[0] * 9.0, tip[1] + perp[1] * 9.0),
             (tip[0] - perp[0] * 3.0, tip[1] - perp[1] * 3.0),
             (hand[0] - perp[0] * 5.0, hand[1] - perp[1] * 5.0)]
    fill_poly_grad(img, blade, SILVER_HI, (120, 132, 150, 255))
    poly_outline(d, blade, INK, 1.4)
    line(d, hand[0], hand[1], tip[0], tip[1], (150, 60, 200, 160), 2.0)

    tint_flash(img, (24, 10, 106, 122), p.get("flash", 0.0))
    return img


def boss_frames() -> list:
    frames = []
    for i in range(4):  # watch
        frames.append(draw_boss({"bob": -1.2 + (i % 2) * 1.2, "eye": 0.8 + 0.2 * math.sin(i * 1.3)}))
    for i in range(4):  # chase
        ph = i / 4.0 * math.tau
        frames.append(draw_boss({"bob": -abs(math.sin(ph)) * 2.0, "lean": 3.0,
                                 "leg_f": math.sin(ph) * 8.0, "leg_b": -math.sin(ph) * 8.0, "arm_a": 0.6}))
    frames.append(draw_boss({"arm_a": 1.9, "lean": -3.0, "charge": 0.5}))            # windup
    frames.append(draw_boss({"arm_a": 2.3, "lean": -4.0, "charge": 0.85, "bob": -1.0}))
    frames.append(draw_boss({"arm_a": 2.6, "lean": -5.0, "charge": 1.0, "bob": -2.0}))
    frames.append(draw_boss({"arm_a": -0.5, "lean": 6.0, "leg_f": 10.0}))            # strike
    frames.append(draw_boss({"arm_a": -0.9, "lean": 7.0, "leg_f": 12.0, "bob": 2.0}))
    frames.append(draw_boss({"arm_a": -0.4, "lean": 5.0}))
    frames.append(draw_boss({"flash": 1.0, "lean": -4.0}))                           # hurt
    frames.append(draw_boss({"flash": 0.4, "lean": -2.0}))
    frames.append(draw_boss({"lean": -6.0, "bob": 6.0, "eye": 0.5}))                 # death
    frames.append(draw_boss({"lean": -9.0, "bob": 12.0, "eye": 0.2}))
    frames.append(draw_boss({"lean": -12.0, "bob": 18.0, "eye": 0.1}))
    collapse = draw_boss({"lean": 0.0, "eye": 0.0, "bob": 20.0})
    collapse = collapse.rotate(-64, expand=True, resample=Image.BICUBIC)
    down = canvas(128, 128)
    down.alpha_composite(collapse, (int(6 * SS), int(40 * SS)))
    from oa_common import ell as _ell
    from PIL.ImageDraw import Draw as _D
    _ell(_D(down), 64.0, 120.0, 38.0, 6.0, (0, 0, 0, 90))
    frames.append(down)
    frames.append(down)
    return frames


def build_all_sheets() -> None:
    compose_sheet(hero_frames(), 64, SHEET_COLS, 4, "assets/sprites/hero/hero_sheet.png")
    compose_sheet(warden_frames(), 64, SHEET_COLS, 2, "assets/sprites/enemies/warden_sheet.png")
    compose_sheet(wraith_frames(), 64, SHEET_COLS, 2, "assets/sprites/enemies/wraith_sheet.png")
    compose_sheet(boss_frames(), 128, SHEET_COLS, 3, "assets/sprites/enemies/rift_warden_sheet.png")
