#!/system/bin/sh
# Установка модуля. Кладём начальное значение толщины.

# Установщик задаёт MODPATH. Если скрипт запущен без него, берём каталог скрипта.
# Конструкция ${0%/*} при $0 без слеша возвращает сам $0, поэтому отдельно
# обрабатываем этот случай — иначе получится . "customize.sh/common.sh".
if [ -n "$MODPATH" ]; then
    MODDIR="$MODPATH"
else
    MODDIR="${0%/*}"
    [ "$MODDIR" = "$0" ] && MODDIR="."
fi

. "$MODDIR/common.sh"

# Установщик Magisk/KernelSU отдаёт эти функции. Подстраховка на случай запуска
# вне установщика: если функции уже есть, ничего не переопределяем.
command -v ui_print >/dev/null 2>&1 || ui_print() { echo "$1"; }
command -v set_perm_recursive >/dev/null 2>&1 || set_perm_recursive() { :; }

ensure_state

ui_print " "
ui_print "  MiSans System Font"
ui_print "  ---------------------"
ui_print "  sans-serif и его варианты переводятся на MiSans."
ui_print "  Заголовки и часы (google-sans*) — алиасы на тот же MiSans."
ui_print "  monospace, condensed и smallcaps не тронуты:"
ui_print "  у MiSans нет оси wdth и нет моноширинного начертания."
ui_print " "
ui_print "  Толщина по умолчанию: +$DEFAULT_WEIGHT (максимум)"
ui_print "  Поменять: кнопка «Действие» у модуля в KernelSU."
ui_print " "
ui_print "  Шрифт применится после перезагрузки."
ui_print " "

set_perm_recursive "$MODDIR" 0 0 0755 0644
# set_perm_recursive ставит на всё 0644, а скрипты запускаются напрямую
chmod 0755 "$MODDIR"/*.sh 2>/dev/null
