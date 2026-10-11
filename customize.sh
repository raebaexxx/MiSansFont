#!/system/bin/sh
# Установка модуля.

# Установщик Magisk/KernelSU задаёт MODPATH. Если скрипт запущен без него,
# берём каталог скрипта: конструкция ${0%/*} при $0 без слеша возвращает
# сам $0, и . "$MODDIR/common.sh" падает.
if [ -n "$MODPATH" ]; then
    MODDIR="$MODPATH"
else
    MODDIR="${0%/*}"
    [ "$MODDIR" = "$0" ] && MODDIR="."
fi

. "$MODDIR/common.sh"

# Установщик отдаёт эти функции; подстраховка на случай запуска вне него.
command -v ui_print >/dev/null 2>&1 || ui_print() { echo "$1"; }
command -v set_perm_recursive >/dev/null 2>&1 || set_perm_recursive() { :; }

ensure_state

# ГЛАВНОЕ. Файлы, попавшие в модуль через adb, наследуют контекст
# shell_data_file. Magic mount подставляет их в /system с этим контекстом,
# и SELinux запрещает zygote'у читать конфигурацию шрифтов:
#
#   avc: denied { read } for name="fonts.xml" dev="overlay"
#        scontext=u:r:zygote:s0
#   SystemFonts: FileNotFoundException: /system/etc/fonts.xml: EACCES
#
# Дальше FontManagerService падает с NPE в Typeface.create, поток
# SystemServerInitThreadPool не завершается, mServiceStarted.join() висит
# вечно, вотердог убивает SystemServer — и так по кругу. Телефон не
# грузится вообще.
#
# Правильный контекст для файлов в /system — system_file.
chcon -R u:object_r:system_file:s0 "$MODDIR/system" 2>/dev/null
chcon u:object_r:system_file:s0 "$MODDIR/sepolicy.rule" 2>/dev/null

ui_print " "
ui_print "  MiSans System Font"
ui_print "  ---------------------"
ui_print "  MiSans кладётся на место /system/fonts/Roboto-Regular.ttf."
ui_print "  Ни один XML не меняется."
ui_print " "
ui_print "  Затрагиваются sans-serif, roboto, sans-serif-condensed"
ui_print "  и общий запасной шрифт."
ui_print " "
ui_print "  Толщина по умолчанию: +$DEFAULT_WEIGHT (максимум)"
ui_print "  Поменять: кнопка «Действие» у модуля в KernelSU."
ui_print " "
ui_print "  Нужен перезапуск."
ui_print " "

set_perm_recursive "$MODDIR" 0 0 0755 0644
# set_perm_recursive ставит на всё 0644, а скрипты запускаются напрямую
chmod 0755 "$MODDIR"/*.sh 2>/dev/null
# chcon надо повторить после set_perm_recursive, если он сбросил контекст
chcon -R u:object_r:system_file:s0 "$MODDIR/system" 2>/dev/null
