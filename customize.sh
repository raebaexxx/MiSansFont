#!/system/bin/sh
# Установка модуля. Кладём начальное значение толщины.

MODDIR=${0%/*}
. "$MODDIR/common.sh"

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
