"""Validate P1 sprite delivery. Run with Python 3 and Pillow from any directory."""

import json
from collections import deque
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
EXPECTED = {
    "bld_solar_panel": ["solar_panel_t1"],
    "bld_tool_workshop": [f"tool_workshop_t{i}" for i in range(1, 4)],
    "bld_lumber_yard": [f"lumber_yard_t{i}" for i in range(1, 4)],
    "bld_quarry_pit": [f"quarry_pit_t{i}" for i in range(1, 4)],
    "bld_source_tower": ["source_tower_old_t1"],
    "bld_source_tower_restored": ["source_tower_restored_t1"],
    "bld_company_ruin": ["company_ruin_t1"],
    "bld_company_office": ["company_office_t1"],
}


def connected_pixels(alpha):
    """Count the first 8-connected alpha component, including antialiased pixels."""
    width, height = alpha.size
    mask = bytearray(1 if value else 0 for value in alpha.tobytes())
    total = sum(mask)
    if not total:
        return 0, 0
    start = mask.index(1)
    mask[start] = 0
    queue = deque([start])
    reached = 0
    while queue:
        index = queue.popleft()
        reached += 1
        x, y = index % width, index // width
        for ny in range(max(0, y - 1), min(height, y + 2)):
            for nx in range(max(0, x - 1), min(width, x + 2)):
                neighbor = ny * width + nx
                if mask[neighbor]:
                    mask[neighbor] = 0
                    queue.append(neighbor)
    return reached, total


def main():
    buildings = json.loads((ROOT / "content/base/buildings.json").read_text())
    errors = []
    checked = 0
    for building, names in EXPECTED.items():
        paths = [f"res://assets/buildings/tiers/{name}.png" for name in names]
        definition = buildings[building]
        if definition.get("sprites_by_level") != paths:
            errors.append(f"{building}: incorrect sprite mapping")
        if "sprite_tint" in definition:
            errors.append(f"{building}: obsolete tint")
        for name, resource in zip(names, paths):
            path = ROOT / resource.removeprefix("res://")
            try:
                with Image.open(path) as sprite:
                    if sprite.format != "PNG" or sprite.mode != "RGBA" or sprite.size != (1024, 1024):
                        errors.append(f"{name}: expected 1024x1024 RGBA PNG")
                        continue
                    alpha = sprite.getchannel("A")
                    edges = [(0, 0, 1024, 1), (0, 1023, 1024, 1024),
                             (0, 0, 1, 1024), (1023, 0, 1024, 1024)]
                    if any(alpha.crop(edge).getbbox() for edge in edges):
                        errors.append(f"{name}: nontransparent canvas edge")
                    bbox = alpha.getbbox()
                    if bbox is None or not 0.85 * 1024 <= bbox[3] < 1024:
                        errors.append(f"{name}: silhouette must end in bottom 15%")
                    reached, total = connected_pixels(alpha)
                    if not total or reached != total:
                        errors.append(f"{name}: disconnected alpha pixels ({total - reached})")
                    print(f"{name}: bbox={bbox}, connected={reached}/{total}")
                    checked += 1
            except (OSError, ValueError) as error:
                errors.append(f"{name}: {error}")
    for error in errors:
        print("FAIL:", error)
    print(f"P1 ART: {checked}/14 sprites checked, {len(errors)} errors")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
