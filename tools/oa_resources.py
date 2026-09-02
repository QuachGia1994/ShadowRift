"""Emit deterministic Godot text resources for generated environment art."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def emit_tileset() -> None:
    lines = ['[gd_resource type="TileSet" load_steps=3 format=3]', ""]
    lines.append('[ext_resource type="Texture2D" path="res://assets/environment/rift_zone_tiles.png" id="1_tiles"]')
    lines.append("")
    lines.append('[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_rift"]')
    lines.append('texture = ExtResource("1_tiles")')
    lines.append("texture_region_size = Vector2i(32, 32)")
    for tile_index in range(3):
        lines.append(f"{tile_index}:0/0 = 0")
    lines.append("")
    lines.append("[resource]")
    lines.append("tile_size = Vector2i(32, 32)")
    lines.append('sources/0 = SubResource("TileSetAtlasSource_rift")')
    lines.append("")
    path = ROOT / "assets/environment/rift_zone_tileset.tres"
    path.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(f"wrote {path.relative_to(ROOT)}")


def build_all() -> None:
    emit_tileset()


def main() -> int:
    build_all()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
