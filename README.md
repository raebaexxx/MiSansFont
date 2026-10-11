# MiSans System Font

Модуль для KernelSU / Magisk: системный шрифт Android меняется с Roboto на **MiSans**.

Прямые штрихи вместо закруглённых, кириллица из одного файла, толщина
регулируется ползунком и работает во всех приложениях.

---

## Как устроено

```
system/fonts/Roboto-Regular.ttf      MiSans под именем Roboto
system/etc/font_fallback.xml         семейство sans-serif
system/etc/fonts.xml                 то же в легаси-формате
post-fs-data.sh                      применяет сохранённый сдвиг
```

`Roboto-Regular.ttf` используется семействами `sans-serif`, `roboto`,
`sans-serif-condensed` и общим запасным шрифтом — то есть покрывает всю систему.

## Почему толщина задаётся в конфигурации, а не настройкой

В AOSP есть `Settings.Secure.FONT_WEIGHT_ADJUSTMENT`, и `TextView` складывает
его с осью `wght`:

```java
// frameworks/base/core/java/android/widget/TextView.java
public void setTypeface(@Nullable Typeface tf) {
    if (mFontWeightAdjustment != 0 && ...) {
        int newWeight = Math.min(Math.max(tf.getWeight() + mFontWeightAdjustment, ...), FONT_WEIGHT_MAX);
```

Два ограничения сделали его непригодным как единственный механизм:

**1. Он не везде применяется.** Срабатывает только на этом пути. Приложения,
задающие шрифт мимо `TextView.setTypeface()`, его не видят.

**2. Он только добавляет.** Значение складывается поверх веса из конфигурации.
Если там уже стоит сдвиг, нижняя граница ползунка поднимается, и опустить
толщину ниже нельзя. При сдвиге 200 обычный текст рисуется как 600, и ползунок
от 0 до 300 даёт лишь 600…700 — почти неразличимо.

Поэтому сдвиг пишется прямо в конфигурацию. Он работает у всех, кто берёт
системный шрифт, и даёт полный диапазон.

## Почему это в `post-fs-data.sh`

Порядок загрузки с metamodule HybridMount:

```
ksud::cli: command: PostFsData
  exec <модуль>/post-fs-data.sh          ← наши скрипты
  ksud::metamodule: Executing mount script
  Metamodule mount script executed successfully
```

Скрипты выполняются **до** монтирования. Значит в `post-fs-data.sh` конфиги
ещё можно править — монтирование подхватит уже изменённые файлы.

По этой же причине проверять здесь оверлей бессмысленно: на этом этапе его ещё
нет, проверка всегда увидит пустоту. Именно так модуль однажды отключил сам себя.

## Тонкость, без которой телефон не грузится

Файлы модуля должны иметь SELinux-контекст `system_file`. Попавшие через
`adb push` наследуют `shell_data_file`, и тогда:

```
W auditd: avc:  denied { read } for name="fonts.xml" dev="overlay"
           scontext=u:r:zygote:s0
E SystemFonts: FileNotFoundException: /system/etc/fonts.xml: EACCES
E SystemServerInitThreadPool: Failure in FontManagerService_create: NullPointerException
```

`serviceStarted.complete(null)` не вызывается, `mServiceStarted.join()` висит
вечно, вотердог убивает SystemServer — телефон не грузится вообще.

Проверять после установки:

```bash
ls -lZ /system/fonts/Roboto-Regular.ttf   # должно быть system_file
```

Модуль ставит контекст в `customize.sh` при установке и проверяет его в
`service.sh`. В `sepolicy.rule` лежит подстраховка на случай, если `chcon`
не сработал.

## Управление

**KernelSU → MiSans System Font → веб-интерфейс.** Ползунок 0…300, пресеты,
таблица соответствия весов, кнопка «Сохранить и перезагрузить».

Из консоли:

```bash
su -c 'sh /data/adb/modules/misans/action.sh set 150'
su -c 'sh /data/adb/modules/misans/action.sh'      # только показать
```

**Нужна перезагрузка.** Конфигурация шрифтов читается один раз при старте,
обновления на лету нет.

## `/product` перекрыть нельзя

PixelOS задаёт часы ресурсом `config_clockFontFamily = google-sans-clock` из
`/product/etc/fonts_customization.xml`. Оба пути закрыты:

- `/system/product` — симлинк на точку монтирования раздела, модуль его ломает
- `extra_mount` в HybridMount требует отсутствия записи в `/system` и отвергает
  `/product` с `invalid extra_mount partition`
- алиас из системного слоя не помогает: при конфликте выигрывает именованное
  семейство (`Typeface.initSystemDefaultTypefaces`)

Изменение часов возможно только правкой прошивки.

## Границы

**Приложения со вшитым шрифтом не затрагиваются.** Если приложение кладёт `.ttf`
в assets и обращается по имени, конфиг на него не действует. Так же работает и
стоковый HyperOS.

**Google Play Services** тянет часть шрифтов через собственный `FontsProvider`.

**`sans-serif-monospace` и `sans-serif-smallcaps`** остаются на Roboto: у них
другие файлы. **`sans-serif-condensed`** формально остаётся, но у MiSans нет
оси `wdth`, так что визуально он будет обычной ширины.

## Шрифт

`MiSansLatinVF.ttf` взят из стокового `product` Xiaomi 13. Латиница и кириллица
в одном файле, ось `wght` 150..700. PostScript-имя пропатчено на
`Roboto-Regular`: `FontListParser` выводит его из имени файла, и при несовпадении
карта шрифтов не разрешает нужный глиф.

Код модуля — MIT. Шрифт — собственность Xiaomi, распространяется с их
прошивками; модуль не содержит лицензии на него и предназначен для устройств,
на которых уже установлена стоковая прошивка Xiaomi.
