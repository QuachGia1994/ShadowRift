"""Check 16 KB native page-size compatibility of native libraries inside an APK.

Parses the APK as a zip, inspects every lib/*//*.so ELF header and verifies that
every PT_LOAD segment is aligned to at least 16 KiB (p_align >= 16384), which is
what Android 15+ 16 KB page-size devices require.

Pure Python (zipfile + struct) so it runs anywhere the APK was built, including
CI hosts without the Android NDK. Evidence-based: prints per-library results and
a final verdict; exits non-zero only when native libraries exist and at least
one fails, so an APK without native libraries is reported NOT APPLICABLE.

Run:  python tools/check_elf_alignment.py <path-to-apk>
"""
from __future__ import annotations

import struct
import sys
import zipfile
from pathlib import Path

PT_LOAD = 1
PAGE_16K = 16384


def load_segments(data: bytes) -> list[tuple[int, int]]:
    """Return (p_type, p_align) for every program header entry."""
    if data[:4] != b"\x7fELF":
        raise ValueError("not an ELF file")
    is64 = data[4] == 2
    little = data[5] == 1
    endian = "<" if little else ">"
    if is64:
        e_phoff = struct.unpack_from(endian + "Q", data, 0x20)[0]
        e_phentsize = struct.unpack_from(endian + "H", data, 0x36)[0]
        e_phnum = struct.unpack_from(endian + "H", data, 0x38)[0]
    else:
        e_phoff = struct.unpack_from(endian + "I", data, 0x1C)[0]
        e_phentsize = struct.unpack_from(endian + "H", data, 0x2A)[0]
        e_phnum = struct.unpack_from(endian + "H", data, 0x2C)[0]
    segments = []
    for index in range(e_phnum):
        offset = e_phoff + index * e_phentsize
        if is64:
            p_type = struct.unpack_from(endian + "I", data, offset)[0]
            p_align = struct.unpack_from(endian + "Q", data, offset + 0x30)[0]
        else:
            p_type = struct.unpack_from(endian + "I", data, offset)[0]
            p_align = struct.unpack_from(endian + "I", data, offset + 0x1C)[0]
        segments.append((p_type, p_align))
    return segments


def check_apk(apk_path: Path) -> tuple[int, int, list[str]]:
    lines = []
    checked = failed = 0
    with zipfile.ZipFile(apk_path) as archive:
        libraries = sorted(name for name in archive.namelist() if name.startswith("lib/") and name.endswith(".so"))
        for name in libraries:
            data = archive.read(name)
            try:
                segments = load_segments(data)
            except ValueError:
                lines.append(f"  [SKIP] {name}: not an ELF object")
                continue
            load_aligns = [align for p_type, align in segments if p_type == PT_LOAD]
            if not load_aligns:
                lines.append(f"  [SKIP] {name}: no PT_LOAD segments")
                continue
            checked += 1
            worst = min(load_aligns)
            if worst >= PAGE_16K:
                lines.append(f"  [PASS] {name}: max load alignment {max(load_aligns)}, min {worst} (>= 16 KiB)")
            else:
                failed += 1
                lines.append(f"  [FAIL] {name}: min load alignment {worst} (< 16 KiB)")
    return checked, failed, lines


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: python tools/check_elf_alignment.py <apk>", file=sys.stderr)
        return 2
    apk_path = Path(sys.argv[1])
    if not apk_path.is_file():
        print(f"APK not found: {apk_path}", file=sys.stderr)
        return 2
    print(f"16 KB page-size compatibility check: {apk_path.name}")
    checked, failed, lines = check_apk(apk_path)
    for line in lines:
        print(line)
    if checked == 0:
        print("VERDICT: NOT APPLICABLE (no native libraries found in APK)")
        return 0
    if failed > 0:
        print(f"VERDICT: FAIL ({failed}/{checked} native libraries not 16 KiB aligned)")
        return 1
    print(f"VERDICT: PASS ({checked}/{checked} native libraries 16 KiB aligned)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
