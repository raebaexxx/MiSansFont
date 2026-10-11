#!/system/bin/sh
# Prints state, or applies a setting. No interactive menu: KernelSU gives the
# script no terminal, so `read` blocks forever.
#
#   su -c 'sh /data/adb/modules/misans/action.sh set 150'
#   su -c 'sh /data/adb/modules/misans/action.sh unify off'
#   su -c 'sh /data/adb/modules/misans/action.sh'

MODDIR=${0%/*}
[ -z "$MODPATH" ] && [ "$MODDIR" = "$0" ] && MODDIR="."
[ -n "$MODPATH" ] && MODDIR="$MODPATH"

. "$MODDIR/common.sh"

show() {
    s=$(get_shift)
    u=$(get_unify)
    echo "  shift: +$s"
    if [ "$u" = "1" ]; then
        echo "  system interface: MiSans"
    else
        echo "  system interface: Google Sans"
    fi
    echo ""
    echo "  regular 400 -> $(axis_of 400 "$s")"
    echo "  light   100 -> $(axis_of 100 "$s")"
    echo "  bold    700 -> $(axis_of 700 "$s")"
    echo ""
}

case "$1" in
    set)
        case "$2" in
            ''|*[!0-9]*) echo "need an integer 0..$MAX_SHIFT"; exit 1 ;;
        esac
        if [ "$2" -gt "$MAX_SHIFT" ]; then
            echo "$MAX_SHIFT is the maximum: the MiSans wght axis ends at 700"
            exit 1
        fi
        set_shift "$2"
        echo "shift saved: +$(get_shift)"
        echo "takes effect after a reboot"
        exit 0
        ;;
    unify)
        case "$2" in
            on|1)
                set_unify 1
                echo "interface substitution on"
                ;;
            off|0)
                set_unify 0
                echo "interface substitution off"
                ;;
            *)
                [ "$(get_unify)" = "1" ] && echo "on" || echo "off"
                echo "usage: action.sh unify on|off"
                exit 1
                ;;
        esac
        echo "takes effect after a reboot"
        exit 0
        ;;
    *)
        show
        echo "  Web UI: KernelSU -> MiSans System Font -> web UI."
        echo ""
        echo "  From a shell:"
        echo "    su -c 'sh /data/adb/modules/misans/action.sh set 150'"
        echo ""
        ;;
esac
