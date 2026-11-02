# openMSX script: from the first hit of HQ_FROM logs the PC of every
# instruction executed outside the runtime (page 0) until HQ_COUNT lines.
set throttle off
set ::hq_log [open $::env(HQ_OUT) w]
set ::hq_n 0
set ::hq_last -1
proc hq_start {} {
    debug set_condition {[reg pc] >= 0x4000 || [reg pc] < 0x60} {hq_step}
}
proc hq_step {} {
    set pc [reg pc]
    if {$pc == $::hq_last} { return }
    set ::hq_last $pc
    incr ::hq_n
    puts $::hq_log [format "%04X sp=%04X a=%02X bc=%04X de=%04X hl=%04X" $pc [reg sp] [reg a] [reg bc] [reg de] [reg hl]]
    if {$::hq_n >= $::env(HQ_COUNT)} { close $::hq_log; exit }
}
debug set_bp 0x$::env(HQ_FROM) {} {hq_start}
after time 40 { close $::hq_log; exit }
