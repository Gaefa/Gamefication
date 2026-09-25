"""P5 delivery checks. Python 3 + Pillow; run from any directory."""
from itertools import combinations
from pathlib import Path
from xml.etree import ElementTree as ET
from PIL import Image, ImageChops, ImageColor

ROOT = Path(__file__).resolve().parents[1] / 'assets/ui/pins'
COLORS = dict(repair='#e63535', issue='#e6a02b', road='#e63535', power='#e6a02b',
              water='#e63535', stock='#2f7fe6', pressure='#7fb8ff', event='#f4f1ea')


def main():
    errors, silhouettes, badges = [], {}, []
    for label, color in COLORS.items():
        try:
            with Image.open(ROOT / f'pin_{label}.png') as pin:
                assert pin.format == 'PNG' and pin.mode == 'RGBA' and pin.size == (128, 128), '128px RGBA PNG required'
                alpha = pin.getchannel('A')
                assert alpha.getextrema() == (0, 255), 'transparent background and opaque badge required'
                assert alpha.getbbox()[3] == 128, 'tail must reach bottom edge'
                assert alpha.getpixel((0, 0)) == alpha.getpixel((127, 127)) == 0, 'corners must be transparent'
                assert pin.getpixel((64, 10)) == (*ImageColor.getrgb(color), 255), 'incorrect flat semantic fill'
                badges.append(alpha)
                # Compare glyph silhouettes independently of semantic color at delivery size.
                foreground = (43, 38, 34) if label == 'event' else (255, 255, 255)
                mask = Image.new('L', pin.size)
                pixels = pin.load()
                mask.putdata([255 if pixels[x, y] == (*foreground, 255) else 0
                              for y in range(128) for x in range(128)])
                # Exclude the outer outline for the dark event glyph.
                clipped = Image.new('L', pin.size)
                clipped.paste(mask.crop((20, 16, 108, 102)), (20, 16))
                silhouettes[label] = clipped.resize((20, 20), Image.Resampling.LANCZOS)
            svg = ET.parse(ROOT / f'src/pin_{label}.svg').getroot()
            assert svg.get('viewBox') == '0 0 128 128', 'SVG viewBox mismatch'
            elements = list(svg.iter())
            assert not any(e.tag.split('}')[-1] in ('image', 'text', 'linearGradient', 'radialGradient', 'filter') for e in elements), 'SVG must contain flat vectors, no raster/text/effects'
            paths = svg.findall('{http://www.w3.org/2000/svg}path')
            assert len(paths) == 2 and all(p.get('d') for p in paths), 'badge and glyph vector paths required'
            assert paths[0].get('fill') == color and paths[0].get('stroke-width') == '2', 'SVG palette/outline mismatch'
            print(f'PASS: {label}: PNG, alpha, palette, vector source')
        except (OSError, AssertionError, ET.ParseError) as error:
            errors.append(f'{label}: {error}')
    if len(badges) == 8 and any(ImageChops.difference(badges[0], a).getbbox() for a in badges[1:]):
        errors.append('badge silhouette differs between pins')
    for (a, ma), (b, mb) in combinations(silhouettes.items(), 2):
        difference = sum(value * count for value, count in
                         enumerate(ImageChops.difference(ma, mb).histogram())) / 255
        if difference < 8:
            errors.append(f'{a}/{b}: silhouettes too similar at 20px ({difference:.1f} pixels)')
    for error in errors:
        print('FAIL:', error)
    print(f'P5 ART: {len(silhouettes)}/8 pins checked, {len(errors)} errors')
    return int(bool(errors))


if __name__ == '__main__':
    raise SystemExit(main())
