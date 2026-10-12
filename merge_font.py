#!/usr/bin/env python3
"""Merges MiSans with a donor font so that no glyph falls back to a tofu box.

MiSans is a Latin subset. It has no combining-extended marks (U+1AB0-U+1AFF),
almost no Latin Extended Additional, and thin Greek and Cyrillic extension
coverage. Google Sans Flex, which the interface asks for, is worse: 535 glyphs,
Latin and digits only, no Cyrillic at all.

Neither the Latin subset nor the full MiSansVF from the stock ROM covers those
ranges -- verified across all 25 MiSans files in the firmware, 0 of 80 for
U+1AB0-U+1AFF. The typeface simply does not draw them.

Putting a donor into /system/etc/font_fallback.xml fixes the boxes, but minikin
opens fallback files lazily on first use, so the first layout pays for opening
a 306 KB font on the UI thread and the quick settings date lands after the
expand animation. Merging keeps a single font, so nothing extra is opened.

Cost: the added glyphs are static outlines. They render at weight 400 while
MiSans follows the shift, so a run mixing both will not match in weight. Only
visible in text that actually uses those rare characters.

Usage:  merge_font.py <base.ttf> <donor.ttf> <out.ttf>
"""
import sys
from fontTools.ttLib import TTFont
from fontTools.merge import Merger


def codepoints(path):
    f = TTFont(path, lazy=True)
    s = set()
    for t in f['cmap'].tables:
        s |= set(t.cmap.keys())
    f.close()
    return s


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    base, donor, out = sys.argv[1], sys.argv[2], sys.argv[3]

    have = codepoints(base)
    gain = codepoints(donor) - have
    print(f"  base   {len(have)} codepoints")
    print(f"  donor adds {len(gain)}")

    merger = Merger()
    merger.merge([base, donor])
    font = merger.font

    # The donor's PostScript name must not collide with the base, otherwise the
    # font map resolves to the wrong face. MiSans is patched to Roboto-Regular;
    # RobotoStatic-Regular is a different name, so nothing to fix here -- but
    # verify rather than assume.
    got = set()
    for t in font['cmap'].tables:
        got |= set(t.cmap.keys())
    missing = gain - got
    if missing:
        print(f"  WARNING: {len(missing)} donor codepoints lost during merge")

    axes = [(a.axisTag, a.minValue, a.maxValue) for a in font['fvar'].axes] \
        if 'fvar' in font else None
    print(f"  axes kept: {axes}")
    print(f"  total codepoints: {len(got)} (was {len(have)})")

    font.save(out)
    print(f"  written: {out}")

    # Re-open what was written: a merge that corrupts the variable tables only
    # shows up here.
    check = TTFont(out)
    ok_axes = [(a.axisTag, a.minValue, a.defaultValue, a.maxValue)
               for a in check['fvar'].axes] if 'fvar' in check else None
    print(f"  reopened, axes: {ok_axes}")
    print(f"  reopened, glyphs: {len(check.getGlyphOrder())}")
    check.close()


if __name__ == '__main__':
    main()
