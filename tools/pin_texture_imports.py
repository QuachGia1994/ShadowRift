"""One-off: pin Godot texture import settings for every production PNG.

Writes a standard Godot 4.7 texture .import next to each PNG with explicit
intentional settings for the Option A asset classes:
  - compress/mode=0 (lossless) — crisp stylized vector-raster art, no VRAM
    artifacts on gradients; total decoded budget is small (see memory report)
  - mipmaps/generate=false — nothing is minified (1:1 or magnified rendering)
  - linear filtering comes from the project default (default_texture_filter=1)
Godot fills in uid/remap paths on first import; params are the persisted intent.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TEMPLATE = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://{relative}"

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""

count = 0
for png in sorted(ROOT.glob("assets/**/*.png")):
    relative = png.relative_to(ROOT).as_posix()
    imp = png.with_suffix(".png.import")
    imp.write_text(TEMPLATE.format(relative=relative), encoding="utf-8", newline="\n")
    count += 1
print(f"wrote {count} .import files")
