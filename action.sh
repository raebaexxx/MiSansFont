#!/system/bin/sh
# Кнопка "Действие" в KernelSU: выбор толщины.

if [ -n "$MODPATH" ]; then
    MODDIR="$MODPATH"
else
    MODDIR="${0%/*}"
    [ "$MODDIR" = "$0" ] && MODDIR="."
fi

. "$MODDIR/common.sh"

# Значение, выбранное пользователем. Глобальная, а не stdout:
# stdout меню нельзя отдавать через подстановку команды.
REPLY=''

show_state() {
    w=$(get_weight)
    cur=$(settings get secure font_weight_adjustment 2>/dev/null)
    echo "  сохранено в модуле: +$w"
    echo "  сейчас в системе:  +$cur"
    echo ""
    echo "  MiSans, ось wght 150..700. Значение прибавляется к весу текста:"
    echo "    обычный  400 + $w = $((400 + w))"
    echo "    тонкий   100 + $w = $((100 + w))"
    echo "    средний  500 + $w = $((500 + w))"
    echo "  всё, что выше 700, упрётся в предел оси и станет 700."
    echo ""
}

menu() {
    echo "MiSans — толщина шрифта"
    echo "=========================="
    show_state
    echo "  1)  +0    обычный вид"
    echo "  2)  +50"
    echo "  3)  +100"
    echo "  4)  +150"
    echo "  5)  +200"
    echo "  6)  +250"
    echo "  7)  +300  максимум"
    echo "  8)  вписать значение вручную"
    echo "  0)  выход"
    printf "  выбери: "
}

# Крутит меню, пока не выберут значение или не выйдут.
ask() {
    REPLY=''
    while :; do
        menu
        read -r c
        case "$c" in
            0|'') return 1 ;;
            1) v=0 ;;
            2) v=50 ;;
            3) v=100 ;;
            4) v=150 ;;
            5) v=200 ;;
            6) v=250 ;;
            7) v=300 ;;
            8)
                printf "  значение (0..%s): " "$MAX_WEIGHT"
                read -r v
                ;;
            *) echo "  нет такого варианта"; continue ;;
        esac
        case "$v" in
            ''|*[!0-9]*)
                echo "  нужно целое число"
                continue
                ;;
        esac
        if [ "$v" -gt "$MAX_WEIGHT" ]; then
            echo "  больше $MAX_WEIGHT бессмысленно: ось MiSans кончается на 700"
            continue
        fi
        REPLY=$v
        return 0
    done
}

if [ "$1" = "set" ]; then
    # вызов извне: action.sh set <значение>
    set_weight "$2"
    echo "  вес: +$(get_weight)"
    exit 0
fi

if ask; then
    set_weight "$REPLY"
    echo "  применено: +$REPLY, SystemUI перезапущен"
    show_state
    echo "  Толщина видна сразу. Сам шрифт целиком меняется при перезагрузке."
fi

echo ""
