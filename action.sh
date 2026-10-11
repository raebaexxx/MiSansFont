#!/system/bin/sh
# Состояние и установка сдвига. Интерактивное меню здесь не работает:
# KernelSU не выдаёт скрипту терминал на ввод, поэтому read зависает.
#
#   su -c 'sh /data/adb/modules/misans/action.sh set 150'   # затем перезагрузка
#   su -c 'sh /data/adb/modules/misans/action.sh'           # только показать

MODDIR=${0%/*}
[ -z "$MODPATH" ] && [ "$MODDIR" = "$0" ] && MODDIR="."
[ -n "$MODPATH" ] && MODDIR="$MODPATH"

. "$MODDIR/common.sh"

show() {
    s=$(get_shift)
    echo "  сдвиг: +$s"
    echo ""
    echo "  обычный 400 -> $(axis_of 400 "$s")"
    echo "  тонкий  100 -> $(axis_of 100 "$s")"
    echo "  жирный  700 -> $(axis_of 700 "$s")"
    echo ""
}

case "$1" in
    set)
        case "$2" in
            ''|*[!0-9]*) echo "нужно целое число 0..$MAX_SHIFT"; exit 1 ;;
        esac
        if [ "$2" -gt "$MAX_SHIFT" ]; then
            echo "больше $MAX_SHIFT бессмысленно: ось MiSans кончается на 700"
            exit 1
        fi
        set_shift "$2"
        echo "сдвиг сохранён: +$(get_shift)"
        echo "применится после перезагрузки"
        exit 0
        ;;
    *)
        show
        echo "  Ползунок — в WebUI модуля: KernelSU -> MiSans -> веб-интерфейс."
        echo ""
        echo "  Из консоли:"
        echo "    su -c 'sh /data/adb/modules/misans/action.sh set 150'"
        echo ""
        ;;
esac
