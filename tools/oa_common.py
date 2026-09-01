"""Shared palette and drawing primitives for the OPTION A asset generator.

Stylized 2D hand-drawn / vector dark fantasy. Deterministic (fixed seed).
All painting happens at 4x supersampling; save() downscales with Lanczos.
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
SS = 4  # supersample factor
RNG = random.Random(20260901)

# ---------------------------------------------------------------- palette --
INK = (7, 11, 20, 255)            # near-black navy outline
CHARCOAL = (24, 33, 52, 255)      # hero armor base
CHARCOAL_HI = (44, 58, 86, 255)
NAVY_DEEP = (11, 18, 32, 255)
CRIMSON = (140, 22, 38, 255)
CRIMSON_HI = (196, 44, 60, 255)
CRIMSON_DEEP = (86, 12, 24, 255)
GOLD = (201, 162, 75, 255)
GOLD_HI = (238, 208, 132, 255)
GOLD_DEEP = (122, 94, 42, 255)
SILVER = (182, 194, 208, 255)
SILVER_HI = (238, 244, 250, 255)
CYAN = (64, 196, 216, 255)
CYAN_HI = (150, 236, 246, 255)
VIOLET = (124, 62, 196, 255)
VIOLET_HI = (176, 118, 236, 255)
BONE = (214, 202, 178, 255)
OBSIDIAN = (28, 26, 38, 255)
OBSIDIAN_HI = (58, 52, 74, 255)


def canvas(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))


def save(img: Image.Image, w: int, h: int, relative: str) -> None:
    path = ROOT / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    img.resize((w, h), Image.LANCZOS).save(path)
    print(f"wrote {relative} ({w}x{h})")


def s(v: float) -> float:
    return v * SS


def poly(draw: ImageDraw.ImageDraw, points, fill) -> None:
    draw.polygon([(s(x), s(y)) for x, y in points], fill=fill)


def poly_outline(draw: ImageDraw.ImageDraw, points, color, width=1.2) -> None:
    pts = [(s(x), s(y)) for x, y in points]
    pts.append(pts[0])
    draw.line(pts, fill=color, width=max(1, int(round(s(width)))), joint="curve")


def ell(draw: ImageDraw.ImageDraw, cx, cy, rx, ry, fill) -> None:
    draw.ellipse([s(cx - rx), s(cy - ry), s(cx + rx), s(cy + ry)], fill=fill)


def ell_outline(draw: ImageDraw.ImageDraw, cx, cy, rx, ry, color, width=1.2) -> None:
    draw.ellipse([s(cx - rx), s(cy - ry), s(cx + rx), s(cy + ry)], outline=color,
                 width=max(1, int(round(s(width)))))


def line(draw: ImageDraw.ImageDraw, x0, y0, x1, y1, color, width) -> None:
    draw.line([s(x0), s(y0), s(x1), s(y1)], fill=color, width=max(1, int(round(s(width)))))


def glow_layer(base: Image.Image, painter, radius: float, alpha: float = 1.0) -> None:
    """Paint onto a temp layer, blur it, then composite onto base as soft glow."""
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    painter(ImageDraw.Draw(layer))
    if alpha < 1.0:
        a = layer.getchannel("A").point(lambda v: int(v * alpha))
        layer.putalpha(a)
    layer = layer.filter(ImageFilter.GaussianBlur(s(radius)))
    base.alpha_composite(layer)


def vgrad(size, top, bottom) -> Image.Image:
    w, h = size
    grad = Image.new("RGBA", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        grad.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(4)))
    return grad.resize((w, h))


def fill_poly_grad(base: Image.Image, points, top, bottom) -> None:
    mask = Image.new("L", base.size, 0)
    ImageDraw.Draw(mask).polygon([(s(x), s(y)) for x, y in points], fill=255)
    grad = vgrad(base.size, top, bottom)
    base.paste(grad, (0, 0), mask)


def tint_flash(img: Image.Image, box, flash: float) -> None:
    """Red hurt-flash clipped to the sprite alpha (kept subtle so art still reads)."""
    if flash <= 0.0:
        return
    x0, y0, x1, y1 = box
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(overlay).rectangle([s(x0), s(y0), s(x1), s(y1)], fill=(255, 70, 78, int(70 * flash)))
    img.paste(overlay, (0, 0), img.getchannel("A"))


def apply_alpha(img: Image.Image, alpha: float) -> None:
    if alpha < 1.0:
        img.putalpha(img.getchannel("A").point(lambda v: int(v * alpha)))


def crescent(draw: ImageDraw.ImageDraw, cx, cy, radius, a0, a1, color, width, taper=True) -> None:
    """Tapered arc slash painted as a filled wedge between two arcs."""
    steps = 48
    outer, inner = [], []
    for i in range(steps + 1):
        t = i / steps
        a = a0 + (a1 - a0) * t
        w = width * (math.sin(t * math.pi) ** 0.7 if taper else 1.0)
        outer.append((cx + math.cos(a) * (radius + w * 0.5), cy + math.sin(a) * (radius + w * 0.5)))
        inner.append((cx + math.cos(a) * (radius - w * 0.5), cy + math.sin(a) * (radius - w * 0.5)))
    poly(draw, outer + inner[::-1], color)


def compose_sheet(frames, cell: int, cols: int, rows: int, relative: str) -> None:
    sheet = Image.new("RGBA", (cols * cell * SS, rows * cell * SS), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.alpha_composite(fr, ((i % cols) * cell * SS, (i // cols) * cell * SS))
    save(sheet, cols * cell, rows * cell, relative)
