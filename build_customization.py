#!/usr/bin/env python3
"""Готовит fonts_customization.xml для подмены через VFS-правило.

PixelOS держит семейства google-sans* в /product/etc/fonts_customization.xml,
и FontListParser выкидывает одноимённые семейства из /system/etc/fonts.xml:

    if (!oemNamedFamilies.containsKey(name)) {
        // The OEM customization overrides system named family.

Поэтому подменяется сам OEM-конфиг: прямые начертания переводятся на
Roboto-Regular.ttf (это MiSans, он лежит в /system/fonts), лишние оси
удаляются, а вес wght становится осью, которую умеет менять ползунок.

Курсивные начертания не трогаются: у MiSans нет курсивного файла, и
GoogleSans-Italic.ttf продолжает давать настоящий курсив.

Запуск:  build_customization.py <исходный.xml> <шаблон.xml> [семейство ...]
"""
import re
import sys

# Начертания, которые интерфейс берёт через config_*FontFamily
# (vendor/pixel/gsans/overlay/.../config.xml).
DEFAULT_TARGETS = [
    "google-sans",              # config_headlineFontFamily
    "google-sans-medium",       # config_headlineFontFamilyMedium
    "google-sans-bold",
    "google-sans-text",         # config_bodyFontFamily
    "google-sans-text-medium",
    "google-sans-clock",        # config_clockFontFamily
]

OUR_FONT = "GoogleSans-Regular.ttf"   # имя оставляем: OEM-конфиг ищет файлы в /product/fonts

FONT_RE = re.compile(
    r"(<font\b[^>]*>)(?P<body>.*?)(</font>)", re.S)
ATTR_RE = re.compile(r'(\bweight=")([0-9]+)(")')
STYLE_RE = re.compile(r'\bstyle="([a-z]+)"')
AXIS_RE = re.compile(r"\s*<axis\b[^>]*/>")


def fix_font(m):
    open_tag, body, close_tag = m.group(1), m.group("body"), m.group(3)
    style = STYLE_RE.search(open_tag)
    if style and style.group(1) == "italic":
        return m.group(0)                      # курсив оставляем как есть

    # Прямое начертание: файл наш, лишних осей в нём не существует.
    # Имя файла ищется без обрамляющих > и <: закрывающий > тега <font>
    # лежит в другой группе, в теле его нет.
    body = re.sub(r"[A-Za-z0-9_.-]+\.ttf", OUR_FONT, body, count=1)
    body = AXIS_RE.sub("", body).strip()
    body = f"{body}\n        <axis tag=\"wght\" stylevalue=\"{weight_of(open_tag)}\"/>"
    return open_tag + body + close_tag


def weight_of(open_tag):
    m = ATTR_RE.search(open_tag)
    return m.group(2) if m else "400"


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    src, dst = sys.argv[1], sys.argv[2]
    targets = sys.argv[3:] or DEFAULT_TARGETS

    xml = open(src, encoding="utf-8").read()
    touched = []

    def repl(m):
        head = m.group(0)
        name = re.search(r'name="([^"]+)"', head)
        if not name or name.group(1) not in targets:
            return head
        touched.append(name.group(1))
        return FONT_RE.sub(fix_font, head)

    out = re.sub(r"<family\b.*?</family>", repl, xml, flags=re.S)
    open(dst, "w", encoding="utf-8").write(out)

    missing = [t for t in targets if t not in touched]
    print(f"  обработано семейств: {len(set(touched))} -> {sorted(set(touched))}")
    if missing:
        print(f"  НЕ НАЙДЕНЫ в исходнике: {missing}")
    print(f"  наш файл в семействах: {out.count(OUR_FONT)} вхождений")


if __name__ == "__main__":
    main()
