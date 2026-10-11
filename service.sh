#!/system/bin/sh
# Late-start check. The shift itself is applied in post-fs-data.sh.
#
# This only repairs the SELinux context. If the font file is not system_file,
# zygote cannot read the font configuration and FontManagerService takes
# SystemServer down with it, so the check stays.

if [ -n "$MODPATH" ]; then
    MODDIR="$MODPATH"
else
    MODDIR="${0%/*}"
    [ "$MODDIR" = "$0" ] && MODDIR="."
fi

. "$MODDIR/common.sh"

mkdir -p /data/adb/misans

want=u:object_r:system_file:s0
got=$(ls -Z /system/fonts/Roboto-Regular.ttf 2>/dev/null | awk '{print $NF}')
if [ "$got" != "$want" ]; then
    chcon "$want" "$MODDIR/system/fonts/Roboto-Regular.ttf" 2>/dev/null
    echo "font context was ${got:-unknown}, set to system_file" \
        > /data/adb/misans/last_error
fi
