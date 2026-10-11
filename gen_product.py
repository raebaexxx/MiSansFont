#!/usr/bin/env python3
"""Убирает Google Sans из /product/etc/fonts_customization.xml.

PixelOS подключает Google Sans через config_headlineFontFamily,
config_bodyFontFamily и config_clockFontFamily. Из-за этого заголовки
и часы в строке состояния рисуются чужим шрифтом.

Семейства google-sans* удаляются, а их имена превращаются в алиасы
на sans-serif. FontListParser разбирает алиасы после семейств, и
FontManagerService строит карту один раз — всё, что запрашивает
google-sans, получает MiSans.
"""

import re
import sys

SRC = '_device/product/etc/fonts_customization.xml'
DST = 'system/product/etc/fonts_customization.xml'

# имя -> вес, под который оно будет жить в алиасе
ALIASES = [
    ('google-sans', 400),
    ('google-sans-medium', 500),
    ('google-sans-bold', 700),
    ('google-sans-clock', 400),
    ('google-sans-flex', 400),
    ('google-sans-flex-clock', 400),
    ('google-sans-text', 400),
    ('google-sans-text-medium', 500),
    ('google-sans-text-bold', 700),
    ('google-sans-text-italic', 400),
    ('google-sans-text-medium-italic', 500),
    ('google-sans-text-bold-italic', 700),
]


def main():
    s = open(SRC, encoding='utf-8').read()

    # <family и <family-list считаем отдельно, иначе проверка врёт
    def count(text):
        return (len(re.findall(r'<family[\s>]', text)),
                len(re.findall(r'<family-list[\s>]', text)))

    before_families, before_lists = count(s)

    # 1. семейства google-sans* вместе с обёртками family-list
    s, removed_families = re.subn(
        r'\n?[ \t]*<family\s[^>]*name="google-sans[^"]*"[^>]*>.*?</family>', '', s, flags=re.S)
    s, removed_lists = re.subn(
        r'\n?[ \t]*<family-list\s[^>]*name="google-sans[^"]*"[^>]*>.*?</family-list>', '', s, flags=re.S)
    print(f'  удалено семейств google-sans: {removed_families}, family-list: {removed_lists}')

    # 2. родные алиасы gsans на google-sans* — иначе будут дубли имён
    s, n = re.subn(r'\n?[ \t]*<alias name="google-sans[^"]*"[^>]*/>', '', s)
    print(f'  удалено алиасов google-sans: {n}')

    # 3. проверяем, что в имени не осталось упоминаний, кроме fallback=
    left = sorted(set(re.findall(r'google-sans[a-z-]*',
                                re.sub(r'fallback="[^"]*"', '', s))))
    assert not left, f'остались google-sans: {left}'
    print('  ссылок на google-sans не осталось')

    # 4. наши алиасы
    block = ('  <!-- Google Sans -> MiSans: заголовки и часы должны быть тем же шрифтом -->\n'
             + ''.join(f'  <alias name="{n}" to="sans-serif" weight="{w}"/>\n'
                       for n, w in ALIASES))
    i = s.rfind('</fonts-modification>')
    assert i > 0, 'нет закрывающего тега'
    s = s[:i] + block + s[i:]

    import os
    os.makedirs(os.path.dirname(DST), exist_ok=True)
    open(DST, 'w', encoding='utf-8').write(s)

    # 5. самопроверка
    import xml.dom.minidom
    xml.dom.minidom.parse(DST)
    text = open(DST, encoding='utf-8').read()
    names = re.findall(r'<alias name="([^"]*)"', text)
    dupes = {n for n in names if names.count(n) > 1}
    assert not dupes, f'дубли алиасов: {dupes}'
    after_families, after_lists = count(text)
    del after_families, after_lists, before_families, before_lists

    # Сверяем именно имена семейств: счётчики тегов врут из-за
    # <family-list> и безымянных <family> внутри них.
    from collections import Counter

    def family_names(t):
        return [m.group(1)
                for m in re.finditer(r'<family(?:-list)?[^>]*name="([^"]*)"', t)]

    before = Counter(family_names(open(SRC, encoding='utf-8').read()))
    after = Counter(family_names(text))
    gone, added = before - after, after - before

    assert not added, f'появились лишние семейства: {added}'
    assert set(gone) <= {n for n, _ in ALIASES}, f'пропали не те: {set(gone)}'
    print(f'  семейств было {sum(before.values())}, стало {sum(after.values())}')
    print(f'  заменено на алиасы: {len(gone)} семейств, {len(names)} алиасов')
    print(f'  OK: {DST}')


if __name__ == '__main__':
    sys.exit(main())
