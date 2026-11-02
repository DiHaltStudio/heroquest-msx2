# openMSX script: replays an .omr recorded with the current ROM and logs
# every hit of the addresses in HQ_ADDRS (hex, with an optional name after a
# colon) with the time and a few registers. Environment: HQ_OMR, HQ_OUT,
# HQ_ADDRS, HQ_FROM (seconds: log only after this time, default 0).
set throttle off
set ::hq_log [open $::env(HQ_OUT) w]
set ::hq_from 0
if {[info exists ::env(HQ_FROM)]} { set ::hq_from $::env(HQ_FROM) }
proc hq_hit {name} {
    if {[machine_info time] < $::hq_from} { return }
    puts $::hq_log [format "%8.3f %-14s ix=%04X hl=%04X de=%04X a=%02X sp=%04X ret=%04X frozen=%02X redraw=%02X" \
        [machine_info time] $name [reg ix] [reg hl] [reg de] [reg a] [reg sp] [peek16 [reg sp]] [peek 0xA989] [peek 0xA987]]
}
reverse loadreplay -viewonly $::env(HQ_OMR)
foreach a $::env(HQ_ADDRS) {
    set p [split $a :]
    set name [expr {[llength $p] > 1 ? [lindex $p 1] : [lindex $p 0]}]
    debug set_bp 0x[lindex $p 0] {} "hq_hit $name"
}
proc hq_poll {} {
    set st [reverse status]
    if {[machine_info time] >= [dict get $st end] - 0.05} {
        close $::hq_log
        exit
    }
    after time 1 hq_poll
}
after time 1 hq_poll
