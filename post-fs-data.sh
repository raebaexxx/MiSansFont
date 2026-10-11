#!/system/bin/sh
# Applies the weight shift and substitutes /product through VFS rules.
#
# Runs at post-fs-data, before zygote reads the font configuration. Checking
# the overlay here would be pointless — it does not exist yet — but replacing
# /product files is exactly right here.
#
# Why /product matters: PixelOS keeps the google-sans* override in
# /product/etc/fonts_customization.xml, and FontListParser drops same-named
# families from /system/etc/fonts.xml:
#
#   if (!oemNamedFamilies.containsKey(name)) {
#       // The OEM customization overrides system named family.
#
# The interface asks for config_bodyFontFamily = google-sans-text (the RRO
# overlay is in /product too), so without this the shift never reaches it.
#
# A module cannot overlay /product the usual way: extra_mount in HybridMount
# requires no matching /system entry, and /system/product is a symlink. VFS
# rules redirect paths in the kernel and are not subject to that check.
#
# NOTE: a compound awk pattern such as "cond && /re/ { }" is rejected by some
# awk builds (gawk 5.4.1 on the build host). Every condition below is an if.

MODDIR=${0%/*}
[ -z "$MODPATH" ] && [ "$MODDIR" = "$0" ] && MODDIR="."
[ -n "$MODPATH" ] && MODDIR="$MODPATH"

. "$MODDIR/common.sh"

STATE=/data/adb/misans
SHIFT_FILE="$STATE/shift"
UNIFY_FILE="$STATE/unify"
MIN_AXIS=150
MAX_AXIS=700

# Where the substituted files live. /data/adb is unreachable for zygote while
# /data/cache belongs to system: root writes, zygote reads.
SERVE=/data/cache/misans

HYBRID=/data/adb/modules/hybrid_mount/hybrid-mount
PRODUCT_FONTS=/product/fonts
OEM_XML=/product/etc/fonts_customization.xml

SHIFT=$(cat "$SHIFT_FILE" 2>/dev/null)
case "$SHIFT" in
    ''|*[!0-9]*) SHIFT=0 ;;
esac
[ "$SHIFT" -gt 300 ] && SHIFT=300

# Adds the shift to wght inside the named families. The weight comes from the
# weight attribute of the same <font>: faces are declared explicitly, so it is
# the axis value that has to move, not the face index.
shift_targets() {
    list="$1"
    file="$2"
    awk -v shift="$SHIFT" -v lo="$MIN_AXIS" -v hi="$MAX_AXIS" -v names="$list" '
        BEGIN {
            n = split(names, want, " ")
            for (i = 1; i <= n; i++) targets[want[i]] = 1
        }
        {
            if (match($0, /<family [^>]*name="[^"]+"/)) {
                seg = substr($0, RSTART, RLENGTH)
                if (match(seg, /name="[^"]+"/)) {
                    fname = substr(seg, RSTART + 6, RLENGTH - 7)
                    if (fname in targets) keep = 1
                    else keep = 0
                }
            }
            if (keep && index($0, "<font") > 0) {
                # -1 means the face has no weight attribute. The clock is
                # written that way, as a bare <font>; the existing axis value
                # is used instead, otherwise w leaks from the previous family.
                w = -1
                if (match($0, /weight="[0-9]+"/)) {
                    w = substr($0, RSTART + 8, RLENGTH - 9) + 0
                }
            }
            if (keep && index($0, "tag=\"wght\"") > 0) {
                if (match($0, /stylevalue="[0-9]+"/)) {
                    cur = substr($0, RSTART + 12, RLENGTH - 13) + 0
                    if (w >= 0) cur = w
                    v = cur + shift
                    if (v < lo) v = lo
                    if (v > hi) v = hi
                    sub(/stylevalue="[0-9]+"/, "stylevalue=\"" v "\"")
                }
            }
            print
            if (keep && index($0, "</family>") > 0) keep = 0
        }
    ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

# Same shift, selected by file rather than by family name. Needed for the OEM
# config: the interface asks for variable-*, which is 18 families. Listing them
# by hand would mean forgetting a new one, as v5.0 did. A face is recognised by
# the file named in its <font> tag.
shift_by_file() {
    name="$1"
    file="$2"
    awk -v shift="$SHIFT" -v lo="$MIN_AXIS" -v hi="$MAX_AXIS" -v name="$name" '
        {
            if (index($0, name) > 0) {
                w = -1
                if (match($0, /weight="[0-9]+"/)) {
                    w = substr($0, RSTART + 8, RLENGTH - 9) + 0
                }
                pend = 1
            }
            if (pend && index($0, "tag=\"wght\"") > 0) {
                if (match($0, /stylevalue="[0-9]+"/)) {
                    cur = substr($0, RSTART + 12, RLENGTH - 13) + 0
                    if (w >= 0) cur = w
                    v = cur + shift
                    if (v < lo) v = lo
                    if (v > hi) v = hi
                    sub(/stylevalue="[0-9]+"/, "stylevalue=\"" v "\"")
                }
                pend = 0
            }
            print
        }
    ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

# The same shift for sans-serif in the /system configs. A COPY of the template
# is shifted: editing the template in place is not idempotent and the next boot
# could no longer restore the original values.
rewrite_sans() {
    for name in fonts.xml font_fallback.xml; do
        tpl="$MODDIR/templates/$name"
        out="$MODDIR/system/etc/$name"
        [ -f "$tpl" ] || continue
        cp "$tpl" "$out" || continue
        shift_targets "sans-serif" "$out"
    done
}

# --- /product substitution via VFS ----------------------------------------
# Rules are runtime-only and never written to disk: if anything goes wrong, a
# plain reboot restores stock state and there is nothing to clean up.
serve_product() {
    [ "$(get_unify)" = "1" ] || return 0
    [ -x "$HYBRID" ] || return 0
    tpl="$MODDIR/templates/fonts_customization.xml"
    font="$MODDIR/system/fonts/Roboto-Regular.ttf"
    [ -f "$tpl" ] && [ -f "$font" ] || return 0

    rm -rf "$SERVE"
    mkdir -p "$SERVE" || return 0
    cp "$tpl" "$SERVE/fonts_customization.xml" || return 0
    cp "$font" "$SERVE/GoogleSans-Regular.ttf" || return 0

    shift_by_file "GoogleSans-Regular.ttf" "$SERVE/fonts_customization.xml"

    # Ownership and context go AFTER the shift. shift_by_file rewrites the file
    # through mv, and the new file would otherwise be root-owned and cache_file
    # instead of system_file. zygote reads it from its own SELinux domain.
    chown -R 1000:1000 "$SERVE" 2>/dev/null
    chmod 0755 "$SERVE"
    chmod 0644 "$SERVE/fonts_customization.xml" "$SERVE/GoogleSans-Regular.ttf"
    chcon u:object_r:system_file:s0 "$SERVE/fonts_customization.xml" \
        "$SERVE/GoogleSans-Regular.ttf" 2>/dev/null

    "$HYBRID" vfs load >/dev/null 2>&1
    "$HYBRID" vfs rule add "$OEM_XML" "$SERVE/fonts_customization.xml" >/dev/null 2>&1
    for f in GoogleSans-Regular.ttf GoogleSansFlex-Regular.ttf GoogleSansClock-Regular.ttf; do
        "$HYBRID" vfs rule add "$PRODUCT_FONTS/$f" "$SERVE/GoogleSans-Regular.ttf" \
            >/dev/null 2>&1
    done
}

rewrite_sans
serve_product
