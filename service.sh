#!/system/bin/sh
# Применение сдвига — в post-fs-data.sh, до монтирования.
#
# Здесь только проверка контекста SELinux: если файл шрифта не system_file,
# zygote не прочтёт конфигурацию и FontManagerService уронит SystemServer.
# Этот сценарий однажды ломал загрузку телефона, поэтому проверка нужна.

if [ -n "$MODPATH" ]; then
    MODDIR="$MODPATH"
else
    MODDIR="${0%/*}"
    [ "$MODDIR" = "$0" ] && MODDIR="."
fi

. "$MODDIR/common.sh"

mkdir -p /data/adb/misans

fix_context() {
    want=u:object_r:system_file:s0
    got=$(ls -Z /system/fonts/Roboto-Regular.ttf 2>/dev/null | awk '{print $NF}')
    [ "$got" = "$want" ] && return 0
    chcon "$want" "$MODDIR/system/fonts/Roboto-Regular.ttf" 2>/dev/null
    echo "контекст шрифта был ${got:-неизвестен}, исправлен на system_file" \
        > /data/adb/misans/last_error
    return 1
}

fix_context || true
