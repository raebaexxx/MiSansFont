#!/system/bin/sh
# Применяет сохранённый сдвиг веса к конфигам модуля.
#
# Скрипт выполняется на этапе post-fs-data, то есть ДО того, как metamodule
# смонтирует system/ модулей. Значит конфиги здесь ещё можно править:
# монтирование подхватит уже изменённые файлы. Именно поэтому проверять
# оверлей здесь бессмысленно (его ещё нет), а перегенерация — в самый раз.

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
#
# Правим КОПИЮ эталона, а не сам конфиг. Иначе операция не идемпотентна:
# сдвиг 300 записался бы поверх файла, и следующий запуск с нулем уже не
# смог бы вернуть исходные значения.
rewrite() {
    src="$1"
    dst="$2"
    awk -v shift="$SHIFT" -v lo="$MIN_AXIS" -v hi="$MAX_AXIS" '
        /<family name="sans-serif">/ { inblock = 1 }
        inblock && /<font / {
            w = 0
            if (match($0, /weight="[0-9]+"/)) {
                w = substr($0, RSTART + 8, RLENGTH - 9) + 0
            }
        }
        inblock && /tag="wght"/ {
            if (match($0, /stylevalue="[0-9]+"/)) {
                n = w + shift
                if (n < lo) n = lo
                if (n > hi) n = hi
                sub(/stylevalue="[0-9]+"/, "stylevalue=\"" n "\"")
            }
        }
        { print }
        inblock && /<\/family>/ { inblock = 0 }
    ' "$src" > "$dst.tmp" && mv "$dst.tmp" "$dst"
}

for name in fonts.xml font_fallback.xml; do
    tpl="$MODDIR/templates/$name"
    out="$MODDIR/system/etc/$name"
    [ -f "$tpl" ] || continue
    rewrite "$tpl" "$out"
done
