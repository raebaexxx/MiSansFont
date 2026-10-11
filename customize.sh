#!/system/bin/sh
# Installer.

# Magisk/KernelSU set MODPATH. Without it, fall back to the script directory:
# ${0%/*} returns $0 unchanged when there is no slash, and sourcing
# common.sh from the current directory would fail.
if [ -n "$MODPATH" ]; then
    MODDIR="$MODPATH"
else
    MODDIR="${0%/*}"
    [ "$MODDIR" = "$0" ] && MODDIR="."
fi

. "$MODDIR/common.sh"

# Provided by the installer; stubbed so this also runs outside it.
command -v ui_print >/dev/null 2>&1 || ui_print() { echo "$1"; }
command -v set_perm_recursive >/dev/null 2>&1 || set_perm_recursive() { :; }

ensure_state

# Everything shipped in /system must be system_file. Files pushed over adb keep
# shell_data_file, magic mount serves them with that context, and zygote then
# cannot read the font configuration:
#
#   avc:  denied { read } for name="fonts.xml" dev="overlay"
#         scontext=u:r:zygote:s0
#   SystemFonts: FileNotFoundException: /system/etc/fonts.xml: EACCES
#
# FontManagerService_create then fails with an NPE, SystemServerInitThreadPool
# never completes, mServiceStarted.join() blocks forever and the watchdog kills
# SystemServer in a loop. The device does not boot at all.
chcon -R u:object_r:system_file:s0 "$MODDIR/system" 2>/dev/null
chcon u:object_r:system_file:s0 "$MODDIR/sepolicy.rule" 2>/dev/null

ui_print " "
ui_print "  MiSans System Font"
ui_print "  ---------------------"
ui_print "  MiSans replaces /system/fonts/Roboto-Regular.ttf, so sans-serif,"
ui_print "  roboto, sans-serif-condensed and the system fallback all follow."
ui_print " "
if [ "$(get_unify)" = "1" ]; then
    ui_print "  The PixelOS interface and the status bar clock are switched to"
    ui_print "  MiSans too, via VFS rules in /product. Requires HybridMount."
    ui_print "  Turn off later with: action.sh unify off"
else
    ui_print "  Interface substitution is off — the interface stays Google Sans."
fi
ui_print " "
ui_print "  Default weight shift: +$(get_shift)"
ui_print "  Change it in the module web UI. A reboot is required."
ui_print " "

set_perm_recursive "$MODDIR" 0 0 0755 0644
# set_perm_recursive applies 0644 to everything, but the scripts are executed.
chmod 0755 "$MODDIR"/*.sh 2>/dev/null
# Re-apply in case set_perm_recursive reset the context.
chcon -R u:object_r:system_file:s0 "$MODDIR/system" 2>/dev/null
