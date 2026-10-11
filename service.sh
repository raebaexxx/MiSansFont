#!/system/bin/sh
# Выполняется на этапе late_start service — уже ПОСЛЕ того, как
# HybridMount/KernelSU смонтировали system/ модулей.
#
# Скрипт обязан возвращаться мгновенно: блокировка здесь означает
# зависание загрузки. Ожидание boot_completed ушло в фон.

if [ -n "$MODPATH" ]; then
    MODDIR="$MODPATH"
else
    MODDIR="${0%/*}"
    [ "$MODDIR" = "$0" ] && MODDIR="."
fi

. "$MODDIR/common.sh"

mkdir -p /data/adb/misans
ensure_state

# КонтекстSELinux. Если файл шрифта не system_file, zygote его не прочтёт
# и FontManagerService уронит SystemServer. Проверяем и чиним.
check_context() {
    ctx=$(ls -Z /system/fonts/Roboto-Regular.ttf 2>/dev/null | awk '{print $NF}')
    [ "$ctx" = "u:object_r:system_file:s0" ] && return 0
    chcon u:object_r:system_file:s0 "$MODDIR/system/fonts/Roboto-Regular.ttf" 2>/dev/null
    echo "контекст был $ctx, исправлен на system_file" > /data/adb/misans/last_error
    return 1
}

try_apply() {
    w=$(get_weight)
    current=$(settings get secure font_weight_adjustment 2>/dev/null)
    [ "$current" = "$w" ] && return 0
    apply_weight "$w"
}

nohup sh -c "
    . $MODDIR/common.sh
    i=0
    while [ \"\$(getprop sys.boot_completed)\" != '1' ] && [ \$i -lt 60 ]; do
        sleep 1
        i=\$((i + 1))
    done
    w=\$(get_weight)
    current=\$(settings get secure font_weight_adjustment 2>/dev/null)
    [ \"\$current\" != \"\$w\" ] && apply_weight \"\$w\"
" >/dev/null 2>&1 &

try_apply
check_context || true
