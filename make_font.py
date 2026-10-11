#!/usr/bin/env python3
"""Готовит MiSans к подстановке на место Roboto-Regular.ttf.

Подход взят у сообщества (kdrag0n/inter-font-pack, LibreTypeface,
reddxae/return-roboto): XML не трогаем вообще, меняем только содержимое
файла шрифта, сохраняя его имя. Тогда конфигурация системы остаётся
валидной по построению.

Зачем патчить имя: FontListParser выводит PostScript-имя из имени файла
    postScriptName = sanitizedName.substring(0, len - 4)
и использует его как ключ в карте шрифтов. Для Roboto-Regular.ttf это
"Roboto-Regular". Если оставить родное имя MiSans, ключ перестанет
совпадать с тем, что система ждёт. inter-font-pack пишет об этом прямо:
"all font names have been patched to match the original fonts".
"""

import shutil
import sys

from fontTools.ttLib import TTFont

SRC = '/tmp/opencode/prod_mnt/fonts/MiSansLatinVF.ttf'
DST = 'system/fonts/Roboto-Regular.ttf'

# Имя берётся из имени файла, а не из содержимого. Держим в согласии.
FAMILY = 'Roboto'
PS_NAME = 'Roboto-Regular'


def main():
    font = TTFont(SRC)
    name = font['name']

    # У PostScript-имени есть ограничение: только ASCII, без пробелов.
    assert PS_NAME.isascii() and ' ' not in PS_NAME

    for platform, encoding, language in ((3, 1, 0x409), (1, 0, 0)):
        name.setName(FAMILY, 1, platform, encoding, language)
        name.setName('Regular', 2, platform, encoding, language)
        name.setName(PS_NAME, 4, platform, encoding, language)
        name.setName(PS_NAME, 6, platform, encoding, language)

    font.save(DST)

    # проверяем то, что записалось
    check = TTFont(DST, lazy=True)
    got = check['name'].getDebugName(6)
    axes = [(a.axisTag, a.minValue, a.maxValue) for a in check['fvar'].axes]
    cmap = check.getBestCmap()

    cyrillic = all(ord(c) in cmap for c in 'АбвгдеёжзийклмнопрстуфхцчшщъыьэюяЁ')
    latin = all(ord(c) in cmap for c in 'AaBbGgRrSsTtWwZz')

    print(f'  PostScript: {got}')
    print(f'  оси: {axes}')
    print(f'  кириллица: {"есть" if cyrillic else "НЕТ"}')
    print(f'  латиница:  {"есть" if latin else "НЕТ"}')

    assert got == PS_NAME, 'имя не записалось'
    assert cyrillic and latin
    print(f'  OK: {DST}')


if __name__ == '__main__':
    sys.exit(main())
