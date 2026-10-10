#!/system/bin/sh
# Общий код модуля MiSans: чтение/запись веса и применение к системе.

STATE_DIR=/data/adb/misans
WEIGHT_FILE="$STATE_DIR/weight"
# 300 = максимум: обычный текст 400+300=700, а 700 упирается в предел оси MiSans.
DEFAULT_WEIGHT=300
MAX_WEIGHT=300

ensure_state() {
    mkdir -p "$STATE_DIR"
    [ -f "$WEIGHT_FILE" ] || echo "$DEFAULT_WEIGHT" > "$WEIGHT_FILE"
    chmod 0644 "$WEIGHT_FILE"
}

get_weight() {
    ensure_state
    cat "$WEIGHT_FILE" 2>/dev/null || echo "$DEFAULT_WEIGHT"
}

set_weight() {
    ensure_state
    echo "$1" > "$WEIGHT_FILE"
    apply_weight "$1"
}

# Раскладывает значение по всем пользователям и будит SystemUI,
# который уже держит старую Configuration.
apply_weight() {
    w="$1"
    for uid in $(pm list users 2>/dev/null | cut -d: -f2 | tr -d ' '); do
        settings --user "$uid" put secure font_weight_adjustment "$w" 2>/dev/null
    done
    sleep 1
    killall com.android.systemui 2>/dev/null
}
