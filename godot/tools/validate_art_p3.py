"""Validate the ten P3 prop PNGs; requires Pillow. Run from any directory."""
from pathlib import Path
from PIL import Image
from validate_art_p1 import connected_pixels

ROOT = Path(__file__).resolve().parents[1]
NAMES = ['pipe_straight', 'pipe_bend', 'pipe_broken', 'sign_company', 'debris',
         'dry_well', 'barrels', 'tarp_tent', 'leaflets', 'fence']


def main():
    errors = []
    checked = 0
    expected = {f'prop_{name}.png' for name in NAMES}
    actual = {path.name for path in (ROOT / 'assets/props').glob('*.png')}
    if actual != expected:
        errors.append(f'file set differs: {actual ^ expected}')
    for name in sorted(expected):
        try:
            with Image.open(ROOT / 'assets/props' / name) as im:
                if im.format != 'PNG' or im.mode != 'RGBA' or im.size != (512, 512):
                    errors.append(f'{name}: expected 512x512 RGBA PNG')
                    continue
                alpha = im.getchannel('A')
                bounds = alpha.getbbox()
                if bounds is None or not (0 < bounds[0] < bounds[2] < 512 and 0 < bounds[1] < bounds[3] < 512):
                    errors.append(f'{name}: empty sprite or nontransparent canvas edge')
                if bounds is None or not 435 <= bounds[3] <= 480:
                    errors.append(f'{name}: footprint must end near bottom 8%')
                reached, total = connected_pixels(alpha)
                if not total or reached != total:
                    errors.append(f'{name}: disconnected alpha pixels {total-reached}')
                print(f'{name}: bbox={bounds}, connected={reached}/{total}')
                checked += 1
        except (OSError, ValueError) as error:
            errors.append(f'{name}: {error}')
    for error in errors:
        print('FAIL:', error)
    print(f'P3 ART: {checked}/10 props checked, {len(errors)} errors')
    return int(bool(errors))


if __name__ == '__main__':
    raise SystemExit(main())
