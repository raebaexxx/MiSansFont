#!/usr/bin/env python3
"""Builds the glyph donor shipped as system/fonts/RobotoStatic-Regular.ttf.

MiSans is a Latin subset: no combining-extended marks (U+1AB0-U+1AFF), thin
Greek and Cyrillic extension coverage, and the interface font Google Sans Flex
has no Cyrillic at all. No MiSans file in the stock ROM covers those ranges --
verified across all 25 of them, 0 of 80 for U+1AB0-U+1AFF.

RobotoStatic-Regular.ttf, which stock Android already ships in /system, covers
all of it. Adding it to the fallback chain fixes the tofu boxes, but minikin
opens fallback files lazily on first use: the 306 KB original made the quick
settings date land after the expand animation.

So the donor is subset down to only the codepoints that nothing else provides.
1728 that RobotoStatic adds over MiSans, but the existing chain already covers
1156 of them, so only 572 actually rendered as boxes. 59 KB instead of 306 KB,
and five times less to parse.

The donor stays last in the chain, so it is consulted only when no other font
has the glyph, and only those rare characters are affected.

Usage:  build_donor.py <chain-fonts-list> <RobotoStatic-Regular.ttf> <out.ttf>
"""
import sys
import unicodedata
from collections import Counter

from fontTools.subset import Options, Subsetter
from fontTools.ttLib import TTFont

MIFONT = 'system/fonts/Roboto-Regular.ttf'


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


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    chain_list, donor_in, out = sys.argv[1], sys.argv[2], sys.argv[3]

    mine = codepoints(MIFONT)
    covered = set()
    with open(chain_list, encoding='utf-8') as fh:
        for line in fh:
            name = line.strip()
            if name:
                covered |= codepoints(name)
    need = (codepoints(donor_in) - mine) - covered
    print(f"  base font:  {len(mine)} codepoints")
    print(f"  chain:      {len(covered)}")
    print(f"  donor adds: {len(need)} codepoints nothing else has")

    blocks = Counter()
    for c in need:
        try:
            blocks[unicodedata.name(chr(c)).split()[0]] += 1
        except Exception:
            blocks['?'] += 1
    for name, count in blocks.most_common(6):
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

    # Names stay as they are: the XML resolves the file by name, and a
    # mismatch makes the font map fail to resolve it.
    n = font['name']
    n.setName('RobotoStatic', 1, 3, 1, 0x409)
    n.setName('RegularStatic', 2, 3, 1, 0x409)
    n.setName('RobotoStatic-Regular', 4, 3, 1, 0x409)
    n.setName('RobotoStatic-Regular', 6, 3, 1, 0x409)
    font.save(out)

    check = TTFont(out)
    got = set()
    for t in check['cmap'].tables:
        got |= set(t.cmap.keys())
    print(f"  written: {out}")
    print(f"  codepoints kept: {len(got)}   lost: {len(need - got)}")
    print(f"  PostScript name: {check['name'].getDebugName(6)}")
    print(f"  variable: {'yes' if 'fvar' in check else 'no, static'}")


if __name__ == '__main__':
    main()
