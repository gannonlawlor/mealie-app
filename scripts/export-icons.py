"""Export Cookbook icons from the approved imagegen master. Requires Pillow."""

import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BG = '#B54122'
CREAM = '#FFF7E6'
SIZE = 1024
RESAMPLE = Image.Resampling.LANCZOS

# Separate the two-color artwork and normalize generated color variation.
source = Image.open(ROOT / 'docs/branding/icon-master.png').convert('RGB')
mask = source.getchannel('G').point(lambda v: 255 if v >= 160 else 0)
mask = mask.resize((SIZE, SIZE), RESAMPLE)


def composite(background, foreground):
    image = Image.new('RGB', (SIZE, SIZE), background)
    image.paste(Image.new('RGB', image.size, foreground), (0, 0), mask)
    return image


ios = ROOT / 'ios/Darwin/Assets.xcassets/AppIcon.appiconset'
images = []
for name, appearance, background, foreground in [
    ('AppIcon.png', None, BG, CREAM),
    ('AppIcon-dark.png', 'dark', '#241914', CREAM),
    ('AppIcon-tinted.png', 'tinted', '#202020', '#EEEEEE'),
]:
    composite(background, foreground).save(ios / name)
    entry = dict(filename=name, idiom='universal', platform='ios', size='1024x1024')
    if appearance:
        entry['appearances'] = [dict(appearance='luminosity', value=appearance)]
    images.append(entry)
(ios / 'Contents.json').write_text(json.dumps(
    dict(images=images, info=dict(author='xcode', version=1)), indent=2) + '\n')

res = ROOT / 'android/app/src/main/res'
for density, scale in [('mdpi', 1), ('hdpi', 1.5), ('xhdpi', 2),
                       ('xxhdpi', 3), ('xxxhdpi', 4)]:
    folder = res / f'mipmap-{density}'
    adaptive_size = round(108 * scale)
    legacy_size = round(48 * scale)
    # Adaptive layers include space outside the launcher mask for motion.
    mark_size = round(adaptive_size * .76)
    adaptive_mask = Image.new('L', (adaptive_size, adaptive_size))
    offset = (adaptive_size - mark_size) // 2
    adaptive_mask.paste(mask.resize((mark_size, mark_size), RESAMPLE), (offset, offset))
    foreground = Image.new('RGBA', adaptive_mask.size, CREAM)
    foreground.putalpha(adaptive_mask)
    foreground.save(folder / 'ic_launcher_foreground.png')
    monochrome = Image.new('RGBA', adaptive_mask.size, 'white')
    monochrome.putalpha(adaptive_mask)
    monochrome.save(folder / 'ic_launcher_monochrome.png')
    Image.new('RGB', adaptive_mask.size, BG).save(folder / 'ic_launcher_background.png')
    composite(BG, CREAM).resize((legacy_size, legacy_size), RESAMPLE).save(
        folder / 'ic_launcher.png')

print('Exported 3 iOS icons and 20 Android icon layers.')
