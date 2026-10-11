# MiSans System Font

Модуль для KernelSU / Magisk: системный шрифт Android меняется с Roboto на **MiSans**.

Прямые штрихи вместо закруглённых, кириллица из одного файла, вес всего текста
смещён в полужирный. Меняется три файла в `/system` — конфигурация системы
остаётся валидной по построению.

---

## Что делает

| Файл | Что |
|---|---|
| `system/fonts/Roboto-Regular.ttf` | MiSans под именем Roboto |
| `system/etc/font_fallback.xml` | вес `sans-serif` сдвинут вверх |
| `system/etc/fonts.xml` | то же в легаси-формате |

`Roboto-Regular.ttf` используется семействами `sans-serif`, `roboto`,
`sans-serif-condensed` и общим запасным шрифтом — то есть покрывает всю систему.

### Сдвиг веса

```
запрошено   рендерится
   100  →    150      нижний предел оси MiSans
   300  →    600
   400  →    600      обычный текст полужирный
   500  →    650
   700  →    700      жирный остаётся жирным
```

Так выделение сохраняется, а весь обычный текст выглядит жирным.

---

## Почему не через ползунок в настройках

В AOSP есть `Settings.Secure.FONT_WEIGHT_ADJUSTMENT`, и `TextView` складывает
его с осью `wght`:

```java
// frameworks/base/core/java/android/widget/TextView.java
public void setTypeface(@Nullable Typeface tf) {
    if (mFontWeightAdjustment != 0 && ...) {
        int newWeight = Math.min(Math.max(tf.getWeight() + mFontWeightAdjustment, ...), FONT_WEIGHT_MAX);
        tf = Typeface.create(tf, newWeight, italic);
    }
```

Значение действительно доходит до приложений — видно в `dumpsys window`:
`fontWeightAdjustment=300`. Но применяется оно только на этом пути. Приложения,
задающие шрифт в обход `TextView.setTypeface()`, его игнорируют.

Поэтому вес сдвигается в самой конфигурации. Это работает везде независимо от
приложения.

---

## Тонкость, без которой телефон не грузится

SELinux-контекст файлов в модуле должен быть `system_file`.

Файлы, попавшие в модуль через `adb push`, наследуют `shell_data_file`.
Magic mount подставляет их в `/system` с этим контекстом, и SELinux запрещает
zygote читать конфигурацию шрифтов:

```
W auditd: avc:  denied { read } for name="fonts.xml" dev="overlay"
           scontext=u:r:zygote:s0
E SystemFonts: FileNotFoundException: /system/etc/fonts.xml: EACCES
E SystemServerInitThreadPool: Failure in FontManagerService_create:
    java.lang.NullPointerException: at android.graphics.Typeface.create
```

Дальше `serviceStarted.complete(null)` не вызывается, `mServiceStarted.join()`
висит вечно, вотердог убивает SystemServer, он перезапускается и падает снова.
Телефон не грузится вообще.

Модуль лечит это в трёх местах:

- `customize.sh` — `chcon -R u:object_r:system_file:s0` при установке
- `service.sh` — проверяет контекст подменённого шрифта и чинит его
- `sepolicy.rule` — подстраховка на случай, если `chcon` не сработал

Проверить после установки:

```bash
ls -lZ /system/fonts/Roboto-Regular.ttf
```

Должно быть `u:object_r:system_file:s0`.

---

## Часы в строке состояния остаются Google Sans

PixelOS задаёт часы ресурсом `config_clockFontFamily = google-sans-clock`,
который приходит из `/product/etc/fonts_customization.xml`.

Перекрыть `/product` на этом устройстве нельзя, оба пути закрыты:

**1. `system/product/` в модуле.** В system-as-root `/system/product` — симлинк
на точку монтирования раздела:

```
/system/product -> /product
KSU on /system/etc    type overlay
```

Модуль создаёт каталог поверх симлинка, и монтирование ломается.

**2. `extra_mount` в metamodule HybridMount.** Разрешено только для разделов
без соответствующей записи в `/system`:

```toml
# config.toml
# Targets must exist and have no corresponding /system entry.
extra_mount = []
```

Бинарь отвергает `/product` явно:

```
extra_mount: /system entry already exists
invalid extra_mount partition:
```

**3. Алиас из системного слоя** тоже не помогает — при конфликте выигрывает
именованное семейство:

```java
// Typeface.initSystemDefaultTypefaces
if (outSystemFontMap.containsKey(alias.getName())) {
    continue; // If alias and named family are conflict, use named family.
}
```

Единственный рабочий способ изменить часы — правка в дереве прошивки, одной
пересборкой, без модуля.

---

## Границы

**Приложения со вшитым шрифтом не затрагиваются.** Если приложение кладёт `.ttf`
в assets и обращается по имени, `fonts.xml` на него не действует. Так же
работает и стоковый HyperOS.

**Google Play Services** тянет шрифты через собственный `FontsProvider`,
минуя системный. На практике приложения Google используют системные семейства
и переезжают на MiSans, но полное отключение GMS-шрифтов в модуль не входит.

**`sans-serif-monospace` и `sans-serif-smallcaps`** остаются на Roboto: у них
другие файлы.

**`sans-serif-condensed`** формально остаётся, но у MiSans нет оси `wdth`,
так что визуально он будет обычной ширины.

---

## Установка

1. Скачать `MiSansFont-v3.2.zip` из релизов
2. KernelSU → Модули → Установить из хранилища
3. Перезагрузка

Ползунок толщины — кнопка «Действие» у модуля, значения 0…300 поверх сдвига:

```bash
su -c 'sh /data/adb/modules/misans/action.sh set 0'
```

При 0 обычный текст будет 600, при 300 — 700, то есть в потолок оси.

---

## Шрифт

`MiSansLatinVF.ttf` взят из стокового `product` Xiaomi 13. Латиница и кириллица
в одном файле, ось `wght` 150..700. PostScript-имя пропатчено на `Roboto-Regular`:
`FontListParser` выводит его из имени файла, и при несовпадении карта шрифтов
не разрешает нужный глиф.

Код модуля — MIT. Шрифт — собственность Xiaomi, распространяется с их
прошивками; модуль не содержит лицензии на него и предназначен для устройств,
на которых уже установлена стоковая прошивка Xiaomi.
