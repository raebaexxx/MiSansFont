#!/usr/bin/env python3
"""Сдвигает вес sans-serif в обоих конфигах, чтобы весь текст был полужирным.

Settings.Secure.FONT_WEIGHT_ADJUSTMENT работает не везде: он применяется
в TextView.setTypeface(), и приложения, которые задают шрифт в обход
TextView или с собственными начертаниями, его игнорируют.

Поэтому вес сдвигается в самой конфигурации. Запрошенный 400 рендерится
как 600, жирный 700 остаётся 700 — так выделение сохраняется, а весь
обычный текст выглядит полужирным.

По документации AOSP изменения должны быть в обоих файлах:
"In order to support apps that historically use fonts.xml directly,
changes made to font_fallback.xml must be made to fonts.xml."
"""

import os
import re
import sys

MIN_AXIS, MAX_AXIS = 150, 700   # ось MiSans

# Базовый сдвиг веса в конфигурации. Ноль означает «начертание 1:1», и тогда
# толщиной управляет только Settings.Secure.FONT_WEIGHT_ADJUSTMENT.
#
# Ненулевой сдвиг страхует приложения, задающие шрифт мимо
# TextView.setTypeface(), но поднимает нижнюю границу ползунка: при сдвиге
# 200 обычный текст рисуется как 600, и опустить его ниже нельзя — ползунок
# умеет только прибавлять. Поэтому по умолчанию ноль.
BASE_SHIFT = int(os.environ.get('MISANS_BASE_SHIFT', '0'))


def shifted(weight):
    return max(MIN_AXIS, min(MAX_AXIS, weight + BASE_SHIFT))


def legacy_block():
    """Старый формат: fonts.xml, перечисление начертаний."""
    o = ['    <family name="sans-serif">']
    for w in range(100, 1000, 100):
        for style in ('normal', 'italic'):
            o.append(f'        <font weight="{w}" style="{style}">Roboto-Regular.ttf')
            o.append(f'          <axis tag="ital" stylevalue="{1 if style == "italic" else 0}" />')
            o.append('          <axis tag="wght" stylevalue="%d" />' % max(MIN_AXIS, min(MAX_AXIS, shifted(w))))
            o.append('        </font>')
    o.append('    </family>')
    return '\n'.join(o) + '\n'


def fallback_block():
    """Новый формат: font_fallback.xml, Android 15+."""
    o = ['  <family name="sans-serif">']
    for w in range(100, 1000, 100):
        for style in ('normal', 'italic'):
            attrs = f'weight="{w}" style="{style}"'
            o.append(f'    <font {attrs}>')
            o.append('      Roboto-Regular.ttf')
            o.append('      <axis tag="wght" stylevalue="%d"/>'
                     % max(MIN_AXIS, min(MAX_AXIS, shifted(w))))
            if style == 'italic':
                o.append('      <axis tag="ital" stylevalue="1"/>')
            o.append('    </font>')
    o.append('  </family>')
    return '\n'.join(o) + '\n'


def patch(src, dst, block, label):
    s = open(src, encoding='utf-8').read()
    pattern = r'[ \t]*<family name="sans-serif">.*?</family>\n'
    hits = len(re.findall(pattern, s, flags=re.S))
    assert hits == 1, f'{label}: ожидалось одно семейство sans-serif, найдено {hits}'

    before_families = s.count('<family')
    before_alias = s.count('<alias')

    s, n = re.subn(pattern, block, s, flags=re.S)
    open(dst, 'w', encoding='utf-8').write(s)

    import xml.dom.minidom
    xml.dom.minidom.parse(dst)
    text = open(dst, encoding='utf-8').read()
    assert text.count('<family') == before_families, f'{label}: число семейств изменилось'
    assert text.count('<alias') == before_alias, f'{label}: число алиасов изменилось'
    print(f'  {label}: заменено {n}, семейств {before_families}, алиасов {before_alias}')


def main():
    patch('_device/system/etc/fonts.xml', 'system/etc/fonts.xml',
          legacy_block(), 'fonts.xml')
    patch('_device/system/etc/font_fallback.xml', 'system/etc/font_fallback.xml',
          fallback_block(), 'font_fallback.xml')


if __name__ == '__main__':
    sys.exit(main())
