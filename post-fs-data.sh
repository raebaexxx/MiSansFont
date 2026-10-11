#!/system/bin/sh
# Применяет сохранённый сдвиг веса к конфигам модуля.
#
# Скрипт выполняется на этапе post-fs-data, то есть ДО того, как metamodule
# смонтирует system/ модулей. Значит конфиги можно править здесь: монтирование
# подхватит уже изменённые файлы. Именно поэтому проверка оверлея здесь же
# была бы бессмысленной, а перегенерация — в самый раз.

MODDIR=${0%/*}
[ -z "$MODPATH" ] && [ "$MODDIR" = "$0" ] && MODDIR="."
[ -n "$MODPATH" ] && MODDIR="$MODPATH"

STATE=/data/adb/misans
SHIFT_FILE="$STATE/shift"
MIN_AXIS=150
MAX_AXIS=700

SHIFT=$(cat "$SHIFT_FILE" 2>/dev/null)
case "$SHIFT" in
    ''|*[!0-9]*) SHIFT=0 ;;
esac
[ "$SHIFT" -gt 300 ] && SHIFT=300

# Переписывает <axis tag="wght" stylevalue="N"/> внутри семейства sans-serif,
# прибавляя сдвиг и зажимая в пределы оси MiSans. Вес берётся из атрибута
# weight того же элемента <font>: начертания в конфиге объявлены явно,
# поэтому сдвигать нужно именно его значение.
shift_one() {
    awk -v shift="$SHIFT" -v lo="$MIN_AXIS" -v hi="$MAX_AXIS" '
        /<family name="sans-serif">/ { inblock = 1 }
        inblock && /<font / {
            w = 0
            if (match($0, /weight="[0-9]+"/)) {
                v = substr($0, RSTART + 8, RLENGTH - 9)
                w = v + 0
            }
        }
        inblock && /stylevalue="[0-9]+"/ {
            old = 0
            if (match($0, /stylevalue="[0-9]+"/)) {
                old = substr($0, RSTART + 12, RLENGTH - 13) + 0
            }
            if ($0 ~ /tag="wght"/) {
                n = w + shift
                if (n < lo) n = lo
                if (n > hi) n = hi
                sub(/stylevalue="[0-9]+"/, "stylevalue=\"" n "\"")
            }
        }
        { print }
        inblock && /<\/family>/ { inblock = 0 }
    ' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
}

if [ "$SHIFT" != "0" ]; then
    for f in "$MODDIR/system/etc/fonts.xml" "$MODDIR/system/etc/font_fallback.xml"; do
        [ -f "$f" ] && shift_one "$f"
    done
fi
