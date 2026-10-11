#!/system/bin/sh
# Shared state and helpers.

# Weight is a shift written into the font configuration rather than
# Settings.Secure.FONT_WEIGHT_ADJUSTMENT. The setting is applied only in
# TextView.setTypeface(), so apps that pick a font outside that path never see
# it, and it can only add weight — on top of an existing shift the slider
# cannot go lower. A shift in the XML reaches everyone and gives the full range.

# The shift is applied by post-fs-data.sh, which runs before modules are mounted.

STATE_DIR=/data/adb/misans
SHIFT_FILE="$STATE_DIR/shift"
UNIFY_FILE="$STATE_DIR/unify"

DEFAULT_SHIFT=300
MAX_SHIFT=300

# Substitute /product through VFS rules: 1 on, 0 off.
# Off is a full escape hatch — it touches the interface, not just apps, and the
# only way back is a reboot.
DEFAULT_UNIFY=1

ensure_state() {
    mkdir -p "$STATE_DIR"
    [ -f "$SHIFT_FILE" ] || echo "$DEFAULT_SHIFT" > "$SHIFT_FILE"
    [ -f "$UNIFY_FILE" ] || echo "$DEFAULT_UNIFY" > "$UNIFY_FILE"
    chmod 0644 "$SHIFT_FILE" "$UNIFY_FILE"
}

get_shift() {
    ensure_state
    cat "$SHIFT_FILE" 2>/dev/null || echo "$DEFAULT_SHIFT"
}

set_shift() {
    ensure_state
    echo "$1" > "$SHIFT_FILE"
}

get_unify() {
    ensure_state
    cat "$UNIFY_FILE" 2>/dev/null || echo "$DEFAULT_UNIFY"
}

set_unify() {
    ensure_state
    echo "$1" > "$UNIFY_FILE"
}

# Resulting axis value, clamped to what MiSans actually has.
axis_of() {
    w=$(( $1 + $2 ))
    [ "$w" -lt 150 ] && w=150
    [ "$w" -gt 700 ] && w=700
    echo "$w"
}
