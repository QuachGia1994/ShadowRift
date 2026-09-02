"""Compile Option A high-detail character masters into SpriteFrames sheets.

Reads committed files under art_source/option_a_masters (Godot-ignored).
Does not redraw character anatomy. Animation frames are the keyed masters
plus controlled transforms (translate, rotate, squash/stretch, bob, tint,
flash, alpha). Run via tools/generate_option_a_assets.py.
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "art_source" / "option_a_masters"
REPORT_DIR = ROOT / "build" / "reports"

HERO_CELL = 192
ENEMY_CELL = 192
BOSS_CELL = 256
COLS = 8
MAX_KEY_SOURCE = 896

# Filenames are historical labels; mapping is by inspected subject content.
SOURCE_FILES = {
    "hero_idle": "knight-combat.jpg",
    "hero_run": "dragon.jpg",
    "hero_jump": "keep-gate.jpg",
    "hero_slash": "courtyard-far.jpg",
    "hero_magic": "hud-ref.jpg",
    "wraith": "courtyard.jpg",
    "warden": "knight.jpg",
    "boss": "title.jpg",
}


def validate_sources() -> None:
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    ignore = "# High-resolution source masters. Do not import/export with Godot.\n"
    (ROOT / "art_source" / ".gdignore").write_text(
        "# High-resolution art masters and references are source-only; Godot must not import/export them.\n",
        encoding="utf-8",
    )
    (SOURCE_DIR / ".gdignore").write_text(ignore, encoding="utf-8")
    missing = [name for name in SOURCE_FILES.values() if not (SOURCE_DIR / name).is_file()]
    if missing:
        raise FileNotFoundError("missing Option A high-detail masters: " + ", ".join(missing))


def _border_background(rgb: np.ndarray) -> np.ndarray:
    rim = 6
    samples = np.concatenate(
        [
            rgb[:rim, :, :].reshape(-1, 3),
            rgb[-rim:, :, :].reshape(-1, 3),
            rgb[:, :rim, :].reshape(-1, 3),
            rgb[:, -rim:, :].reshape(-1, 3),
        ],
        axis=0,
    )
    return np.median(samples, axis=0)


def remove_backdrop(image: Image.Image) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.float32)
    rgb = rgba[..., :3]
    bg = _border_background(rgb)
    dist = np.linalg.norm(rgb - bg, axis=-1)
    red, green, blue = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    magenta_score = np.minimum(red, blue) - green
    alpha = np.clip((dist - 18.0) / 30.0, 0.0, 1.0) * 255.0
    magenta_bg = (magenta_score > 52.0) & (green < 80.0)
    alpha = np.where(magenta_bg & (dist < 80.0), np.minimum(alpha, np.clip((dist - 12.0) / 36.0, 0.0, 1.0) * 255.0), alpha)
    keep = (magenta_score < 14.0) & (dist > 40.0)
    alpha = np.where(keep, 255.0, alpha)
    alpha_img = Image.fromarray(alpha.astype(np.uint8), mode="L")
    eroded = np.asarray(alpha_img.filter(ImageFilter.MinFilter(3)), dtype=np.float32)
    halo = (magenta_score > 32.0) & (alpha < 250.0)
    alpha = np.where(halo, np.minimum(alpha, eroded), alpha)
    alpha_img = Image.fromarray(np.clip(alpha, 0, 255).astype(np.uint8), mode="L").filter(ImageFilter.GaussianBlur(0.6))
    alpha = np.asarray(alpha_img, dtype=np.float32)
    alpha = np.where(keep, 255.0, alpha)
    alpha = np.where(dist < 18.0, 0.0, alpha)
    alpha = np.where(alpha < 28.0, 0.0, alpha)
    a = np.clip(alpha / 255.0, 0.0, 1.0)[..., None]
    a_safe = np.maximum(a, 1e-3)
    cleaned = np.clip((rgb - (1.0 - a) * bg) / a_safe, 0.0, 255.0)
    spill = np.maximum(0.0, np.minimum(cleaned[..., 0], cleaned[..., 2]) - cleaned[..., 1])
    fringe = (a[..., 0] > 0.02) & (a[..., 0] < 0.97)
    near_bg = dist < 64.0
    despill = fringe | ((near_bg) & (spill > 18.0))
    cleaned[..., 0] = np.where(despill, np.clip(cleaned[..., 0] - spill * 0.92, 0, 255), cleaned[..., 0])
    cleaned[..., 2] = np.where(despill, np.clip(cleaned[..., 2] - spill * 0.78, 0, 255), cleaned[..., 2])
    out = np.concatenate([cleaned, alpha[..., None]], axis=-1)
    image_out = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), mode="RGBA")
    core = Image.fromarray((alpha >= 110).astype(np.uint8) * 255, mode="L")
    bbox = core.getbbox() or image_out.getbbox()
    if bbox is None:
        raise RuntimeError("backdrop key produced an empty image")
    pad = 36
    left = max(0, bbox[0] - pad)
    top = max(0, bbox[1] - pad)
    right = min(image_out.width, bbox[2] + pad)
    bottom = min(image_out.height, bbox[3] + pad)
    return image_out.crop((left, top, right, bottom))


_MASTER_CACHE: dict[str, Image.Image] = {}


def load_master(name: str) -> Image.Image:
    cached = _MASTER_CACHE.get(name)
    if cached is not None:
        return cached
    path = SOURCE_DIR / SOURCE_FILES[name]
    print(f"key {path.name} -> {name}")
    with Image.open(path) as source:
        source = source.convert("RGB")
        source.thumbnail((MAX_KEY_SOURCE, MAX_KEY_SOURCE), Image.Resampling.LANCZOS)
        master = remove_backdrop(source)
    master = ImageEnhance.Contrast(master).enhance(1.05)
    master = ImageEnhance.Sharpness(master).enhance(1.06)
    _MASTER_CACHE[name] = master
    return master


def release_master(name: str) -> None:
    master = _MASTER_CACHE.pop(name, None)
    if master is not None:
        master.close()


def tint(image: Image.Image, color: tuple[int, int, int], strength: float) -> Image.Image:
    base = image.copy()
    overlay = Image.new("RGBA", base.size, (*color, 0))
    alpha = base.getchannel("A").point(lambda v, s=strength: int(v * max(0.0, min(1.0, s))))
    overlay.putalpha(alpha)
    return Image.alpha_composite(base, overlay)


def frame(
    master: Image.Image,
    cell: int,
    *,
    height_ratio: float = 0.88,
    dx: float = 0.0,
    dy: float = 0.0,
    rotate: float = 0.0,
    scale_x: float = 1.0,
    scale_y: float = 1.0,
    alpha: float = 1.0,
    brightness: float = 1.0,
    tint_color: tuple[int, int, int] | None = None,
    tint_strength: float = 0.0,
) -> Image.Image:
    src = master.copy()
    if brightness != 1.0:
        src = ImageEnhance.Brightness(src).enhance(brightness)
    target_h = max(1, int(cell * height_ratio * scale_y))
    fit = target_h / max(1, src.height)
    src = src.resize((max(1, int(src.width * fit * scale_x)), max(1, int(src.height * fit))), Image.Resampling.LANCZOS)
    if rotate:
        src = src.rotate(rotate, resample=Image.Resampling.BICUBIC, expand=True)
        if src.height > cell or src.width > int(cell * 1.08):
            fit2 = min(cell / max(1, src.height), (cell * 1.04) / max(1, src.width))
            src = src.resize((max(1, int(src.width * fit2)), max(1, int(src.height * fit2))), Image.Resampling.BICUBIC)
    if tint_color is not None and tint_strength > 0.0:
        src = tint(src, tint_color, tint_strength)
    if alpha < 1.0:
        src.putalpha(src.getchannel("A").point(lambda v, a=alpha: int(v * a)))
    canvas = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
    x = int((cell - src.width) * 0.5 + dx * cell)
    y = int(cell - max(4, int(cell * 0.04)) - src.height + dy * cell)
    canvas.alpha_composite(src, (x, y))
    return canvas


def compose(frames: list[Image.Image], cell: int, rows: int, path: Path) -> None:
    sheet = Image.new("RGBA", (COLS * cell, rows * cell), (0, 0, 0, 0))
    for index, item in enumerate(frames):
        sheet.alpha_composite(item, ((index % COLS) * cell, (index // COLS) * cell))
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)
    print(f"wrote {path.relative_to(ROOT)} {sheet.size[0]}x{sheet.size[1]}")


def hero_frames() -> list[Image.Image]:
    idle = load_master("hero_idle")
    run = load_master("hero_run")
    jump = load_master("hero_jump")
    slash = load_master("hero_slash")
    magic = load_master("hero_magic")
    f: list[Image.Image] = []
    for dy, sy, bright in [(0.0, 1.0, 1.0), (-0.006, 1.01, 1.03), (-0.012, 1.018, 1.06), (-0.006, 1.01, 1.03)]:
        f.append(frame(idle, HERO_CELL, dy=dy, scale_y=sy, brightness=bright))
    for i, (dy, rot) in enumerate([(0.0, -1.2), (-0.016, -0.4), (-0.028, 0.7), (-0.01, 1.1), (-0.024, 0.2), (-0.006, -0.8)]):
        f.append(frame(run, HERO_CELL, dy=dy, rotate=rot, dx=0.01 * (i % 2)))
    f.append(frame(jump, HERO_CELL, dy=-0.04, rotate=-1.8))
    f.append(frame(jump, HERO_CELL, dy=-0.01, rotate=1.6, scale_y=0.98))
    f.extend([
        frame(idle, HERO_CELL, rotate=-2.0, dx=-0.012),
        frame(slash, HERO_CELL, dx=0.018, rotate=-0.8),
        frame(slash, HERO_CELL, dx=0.008, rotate=1.6),
    ])
    f.extend([
        frame(jump, HERO_CELL, rotate=6.0, dx=-0.008),
        frame(slash, HERO_CELL, rotate=-6.0, dx=0.016),
        frame(idle, HERO_CELL, rotate=1.6),
    ])
    f.extend([
        frame(idle, HERO_CELL, tint_color=(60, 190, 230), tint_strength=0.10, brightness=1.05),
        frame(slash, HERO_CELL, tint_color=(70, 210, 240), tint_strength=0.10, brightness=1.08),
        frame(slash, HERO_CELL, rotate=2.0, tint_color=(70, 180, 230), tint_strength=0.07),
    ])
    f.extend([
        frame(magic, HERO_CELL, tint_color=(120, 70, 220), tint_strength=0.08, brightness=1.04),
        frame(magic, HERO_CELL, dx=0.012, tint_color=(150, 80, 230), tint_strength=0.10, brightness=1.08),
        frame(magic, HERO_CELL, dx=0.008, alpha=0.96),
    ])
    f.extend([
        frame(idle, HERO_CELL, dx=-0.03, rotate=-3.5, tint_color=(190, 35, 55), tint_strength=0.18),
        frame(idle, HERO_CELL, dx=-0.016, rotate=-1.8, tint_color=(150, 25, 50), tint_strength=0.10),
    ])
    f.extend([
        frame(idle, HERO_CELL, dx=-0.035, rotate=-10.0, alpha=0.95),
        frame(idle, HERO_CELL, dx=-0.045, dy=0.03, rotate=-28.0, alpha=0.78),
        frame(idle, HERO_CELL, dx=-0.05, dy=0.07, rotate=-52.0, alpha=0.52),
        frame(idle, HERO_CELL, dx=-0.06, dy=0.11, rotate=-68.0, alpha=0.24),
    ])
    if len(f) != 30:
        raise RuntimeError(f"hero frame contract is 30, got {len(f)}")
    return f


def warden_frames() -> list[Image.Image]:
    m = load_master("warden")
    f = [frame(m, ENEMY_CELL, dy=v, rotate=r) for v, r in [(0.0, 0.0), (-0.008, -0.8), (-0.014, 0.0), (-0.006, 0.8)]]
    f += [frame(m, ENEMY_CELL, dx=0.01, brightness=1.05), frame(m, ENEMY_CELL, dx=0.016, rotate=1.2, brightness=1.08)]
    f += [
        frame(m, ENEMY_CELL, rotate=-5.0, dx=-0.01),
        frame(m, ENEMY_CELL, rotate=4.5, dx=0.028),
        frame(m, ENEMY_CELL, rotate=1.6),
    ]
    f += [
        frame(m, ENEMY_CELL, dx=-0.028, rotate=-4.0, tint_color=(210, 35, 45), tint_strength=0.18),
        frame(m, ENEMY_CELL, dx=-0.012, tint_color=(170, 25, 40), tint_strength=0.10),
    ]
    f += [
        frame(m, ENEMY_CELL, rotate=-12.0, alpha=0.95),
        frame(m, ENEMY_CELL, rotate=-32.0, dy=0.03, alpha=0.72),
        frame(m, ENEMY_CELL, rotate=-54.0, dy=0.07, alpha=0.44),
        frame(m, ENEMY_CELL, rotate=-70.0, dy=0.11, alpha=0.18),
    ]
    if len(f) != 15:
        raise RuntimeError(f"warden frame contract is 15, got {len(f)}")
    return f


def wraith_frames() -> list[Image.Image]:
    m = load_master("wraith")
    f = [frame(m, ENEMY_CELL, dy=v, scale_y=s, brightness=b) for v, s, b in [
        (0.0, 1.0, 1.0), (-0.014, 1.02, 1.04), (-0.024, 1.04, 1.08), (-0.01, 1.02, 1.03),
    ]]
    f += [
        frame(m, ENEMY_CELL, dx=0.02, scale_x=1.06),
        frame(m, ENEMY_CELL, dx=0.045, scale_x=1.14),
        frame(m, ENEMY_CELL, dx=0.022, scale_x=1.06),
    ]
    f += [
        frame(m, ENEMY_CELL, dx=-0.028, tint_color=(200, 40, 80), tint_strength=0.16),
        frame(m, ENEMY_CELL, dx=-0.012, tint_color=(150, 30, 70), tint_strength=0.08),
    ]
    f += [
        frame(m, ENEMY_CELL, alpha=0.76, dy=0.02),
        frame(m, ENEMY_CELL, alpha=0.52, dy=0.04),
        frame(m, ENEMY_CELL, alpha=0.28, dy=0.07),
        frame(m, ENEMY_CELL, alpha=0.08, dy=0.10),
    ]
    if len(f) != 13:
        raise RuntimeError(f"wraith frame contract is 13, got {len(f)}")
    return f


def boss_frames() -> list[Image.Image]:
    m = load_master("boss")
    f = [frame(m, BOSS_CELL, dy=v, scale_y=s, brightness=b) for v, s, b in [
        (0.0, 1.0, 1.0), (-0.006, 1.008, 1.03), (-0.012, 1.014, 1.07), (-0.006, 1.008, 1.03),
    ]]
    f += [frame(m, BOSS_CELL, dx=0.01, rotate=r) for r in (-1.4, 0.0, 1.4, 0.0)]
    f += [
        frame(m, BOSS_CELL, rotate=-3.5, tint_color=(180, 35, 60), tint_strength=0.08, brightness=1.04),
        frame(m, BOSS_CELL, rotate=-6.0, tint_color=(210, 30, 70), tint_strength=0.12, brightness=1.08),
        frame(m, BOSS_CELL, rotate=-8.0, tint_color=(230, 35, 80), tint_strength=0.16, brightness=1.12),
    ]
    f += [
        frame(m, BOSS_CELL, dx=0.028, rotate=4.0),
        frame(m, BOSS_CELL, dx=0.045, rotate=7.0),
        frame(m, BOSS_CELL, dx=0.028, rotate=2.5),
    ]
    f += [
        frame(m, BOSS_CELL, dx=-0.022, rotate=-3.5, tint_color=(220, 35, 55), tint_strength=0.18),
        frame(m, BOSS_CELL, dx=-0.01, rotate=-1.6, tint_color=(170, 25, 50), tint_strength=0.10),
    ]
    f += [
        frame(m, BOSS_CELL, rotate=-8.0, alpha=0.95),
        frame(m, BOSS_CELL, rotate=-22.0, dy=0.02, alpha=0.80),
        frame(m, BOSS_CELL, rotate=-40.0, dy=0.05, alpha=0.58),
        frame(m, BOSS_CELL, rotate=-56.0, dy=0.08, alpha=0.36),
        frame(m, BOSS_CELL, rotate=-68.0, dy=0.12, alpha=0.16),
    ]
    if len(f) != 21:
        raise RuntimeError(f"boss frame contract is 21, got {len(f)}")
    return f


def _checker(size: tuple[int, int]) -> Image.Image:
    width, height = size
    y, x = np.indices((height, width))
    tone = np.where(((x // 10) + (y // 10)) % 2 == 0, 46, 78).astype(np.uint8)
    arr = np.stack([tone, tone, np.minimum(tone + 8, 255), np.full_like(tone, 255)], axis=-1)
    return Image.fromarray(arr, mode="RGBA")


def write_contact_sheet(frames: list[Image.Image], cell: int, path: Path, columns: int = 8) -> None:
    rows = (len(frames) + columns - 1) // columns
    gap = 4
    sheet = _checker((columns * (cell + gap) + gap, rows * (cell + gap) + gap))
    for index, item in enumerate(frames):
        col = index % columns
        row = index // columns
        x = gap + col * (cell + gap)
        y = gap + row * (cell + gap)
        sheet.alpha_composite(Image.alpha_composite(_checker((cell, cell)), item), (x, y))
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)
    print(f"wrote {path.relative_to(ROOT)} {sheet.size[0]}x{sheet.size[1]}")


def _magenta_opaque_fraction(image: Image.Image) -> float:
    arr = np.asarray(image.convert("RGBA"), dtype=np.float32)
    rgb, a = arr[..., :3], arr[..., 3]
    opaque = a > 80.0
    if not np.any(opaque):
        return 0.0
    red, green, blue = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    backdrop = np.array([242.0, 8.0, 184.0])
    dist = np.linalg.norm(rgb - backdrop, axis=-1)
    leftover = opaque & (dist < 48.0) & (green < 70.0)
    return float(leftover.sum() / opaque.sum())


def write_qa_reports(hero: list[Image.Image], warden: list[Image.Image], wraith: list[Image.Image], boss: list[Image.Image]) -> None:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    write_contact_sheet(hero, HERO_CELL, REPORT_DIR / "qa_hero_contact.png")
    write_contact_sheet(warden + wraith, ENEMY_CELL, REPORT_DIR / "qa_warden_wraith_contact.png")
    write_contact_sheet(boss, BOSS_CELL, REPORT_DIR / "qa_boss_contact.png")
    keyed = [frame(load_master(name), 256) for name in ("hero_idle", "hero_run", "hero_jump", "hero_slash", "hero_magic", "warden", "wraith", "boss")]
    write_contact_sheet(keyed, 256, REPORT_DIR / "qa_masters_keyed.png", columns=4)
    lines = ["Option A high-detail character QA", ""]
    for label, frames in (("hero", hero), ("warden", warden), ("wraith", wraith), ("boss", boss)):
        worst = max(_magenta_opaque_fraction(item) for item in frames)
        lines.append(f"{label}: frames={len(frames)} worst_magenta_opaque_fraction={worst:.4f}")
        if worst > 0.04:
            lines.append(f"  WARN magenta spill above 4% in {label}")
    (REPORT_DIR / "qa_character_alpha.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"wrote { (REPORT_DIR / 'qa_character_alpha.txt').relative_to(ROOT) }")


def build_all_sheets() -> None:
    validate_sources()
    hero = hero_frames()
    warden = warden_frames()
    wraith = wraith_frames()
    boss = boss_frames()
    compose(hero, HERO_CELL, 4, ROOT / "assets/sprites/hero/hero_sheet.png")
    compose(warden, ENEMY_CELL, 2, ROOT / "assets/sprites/enemies/warden_sheet.png")
    compose(wraith, ENEMY_CELL, 2, ROOT / "assets/sprites/enemies/wraith_sheet.png")
    compose(boss, BOSS_CELL, 3, ROOT / "assets/sprites/enemies/rift_warden_sheet.png")
    write_qa_reports(hero, warden, wraith, boss)


def main() -> None:
    build_all_sheets()


if __name__ == "__main__":
    main()
