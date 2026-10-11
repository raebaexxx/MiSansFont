#!/usr/bin/env python3
"""Готовит fonts_customization.xml для подмены через VFS-правило.

PixelOS держит семейства google-sans* и variable-* в
/product/etc/fonts_customization.xml, и FontListParser выкидывает одноимённые
семейства из /system/etc/fonts.xml:

    if (!oemNamedFamilies.containsKey(name)) {
        // The OEM customization overrides system named family.

Поэтому подменяется сам OEM-конфиг: начертания переводятся на
GoogleSans-Regular.ttf (это MiSans, он лежит под правилом), лишние оси
удаляются, а вес wght остаётся осью, которую умеет менять ползунок.

Отбор идёт ПО ФАЙЛУ, а не по имени семейства. Так подхватываются все 18
семейств variable-*, не надо вести список: строка состояния просит
variable-label-large-emphasized, и без этого часы, заряд и имя оператора
остались бы стоковыми.

Курсивные начертания google-sans и google-sans-text лежат в отдельном файле
GoogleSans-Italic.ttf и не трогаются: у MiSans нет курсивного файла.

Запуск:  build_customization.py <исходный.xml> <шаблон.xml>
"""
import re
import sys

# Файлы Google Sans, которые нужно заменить на MiSans.
GOOGLE_FONTS = {
    "GoogleSans-Regular.ttf",
    "GoogleSansClock-Regular.ttf",
    "GoogleSansFlex-Regular.ttf",
}

# Имя оставляем прежним: OEM-конфиг ищет файлы в /product/fonts, и отдельное
# правило на каждое переименование не нужно.
OUR_FONT = "GoogleSans-Regular.ttf"

FONT_RE = re.compile(r"(<font\b[^>]*>)(?P<body>.*?)(</font>)", re.S)
# Имя файла ищется без обрамляющих > и <: закрывающий > тега <font> лежит
# в другой группе, в теле его нет.
NAME_RE = re.compile(r"([A-Za-z0-9_.-]+\.ttf)")
ATTR_RE = re.compile(r'(\bweight=")([0-9]+)(")')
STYLE_RE = re.compile(r'\bstyle="([a-z]+)"')
AXIS_RE = re.compile(r"\s*<axis\b[^>]*/>")


def weight_of(open_tag):
    m = ATTR_RE.search(open_tag)
    return m.group(2) if m else "400"


def fix_font(m):
    open_tag, body, close_tag = m.group(1), m.group("body"), m.group(3)
    name = NAME_RE.search(body)
    if not name or name.group(1) not in GOOGLE_FONTS:
        return m.group(0)

    # Имя файла ищется без обрамляющих > и <: закрывающий > тега <font>
    # лежит в другой группе, в теле его нет.
    body = re.sub(r"[A-Za-z0-9_.-]+\.ttf", OUR_FONT, body, count=1)
    body = AXIS_RE.sub("", body).strip()
    body = f"{body}\n        <axis tag=\"wght\" stylevalue=\"{weight_of(open_tag)}\"/>"
    return open_tag + body + close_tag


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    src, dst = sys.argv[1], sys.argv[2]

    xml = open(src, encoding="utf-8").read()
    out = FONT_RE.sub(fix_font, xml)
    open(dst, "w", encoding="utf-8").write(out)

    import xml.dom.minidom
    xml.dom.minidom.parseString(out)

    touched = 0
    for m in FONT_RE.finditer(out):
        n = NAME_RE.search(m.group("body"))
        if n and n.group(1) == OUR_FONT:
            touched += 1
    print(f"  начертаний переведено на наш файл: {touched}")
    print(f"  GoogleSans-Italic.ttf осталось: {out.count('GoogleSans-Italic.ttf')}")
    print(f"  семейств в файле: {out.count('<family ')}")


if __name__ == "__main__":
    main()
