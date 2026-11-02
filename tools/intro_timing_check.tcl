# Full intro timing checks at 50/60 Hz, sourced by check_modes.py.
set ::timing [open "${out}.timing" w]
proc timing_symbols {path} {
    set f [open $path]
    while {[gets $f line] >= 0} {
        if {[regexp {^(\w+): equ ([0-9A-Fa-f]+)h} $line -> name value]} {
            set ::isym($name) [expr "0x$value"]
        }
    }
    close $f
}
timing_symbols build/intro.sym
timing_symbols build/runtime.sym
set ::wait_start -1
set ::waits 0
proc timing_wait {} {
    set ::wait_start [machine_info time]
    set ::wait_ticks [reg b]
}
proc timing_next {} {
    if {$::wait_start < 0} { return }
    set elapsed [expr {[machine_info time]-$::wait_start}]
    puts $::timing [format "wait %d ticks %.6f seconds" $::wait_ticks $elapsed]
    flush $::timing
    if {abs($elapsed - $::wait_ticks/50.0) > 0.04} { error "intro wait is not timed at 50 Hz" }
    set ::wait_start -1
    incr ::waits
}
proc timing_begin {} {
    puts $::timing "music starts [machine_info time] 60hz=[peek 0x68]"
    flush $::timing
}
proc timing_end {} {
    puts $::timing "intro ends [machine_info time], waits=$::waits opl4-playing=[peek 0x6C]"
    close $::timing
    hq_report
}
proc timing_arm_intro {} {
    debug set_bp $::isym(in_pause) {[peek16 [reg sp]] == $::isym(in_next) && $::wait_start < 0} timing_wait
    debug set_bp $::isym(in_next) {} timing_next
    debug set_bp $::isym(in_start_music) {} timing_begin
    debug set_bp $::isym(in_end) {} timing_end
}
debug set_bp $::isym(rt_boot_intro) {} timing_arm_intro
