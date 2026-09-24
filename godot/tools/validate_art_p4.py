"""P4 delivery checks. Run with Python 3 and Pillow from any directory."""
import json
from pathlib import Path
from PIL import Image
from validate_art_p1 import connected_pixels

ROOT = Path(__file__).resolve().parents[1]
FAMILIES = ('well_pump', 'main_cistern', 'shelter', 'admin_post')


def main():
    definitions = json.loads((ROOT / 'content/base/buildings.json').read_text())
    errors = []
    checked = 0
    for family in FAMILIES:
        paths = [f'res://assets/buildings/tiers/{family}_t{i}.png' for i in range(1, 4)]
        definition = definitions[f'bld_{family}']
        if definition.get('sprites_by_level') != paths:
            errors.append(f'{family}: incorrect sprite mapping')
        if 'sprite_tint' in definition:
            errors.append(f'{family}: unexpected tint')
        tier_pixels = set()
        for resource in paths:
            name = Path(resource).name
            try:
                with Image.open(ROOT / resource.removeprefix('res://')) as sprite:
                    if sprite.format != 'PNG' or sprite.mode != 'RGBA' or sprite.size != (1024, 1024):
                        errors.append(f'{name}: expected 1024x1024 RGBA PNG')
                        continue
                    alpha = sprite.getchannel('A')
                    box = alpha.getbbox()
                    if box is None or not (0 < box[0] < box[2] < 1024 and 0 < box[1] < box[3] < 1024):
                        errors.append(f'{name}: empty or nontransparent canvas edge')
                    if box is None or not 870 <= box[3] < 1024:
                        errors.append(f'{name}: silhouette must end in bottom 15%')
                    reached, total = connected_pixels(alpha)
                    if not total or reached != total:
                        errors.append(f'{name}: disconnected alpha pixels ({total-reached})')
                    tier_pixels.add(sprite.tobytes())
                    checked += 1
                    print(f'{name}: bbox={box}, connected={reached}/{total}')
            except (OSError, ValueError) as error:
                errors.append(f'{name}: {error}')
        if len(tier_pixels) != 3:
            errors.append(f'{family}: expected three distinct tier images')
    for error in errors:
        print('FAIL:', error)
    print(f'P4 ART: {checked}/12 sprites checked, {len(errors)} errors')
    return int(bool(errors))


if __name__ == '__main__':
    raise SystemExit(main())
