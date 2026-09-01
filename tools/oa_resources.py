"""Emit Godot text resources (.tres) referencing the generated textures."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def emit_spriteframes(relative: str, sheet_relative: str, cell: int, anims) -> None:
    """anims: list of (name, fps, loop, [frame indices]); 8-column sheet grid."""
    total_frames = max(i for _, _, _, frames in anims for i in frames) + 1
    lines = [f'[gd_resource type="SpriteFrames" load_steps={2 + total_frames} format=3]', ""]
    lines.append(f'[ext_resource type="Texture2D" path="res://{sheet_relative}" id="1_sheet"]')
    lines.append("")
    for i in range(total_frames):
        col = i % 8
        row = i // 8
        lines.append(f'[sub_resource type="AtlasTexture" id="AtlasTexture_{i}"]')
        lines.append(f'atlas = ExtResource("1_sheet")')
        lines.append(f"region = Rect2({col * cell}, {row * cell}, {cell}, {cell})")
        lines.append("")
    entries = []
    for name, fps, loop, indices in anims:
        frames = ", ".join(f'{{"duration": 1.0, "texture": SubResource("AtlasTexture_{i}")}}' for i in indices)
        entries.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}'
                       % (frames, "true" if loop else "false", name, float(fps)))
    lines.append("[resource]")
    lines.append("animations = [%s]" % ", ".join(entries))
    lines.append("")
    path = ROOT / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(f"wrote {relative}")


def emit_tileset() -> None:
    lines = ['[gd_resource type="TileSet" load_steps=3 format=3]', ""]
    lines.append('[ext_resource type="Texture2D" path="res://assets/environment/rift_zone_tiles.png" id="1_tiles"]')
    lines.append("")
    lines.append('[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_rift"]')
    lines.append('texture = ExtResource("1_tiles")')
    lines.append("texture_region_size = Vector2i(32, 32)")
    for t in range(3):
        lines.append(f"{t}:0/0 = 0")
    lines.append("")
    lines.append("[resource]")
    lines.append("tile_size = Vector2i(32, 32)")
    lines.append('sources/0 = SubResource("TileSetAtlasSource_rift")')
    lines.append("")
    path = ROOT / "assets/environment/rift_zone_tileset.tres"
    path.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(f"wrote {path.relative_to(ROOT)}")


def build_all() -> None:
    emit_spriteframes(
        "assets/sprites/hero/hero_frames.tres", "assets/sprites/hero/hero_sheet.png", 64,
        [("idle", 6.0, True, [0, 1, 2, 3]),
         ("move", 12.0, True, [4, 5, 6, 7, 8, 9]),
         ("jump", 8.0, True, [10, 11]),
         ("attack1", 14.0, False, [12, 13, 14]),
         ("attack2", 14.0, False, [15, 16, 17]),
         ("skill_one", 11.0, False, [18, 19, 20]),
         ("skill_two", 9.0, False, [21, 22, 23]),
         ("hurt", 8.0, False, [24, 25]),
         ("death", 6.0, False, [26, 27, 28, 29])])
    emit_spriteframes(
        "assets/sprites/enemies/warden_frames.tres", "assets/sprites/enemies/warden_sheet.png", 64,
        [("patrol", 7.0, True, [0, 1, 2, 3]),
         ("aggro", 5.0, True, [4, 5]),
         ("attack", 9.0, False, [6, 7, 8]),
         ("hurt", 8.0, False, [9, 10]),
         ("death", 6.0, False, [11, 12, 13, 14])])
    emit_spriteframes(
        "assets/sprites/enemies/wraith_frames.tres", "assets/sprites/enemies/wraith_sheet.png", 64,
        [("hover", 6.0, True, [0, 1, 2, 3]),
         ("dash_attack", 12.0, False, [4, 5, 6]),
         ("hurt", 8.0, False, [7, 8]),
         ("death", 6.0, False, [9, 10, 11, 12])])
    emit_spriteframes(
        "assets/sprites/enemies/rift_warden_frames.tres", "assets/sprites/enemies/rift_warden_sheet.png", 128,
        [("watch", 5.0, True, [0, 1, 2, 3]),
         ("chase", 9.0, True, [4, 5, 6, 7]),
         ("windup", 6.5, False, [8, 9, 10]),
         ("strike", 8.0, False, [11, 12, 13]),
         ("hurt", 8.0, False, [14, 15]),
         ("death", 5.0, False, [16, 17, 18, 19, 20])])
    emit_tileset()
