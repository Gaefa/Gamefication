"""Prepare P7 canvases and build the review sheet (Pillow required).

Artwork is produced by image_gen; this only trims transparent margins, uniformly
resizes, places the result on its output canvas and assembles a contact sheet.
  python godot/tools/art_p7_assets.py --prepare /path/to/result-json-directory
  python godot/tools/art_p7_assets.py --sheet
"""
import argparse
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
FAMILIES = ['admin_post', 'main_cistern', 'warehouse', 'shelter', 'well_pump',
            'field_strip', 'lumber_yard', 'quarry_pit', 'tool_workshop']
SINGLES = ['solar_panel_t1', 'generator_t1', 'source_tower_old_t1',
           'source_tower_restored_t1', 'company_office_t1', 'company_ruin_t1']
PROPS = ['pipe_straight', 'pipe_bend', 'pipe_broken', 'sign_company', 'debris',
         'dry_well', 'barrels', 'tarp_tent', 'leaflets', 'fence']
IDS = [f'{family}_t{level}_hex' for family in FAMILIES for level in (1, 2, 3)]
IDS += [f'{name}_hex' for name in SINGLES] + [f'prop_{name}_hex' for name in PROPS]


def destination(asset_id):
    folder = 'props' if asset_id.startswith('prop_') else 'buildings/tiers'
    return ROOT / 'godot/assets' / folder / f'{asset_id}.png'


def silhouette(image):
    return image.getchannel('A').point(lambda a: 255 if a > 12 else 0).getbbox()


def prepare(directory):
    for metadata in sorted(directory.glob('*.json')):
        item = json.loads(metadata.read_text())
        target = destination(item['id'])
        if target.exists():
            continue
        image = Image.open(item['source']).convert('RGBA')
        image = image.crop(silhouette(image))
        size = 512 if item['kind'] == 'prop' else 1024
        width = round(size * 800 / 1024)
        height = round(image.height * width / image.width)
        limit = round(size * 940 / 1024)
        if height > limit:
            width = round(width * limit / height)
            height = limit
        image = image.resize((width, height), Image.Resampling.LANCZOS)
        canvas = Image.new('RGBA', (size, size))
        canvas.alpha_composite(image, ((size - width) // 2, round(size * 964 / 1024) - height))
        canvas.save(target)
        print('PREPARED', item['id'], width, height)


def sheet():
    font = ImageFont.load_default(size=13)
    small = ImageFont.load_default(size=11)
    columns, card_w, card_h = 6, 300, 280
    board = Image.new('RGB', (columns * card_w, 70 + math.ceil(len(IDS) / columns) * card_h), '#302d28')
    draw = ImageDraw.Draw(board)
    draw.text((24, 18), 'P7 / 33 BUILDINGS + 10 PROPS / FRONT-FACING HEX FOOTPRINTS', font=font, fill='#eee8d6')
    draw.text((24, 42), 'Each card: sprite + terrain at equal width (120px); lower pair at 64px. Buildings ordered t1 / t2 / t3.', font=small, fill='#d0c9ba')
    tile = Image.open(ROOT / 'godot/assets/tiles/tile_dust.png').convert('RGBA')
    for i, asset_id in enumerate(IDS):
        image = Image.open(destination(asset_id)).convert('RGBA')
        expected = 512 if asset_id.startswith('prop_') else 1024
        assert image.size == (expected, expected), asset_id
        assert image.getchannel('A').getextrema() == (0, 255), asset_id
        bbox = image.getchannel('A').getbbox()
        assert bbox and min(bbox[:2]) > 0 and max(bbox[2:]) < expected, asset_id
        assert bbox[3] >= expected * .85, asset_id
        image = image.crop(silhouette(image))
        x, y = i % columns * card_w, 70 + i // columns * card_h
        draw.text((x + 10, y + 8), asset_id, font=small, fill='#eee8d6')
        for width, bottom in [(120, y + 176), (64, y + 263)]:
            sprite = image.resize((width, round(image.height * width / image.width)), Image.Resampling.LANCZOS)
            terrain = tile.resize((width, round(width * .75)), Image.Resampling.LANCZOS)
            board.paste(sprite, (x + 15, bottom - sprite.height), sprite)
            board.paste(terrain, (x + 163, bottom - terrain.height), terrain)
    path = ROOT / 'docs/images/visual_pass_b_p7_sheet.png'
    board.save(path)
    print('PASS: 43 PNG canvases, transparent margins, lower anchor; sheet:', path)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prepare', type=Path)
    parser.add_argument('--sheet', action='store_true')
    args = parser.parse_args()
    if args.prepare:
        prepare(args.prepare)
    if args.sheet:
        sheet()
