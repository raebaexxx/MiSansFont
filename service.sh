#!/system/bin/sh
# Применяет вес при загрузке. Файлы шрифта монтирует magic mount сам,
# к началу работы zygote, поэтому дополнительных действий не нужно.

MODDIR=${0%/*}
. "$MODDIR/common.sh"

ensure_state

w=$(get_weight)
current=$(settings get secure font_weight_adjustment 2>/dev/null)

if [ "$current" != "$w" ]; then
    apply_weight "$w"
fi
