"""Validate P2 terrain files against the actual flat-top grid. Requires Pillow."""

import json
import math
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
NAMES = ["dust", "dry_bed", "salt_flat", "clay_hill", "scrub", "rock"]


def main():
    definitions = json.loads((ROOT / "content/base/terrain.json").read_text())["types"]
    errors = []
    checked = 0
    common_alpha = None
    # Normalized coordinates reproduce cos/sin vertices from HexCoords, with
    # HEX_SIZE=32 and ISO_Y=.75, inside the 256x192 canvas (4x game size).
    interior, exterior = [], []
    for y in range(192):
        for x in range(256):
            nx, ny = abs((x + 0.5 - 128) / 128), abs((y + 0.5 - 96) / 96)
            boundary = max(ny / (math.sqrt(3) / 2), nx + ny / math.sqrt(3))
            if boundary < 0.98:
                interior.append((x, y))
            elif boundary > 1.02:
                exterior.append((x, y))
    for terrain_id, name in enumerate(NAMES):
        definition = definitions[str(terrain_id)]
        pair = []
        for field, suffix in [("tile", ""), ("tile_dust", "_dust")]:
            resource = f"res://assets/tiles/tile_{name}{suffix}.png"
            if definition.get(field) != resource:
                errors.append(f"terrain {terrain_id}: wrong {field} mapping")
            try:
                with Image.open(ROOT / resource.removeprefix("res://")) as tile:
                    if tile.format != "PNG" or tile.mode != "RGBA" or tile.size != (256, 192):
                        errors.append(f"{resource}: expected 256x192 RGBA PNG")
                        continue
                    alpha = tile.getchannel("A")
                    if any(alpha.getpixel(p) < 250 for p in interior):
                        errors.append(f"{resource}: transparent holes inside hex")
                    if any(alpha.getpixel(p) != 0 for p in exterior):
                        errors.append(f"{resource}: opaque pixels outside hex")
                    bbox = alpha.getbbox()
                    if not bbox or bbox[0] != 0 or bbox[2] != 256:
                        errors.append(f"{resource}: hex does not span canvas width")
                    raw_alpha = alpha.tobytes()
                    if common_alpha is None:
                        common_alpha = raw_alpha
                    elif raw_alpha != common_alpha:
                        errors.append(f"{resource}: mismatched hex footprint")
                    pair.append(tile.convert("RGB").tobytes())
                    checked += 1
                    print(f"{resource}: bbox={bbox}")
            except (OSError, ValueError) as error:
                errors.append(f"{resource}: {error}")
        if len(pair) == 2 and pair[0] == pair[1]:
            errors.append(f"{name}: dust variant duplicates normal texture")
    for error in errors:
        print("FAIL:", error)
    print(f"P2 ART: {checked}/12 tiles checked, {len(errors)} errors")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
