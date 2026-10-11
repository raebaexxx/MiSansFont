#!/system/bin/sh
# Управление толщиной. Интерактивное меню здесь не работает: KernelSU
# не выдаёт скрипту терминал на ввод, поэтому `read` виснет.
# Управление живёт в WebUI модуля (webroot/index.html), а этот скрипт —
# только приёмник команды оттуда и запасной вариант из консоли.
#
#   su -c 'sh /data/adb/modules/misans/action.sh set 150'

MODDIR=${0%/*}
[ -z "$MODPATH" ] && [ "$MODDIR" = "$0" ] && MODDIR="."
[ -n "$MODPATH" ] && MODDIR="$MODPATH"

. "$MODDIR/common.sh"

show() {
    w=$(get_weight)
    cur=$(settings get secure font_weight_adjustment 2>/dev/null)
    echo "  в модуле: +$w"
    echo "  в системе: +$cur"
    echo ""
    echo "  обычный 400 + $w = $((400 + w))"
    echo "  тонкий  100 + $w = $((100 + w))"
    echo "  жирный  700 + $w = $((700 + w))"
    echo "  всё, что выше 700, упирается в предел оси MiSans."
}

case "$1" in
    set)
        case "$2" in
            ''|*[!0-9]*) echo "нужно целое число 0..$MAX_WEIGHT"; exit 1 ;;
        esac
        if [ "$2" -gt "$MAX_WEIGHT" ]; then
            echo "больше $MAX_WEIGHT бессмысленно: ось MiSans кончается на 700"
            exit 1
        fi
        set_weight "$2"
        echo "толщина: +$(get_weight), SystemUI перезапущен"
        exit 0
        ;;
    *)
        show
        echo ""
        echo "  Управление ползунком — в WebUI модуля: открой KernelSU,"
        echo "  нажми на модуль MiSans и выбери веб-интерфейс."
        echo ""
        echo "  Из консоли:"
        echo "    su -c 'sh /data/adb/modules/misans/action.sh set 150'"
        echo ""
        ;;
esac
