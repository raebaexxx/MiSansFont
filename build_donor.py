#!/usr/bin/env python3
"""Builds the glyph donor shipped as system/fonts/RobotoStatic-Regular.ttf.

MiSans is a Latin subset: it has no vulgar fractions, thin Greek and Cyrillic
extension coverage, and almost no Latin Extended Additional. The interface
font Google Sans Flex is worse, 535 glyphs with no Cyrillic at all. Glyphs they
do not draw fall back, and before this donor the general chain had no second
Latin font, so the fallback found nothing and drew a box. Gboard's long press
on a digit showed them: 1/5, 1/6 and 5/6 came out as empty frames.

RobotoStatic-Regular.ttf, already in stock /system, covers them. It is subset
to just the codepoints nothing else provides.

Sizing matters. minikin opens fallback files lazily on first use, and that
happens on the UI thread during the first quick settings shade expand: the
full 306 KB donor made the shade date land after the animation. Subsetting to
the 1669 codepoints that are genuinely needed keeps the file small enough
that opening it is not noticeable.

READING THE CHAIN IS THE SUBTLE PART. Almost every font in font_fallback.xml
looks like it belongs to the general fallback, but only fonts in nameless
<family> blocks do, plus the first named family:

    if (name == null) { families.add(family); }
    else if (firstFamily) { families.addAll(namedFamilyList.getFamilies()); }

Fonts inside <family name="source-sans-pro"> and friends sit in a map keyed by
name and are never consulted for sans-serif. Counting all 198 files in the file
as the chain makes the donor far too small -- that is what produced 572
glyphs instead of 1669, and it is why the vulgar fractions ended up missing.

The donor is static, so its glyphs render at weight 400 while MiSans follows
the shift. Only visible in text that uses those characters.

Usage:  build_donor.py <font_fallback.xml> <fontdir> <RobotoStatic-Regular.ttf> <out.ttf>
"""
import re
import os
import sys
import unicodedata
from collections import Counter

from fontTools.subset import Options, Subsetter
from fontTools.ttLib import TTFont

MIFONT = 'system/fonts/Roboto-Regular.ttf'
DONOR_NAME = 'RobotoStatic-Regular.ttf'

def codepoints(path):
    try:
        f = TTFont(path, lazy=True)
        s = set()
        for t in f['cmap'].tables:
            s |= set(t.cmap.keys())
        f.close()
        return s
    except Exception:
        return set()

def general_chain(xml_path, fontdir):
    """Fonts reachable as fallback from any family: nameless <family> blocks
    plus the first named one. Mirrors FontListParser.readFamilies."""
    xml = open(xml_path, encoding='utf-8').read()
    inner = xml[xml.index('<familyset>') + len('<familyset>'): xml.rindex('</familyset>')]
    names, took_first = [], False
    for attrs, body in re.findall(r'<family\b([^>]*)>(.*?)</family>', inner, re.S):
        fonts = re.findall(r'>([A-Za-z0-9_.-]+\.(?:ttf|otf|ttc))<', body)
        if 'name=' not in attrs:
            names += fonts
        elif not took_first:
            names += fonts
            took_first = True
    # the donor must not count itself, or it cancels out
    return sorted({n for n in names if n != DONOR_NAME}), fontdir

def main():
    if len(sys.argv) != 5:
        sys.exit(__doc__)
    chain_xml, fontdir, donor_in, out = sys.argv[1:5]

    chain, _ = general_chain(chain_xml, fontdir)
    covered = set()
    missing = []
    for n in chain:
        p = os.path.join(fontdir, n)
        if not os.path.exists(p):
            missing.append(n)
            continue
        covered |= codepoints(p)

    mine = codepoints(MIFONT)
    need = (codepoints(donor_in) - mine) - covered
    print(f"  chain fonts reachable as fallback: {len(chain)} (not found on disk: {len(missing)})")
    print(f"  chain covers:  {len(covered)} codepoints")
    print(f"  MiSans has:   {len(mine)}")
    print(f"  donor must add: {len(need)}")

    blocks = Counter()
    for c in need:
        try:
            blocks[unicodedata.name(chr(c)).split()[0]] += 1
        except Exception:
            blocks['?'] += 1
    for name, count in blocks.most_common(8):
        print(f"      {name:28} {count}")

    font = TTFont(donor_in)
    opts = Options()
    opts.drop_tables += ['DSIG']
    opts.name_IDs = ['*']
    opts.name_legacy = True
    opts.name_languages = ['*']
    ss = Subsetter(options=opts)
    ss.populate(unicodes=need)
    ss.subset(font)

    # Names must stay: the XML resolves the file by name.
    n = font['name']
    n.setName('RobotoStatic', 1, 3, 1, 0x409)
    n.setName('RegularStatic', 2, 3, 1, 0x409)
    n.setName(DONOR_NAME, 4, 3, 1, 0x409)
    n.setName(DONOR_NAME, 6, 3, 1, 0x409)
    font.save(out)

    check = TTFont(out)
    got = set()
    for t in check['cmap'].tables:
        got |= set(t.cmap.keys())
    print(f"  written {out}: {os.path.getsize(out)} bytes")
    print(f"  codepoints kept: {len(got)}   lost: {len(need - got)}")
    for c in (0x2150, 0x2155, 0x2159, 0x215A, 0x1E9C, 0x1AB0):
        print(f"    U+{c:04X} present: {'yes' if c in got else 'NO'}")

if __name__ == '__main__':
    main()
