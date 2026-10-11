#!/usr/bin/env python3
"""Builds templates/fonts_customization.xml for the /product substitution.

PixelOS keeps the google-sans* and variable-* families in
/product/etc/fonts_customization.xml, and FontListParser drops same-named
families from /system/etc/fonts.xml:

    if (!oemNamedFamilies.containsKey(name)) {
        // The OEM customization overrides system named family.

So the OEM config itself is replaced: faces are pointed at GoogleSans-Regular.ttf
(redirected to MiSans by a VFS rule), the axes MiSans does not have are dropped,
and wght is left as the only axis the slider can move.

Selection is by FILE, not by family name. The interface asks for variable-*,
which is 18 families; listing them by hand means forgetting one, which is
exactly what v5.0 did — the status bar clock, battery and carrier name stayed
on stock fonts because variable-label-large-emphasized was missed.

Italic faces of google-sans and google-sans-text live in a separate file,
GoogleSans-Italic.ttf, and are left alone: MiSans has no italic file.

Usage:  build_customization.py <source.xml> <template.xml>
"""
import re
import sys
import xml.dom.minidom

# Google Sans files that have to become MiSans.
GOOGLE_FONTS = {
    "GoogleSans-Regular.ttf",
    "GoogleSansClock-Regular.ttf",
    "GoogleSansFlex-Regular.ttf",
}

# The original name is kept: the OEM config resolves files inside
# /product/fonts, and one rule per original name is easier to reason about.
OUR_FONT = "GoogleSans-Regular.ttf"

FONT_RE = re.compile(r"(<font\b[^>]*>)(?P<body>.*?)(</font>)", re.S)
# The file name is matched without the surrounding > and < — the closing > of
# the <font> tag belongs to the other group and is not in the body.
NAME_RE = re.compile(r"([A-Za-z0-9_.-]+\.ttf)")
WEIGHT_RE = re.compile(r'(\bweight=")([0-9]+)(")')
AXIS_RE = re.compile(r"\s*<axis\b[^>]*/>")


def weight_of(open_tag):
    m = WEIGHT_RE.search(open_tag)
    return m.group(2) if m else "400"


def fix_font(m):
    open_tag, body, close_tag = m.group(1), m.group("body"), m.group(3)
    name = NAME_RE.search(body)
    if not name or name.group(1) not in GOOGLE_FONTS:
        return m.group(0)

    body = re.sub(r"[A-Za-z0-9_.-]+\.ttf", OUR_FONT, body, count=1)
    body = AXIS_RE.sub("", body).strip()
    body = f'{body}\n        <axis tag="wght" stylevalue="{weight_of(open_tag)}"/>'
    return open_tag + body + close_tag


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    src, dst = sys.argv[1], sys.argv[2]

    out = FONT_RE.sub(fix_font, open(src, encoding="utf-8").read())
    xml.dom.minidom.parseString(out)          # fail loudly on a broken result
    open(dst, "w", encoding="utf-8").write(out)

    faces = sum(1 for m in FONT_RE.finditer(out)
                if (n := NAME_RE.search(m.group("body"))) and n.group(1) == OUR_FONT)
    print(f"  faces repointed: {faces}")
    print(f"  GoogleSans-Italic.ttf left alone: {out.count('GoogleSans-Italic.ttf')}")
    print(f"  families in file: {out.count('<family ')}")


if __name__ == "__main__":
    main()
