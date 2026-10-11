#!/system/bin/sh
# Общий код модуля MiSans.
#
# Толщина задаётся сдвигом веса в конфигурации, а не настройкой
# Settings.Secure.FONT_WEIGHT_ADJUSTMENT. Настройка работает не везде:
# приложения, задающие шрифт мимо TextView.setTypeface(), её не видят,
# и нижняя граница ползунка не опускается ниже того, что уже задано в XML.
#
# Сдвиг применяется в post-fs-data.sh, который выполняется ДО монтирования
# system/ модулей, поэтому конфиги успевают переписаться.

STATE_DIR=/data/adb/misans
SHIFT_FILE="$STATE_DIR/shift"

# 300 = обычный текст рисуется как 700, потолок оси MiSans.
DEFAULT_SHIFT=300
MAX_SHIFT=300

ensure_state() {
    mkdir -p "$STATE_DIR"
    [ -f "$SHIFT_FILE" ] || echo "$DEFAULT_SHIFT" > "$SHIFT_FILE"
    chmod 0644 "$SHIFT_FILE"
}

get_shift() {
    ensure_state
    cat "$SHIFT_FILE" 2>/dev/null || echo "$DEFAULT_SHIFT"
}

set_shift() {
    ensure_state
    echo "$1" > "$SHIFT_FILE"
}

# Чему соответствует сдвиг в оси MiSans.
axis_of() {
    w=$(( $1 + $2 ))
    [ "$w" -lt 150 ] && w=150
    [ "$w" -gt 700 ] && w=700
    echo "$w"
}
