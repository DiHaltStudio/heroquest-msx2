# openMSX script: logs the first hits of key addresses during boot.
# Environment: HQ_OUT (log file), HQ_ADDRS (hex addresses, space separated).
set throttle off
set ::hq_log [open $::env(HQ_OUT) w]
set ::hq_n 0
proc hq_hit {name} {
    incr ::hq_n
    puts $::hq_log [format "%-6s pc=%04X sp=%04X af=%04X bc=%04X de=%04X hl=%04X slots=%02X bank=%02X (sp)=%04X t=%.3f" \
        $name [reg pc] [reg sp] [reg af] [reg bc] [reg de] [reg hl] \
        [debug read ioports 0xA8] [peek 0x52] [peek16 [reg sp]] [machine_info time]]
    flush $::hq_log
    if {$::hq_n > 200} { close $::hq_log; exit }
}
foreach a $::env(HQ_ADDRS) {
    debug set_bp 0x$a {} "hq_hit $a"
}
after time 30 { close $::hq_log; exit }
