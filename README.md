# MiSans System Font

Модуль для KernelSU / Magisk: системный шрифт Android меняется с Roboto на **MiSans**,
с живой кириллицей и работающим ползунком толщины.

Робото не меняет. Зато у MiSans прямые штрихи вместо закруглённых и ось веса
`wght` от 150 до 700 в одном файле — поэтому толщину можно двигать глобально,
а не выбирать один из двух файлов.

---

## Что делает

| | |
|---|---|
| `sans-serif` | Roboto → **MiSans** |
| `sans-serif-light` | → MiSans |
| `sans-serif-thin` | → MiSans |
| `sans-serif-medium` | → MiSans |
| `sans-serif-black` | → MiSans |
| `google-sans*` (12 имён) | → алиас на `sans-serif` |
| `config_clockFontFamily` | уезжает на MiSans, часы в строке состояния больше не чужой шрифт |

**Не трогает** `sans-serif-condensed*`, `sans-serif-monospace`, `sans-serif-smallcaps`:
у MiSans нет оси `wdth` и нет моноширинного начертания. Подмена там их бы сломала.

---

## Установка

1. Скачать `MiSansBold-v1.0.zip` из релизов
2. KernelSU → Модули → Установить из хранилища → выбрать файл
3. **Перезагрузка**

Шрифт читается системой при старте, поэтому без перезагрузки не подхватится.

---

## Ползунок толщины

KernelSU → модуль **MiSans System Font** → кнопка **«Действие»**.

```
MiSans — толщина шрифта
==========================
  сохранено в модуле: +300
  сейчас в системе:  +300

  MiSans, ось wght 150..700. Значение прибавляется к весу текста:
    обычный  400 + 300 = 700
    тонкий   100 + 300 = 400
    средний  500 + 300 = 800
  всё, что выше 700, упрётся в предел оси и станет 700.

  1)  +0    обычный вид
  2)  +50
  3)  +100
  4)  +150
  5)  +200
  6)  +250
  7)  +300  максимум
  8)  вписать значение вручную
  0)  выход
```

По умолчанию **+300** — это «крайнее правое положение», как на стоке HyperOS.

Изменение толщины видно сразу, SystemUI перезапускается сам.

Из консоли:

```bash
su -c 'sh /data/adb/modules/misans/action.sh set 150'
```

---

## Почему ползунок вообще возможен

Механизм родной, просто в LineageOS нет UI:

```java
// frameworks/base/core/java/android/provider/Settings.java
Settings.Secure.FONT_WEIGHT_ADJUSTMENT = "font_weight_adjustment";

// TextView.java — значение просто прибавляется к оси wght
Math.clamp(axis.getStyleValue() + mFontWeightAdjustment,
           FontStyle.FONT_WEIGHT_MIN, FontStyle.FONT_WEIGHT_MAX)
```

`TextView` есть везде, поэтому сдвиг применяется и в системе, и в приложениях.

**Почему тумблер «Полужирный шрифт» в стоковой сборке ничего не делает:**
в системном `/system/etc/fonts.xml` для Roboto объявлены оси `ital` и `wdth`,
но **не `wght`**. Сдвигать нечего, жирного начертания у Roboto два файла,
и грубый выбор между ними не меняет толщину мелкого текста.
С MiSans ось появляется — и ползунок начинает работать.

---

## Почему через `fonts_customization.xml`, а не `fonts.xml`

```java
// FontListParser.java
if (!oemNamedFamilies.containsKey(name)) {
    resultNamedFamilies.add(namedFamilyList);
}
// OEM-кастомизация перекрывает системное семейство с тем же именем
```

`/product/etc/fonts_customization.xml` — OEM-слой поверх системного
`/system/etc/fonts.xml`. Перекрывая имена в нём, модуль не трогает
базовую конфигурацию и откатывается удалением модуля.

Шрифты из этого слоя берутся из `/product/fonts/`:

```java
// SystemFonts.java
public static final String OEM_FONT_DIR = "/product/fonts/";
```

---

## Границы

**Приложения со вшитым шрифтом не трогаются.** Если приложение кладёт `.ttf` в assets
и обращается к нему по имени файла, никакой `fonts.xml` на него не действует.
Это не ограничение модуля — так же работает и стоковый HyperOS.

**Google Play Services** подтягивает шрифты через downloadable fonts — отдельный
механизм, тоже не перехватывается. На практике приложения Google используют
системные семейства, поэтому визуально они переезжают на MiSans.

---

## Состав

```
module.prop
customize.sh                              установка
service.sh                                применение толщины при загрузке
action.sh                                 меню «Действие»
common.sh                                 общие функции
system/product/etc/fonts_customization.xml
system/product/fonts/MiSansLatinVF.ttf    481 КБ
```

`MiSansLatinVF.ttf` взят из стокового `product` Xiaomi 13.
Латиница + кириллица в одном файле, ось `wght` 150..700.
Полная версия со всем алфавитом — 20 МБ, она здесь не нужна.

---

## Лицензия шрифта

Код модуля — MIT (см. `LICENSE`).

`MiSansLatinVF.ttf` — собственность Xiaomi, распространяется с их прошивками.
Модуль не содержит лицензии на шрифт и существует только для владельцев устройств,
на которых уже установлена стоковая прошивка Xiaomi.
