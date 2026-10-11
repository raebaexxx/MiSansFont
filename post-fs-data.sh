#!/system/bin/sh
# Применяет сдвиг веса и подменяет файлы /product через VFS-правила.
#
# Скрипт выполняется на этапе post-fs-data, то есть ДО чтения конфигурации
# шрифтов zygote. Проверять тут оверлей бессмысленно (его ещё нет), а вот
# подменить файлы в /product — в самый раз.
#
# Зачем нужен /product: PixelOS держит переопределение google-sans* в
# /product/etc/fonts_customization.xml, и FontListParser выкидывает одноимённые
# семейства из /system/etc/fonts.xml:
#
#   if (!oemNamedFamilies.containsKey(name)) {
#       // The OEM customization overrides system named family.
#
# Интерфейс берёт config_bodyFontFamily = google-sans-text (RRO-оверлей тоже
# в /product), поэтому без этой подмены MiSans до него не доходит.
#
# Обычными средствами модуля /product не перекрыть: extra_mount в HybridMount
# требует, чтобы не было соответствующей записи в /system, а /system/product —
# симлинк. VFS-правила работают на уровне ядра и этой проверки не имеют.
#
# ВНИМАНИЕ: составной образец вида "cond && /regex/ { }" часть awk его не
# разбирает (gawk 5.4.1 — syntax error, toybox на устройстве — иначе).
# Все условия написаны через if, где такой ошибки нет.

MODDIR=${0%/*}
[ -z "$MODPATH" ] && [ "$MODDIR" = "$0" ] && MODDIR="."
[ -n "$MODPATH" ] && MODDIR="$MODPATH"

. "$MODDIR/common.sh"

STATE=/data/adb/misans
SHIFT_FILE="$STATE/shift"
UNIFY_FILE="$STATE/unify"
MIN_AXIS=150
MAX_AXIS=700

# Каталог для файлов, на которые ссылаются правила. /data/adb закрыт от
# zygote, а /data/cache принадлежит системе: root пишет, zygote читает.
SERVE=/data/cache/misans

HYBRID=/data/adb/modules/hybrid_mount/hybrid-mount
PRODUCT_FONTS=/product/fonts
OEM_XML=/product/etc/fonts_customization.xml

SHIFT=$(cat "$SHIFT_FILE" 2>/dev/null)
case "$SHIFT" in
    ''|*[!0-9]*) SHIFT=0 ;;
esac
[ "$SHIFT" -gt 300 ] && SHIFT=300

# Прибавляет сдвиг к wght внутри перечисленных семейств. Вес берётся из
# атрибута weight того же элемента <font>: начертания объявлены явно, поэтому
# сдвигать нужно именно значение оси, а не номер начертания.
shift_targets() {
    list="$1"
    file="$2"
    awk -v shift="$SHIFT" -v lo="$MIN_AXIS" -v hi="$MAX_AXIS" -v names="$list" '
        BEGIN {
            n = split(names, want, " ")
            for (i = 1; i <= n; i++) targets[want[i]] = 1
        }
        {
            if (match($0, /<family [^>]*name="[^"]+"/)) {
                seg = substr($0, RSTART, RLENGTH)
                if (match(seg, /name="[^"]+"/)) {
                    fname = substr(seg, RSTART + 6, RLENGTH - 7)
                    if (fname in targets) keep = 1
                    else keep = 0
                }
            }
            if (keep && index($0, "<font") > 0) {
                # -1 = веса у начертания нет. Так оформлены часы:
                # <font> без атрибутов. Тогда берётся текущее значение оси,
                # иначе w утекал бы из предыдущего семейства.
                w = -1
                if (match($0, /weight="[0-9]+"/)) {
                    w = substr($0, RSTART + 8, RLENGTH - 9) + 0
                }
            }
            if (keep && index($0, "tag=\"wght\"") > 0) {
                if (match($0, /stylevalue="[0-9]+"/)) {
                    cur = substr($0, RSTART + 12, RLENGTH - 13) + 0
                    if (w >= 0) cur = w
                    v = cur + shift
                    if (v < lo) v = lo
                    if (v > hi) v = hi
                    sub(/stylevalue="[0-9]+"/, "stylevalue=\"" v "\"")
                }
            }
            print
            if (keep && index($0, "</family>") > 0) keep = 0
        }
    ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

# Тот же сдвиг, но для семейства sans-serif в конфигах /system.
# Сдвигается КОПИЯ эталона: иначе операция не идемпотентна и следующий
# запуск уже не сможет вернуть исходные значения.
rewrite_sans() {
    for name in fonts.xml font_fallback.xml; do
        tpl="$MODDIR/templates/$name"
        out="$MODDIR/system/etc/$name"
        [ -f "$tpl" ] || continue
        cp "$tpl" "$out" || continue
        shift_targets "sans-serif" "$out"
    done
}

# --- подмена /product через VFS ------------------------------------------
# Правила не сохраняются на диск: если что-то пойдёт не так, обычная
# перезагрузка возвращает стоковое состояние, ничего чистить не нужно.
serve_product() {
    [ "$(get_unify)" = "1" ] || return 0
    [ -x "$HYBRID" ] || return 0
    tpl="$MODDIR/templates/fonts_customization.xml"
    font="$MODDIR/system/fonts/Roboto-Regular.ttf"
    [ -f "$tpl" ] && [ -f "$font" ] || return 0

    rm -rf "$SERVE"
    mkdir -p "$SERVE" || return 0
    cp "$tpl" "$SERVE/fonts_customization.xml" || return 0
    cp "$font" "$SERVE/GoogleSans-Regular.ttf" || return 0

    shift_targets "google-sans google-sans-medium google-sans-bold google-sans-text google-sans-clock" \
        "$SERVE/fonts_customization.xml"

    # Права и контекст — ПОСЛЕ сдвига. shift_targets перезаписывает файл
    # через mv, и на новом файле метки были бы уже не те: корень и
    # cache_file вместо system. zygote читает из своего SELinux-домена.
    chown -R 1000:1000 "$SERVE" 2>/dev/null
    chmod 0755 "$SERVE"
    chmod 0644 "$SERVE/fonts_customization.xml" "$SERVE/GoogleSans-Regular.ttf"
    chcon u:object_r:system_file:s0 "$SERVE/fonts_customization.xml" \
        "$SERVE/GoogleSans-Regular.ttf" 2>/dev/null

    "$HYBRID" vfs load >/dev/null 2>&1
    "$HYBRID" vfs rule add "$OEM_XML" "$SERVE/fonts_customization.xml" >/dev/null 2>&1
    "$HYBRID" vfs rule add "$PRODUCT_FONTS/GoogleSans-Regular.ttf" \
        "$SERVE/GoogleSans-Regular.ttf" >/dev/null 2>&1
    "$HYBRID" vfs rule add "$PRODUCT_FONTS/GoogleSansClock-Regular.ttf" \
        "$SERVE/GoogleSans-Regular.ttf" >/dev/null 2>&1
}

rewrite_sans
serve_product
