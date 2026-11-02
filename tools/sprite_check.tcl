# openMSX script: invariant check of the sprite renderer during a scripted run.
# Every 0.05 s of emulated time, when no VDP command is running: every sprite
# of the "on screen" list must differ somewhere from the scene page; and the
# game's active sprite records are logged when none is on the screen.
# Environment: HQ_OUT (log), HQ_SECS, HQ_KEYS as in boot_test.tcl, HQ_SYM.
set throttle off
set ::lg [open $::env(HQ_OUT) w]
# addresses of the runtime variables, read from build/runtime.sym (HQ_SYM)
proc hq_sym {name} {
    set f [open $::env(HQ_SYM)]
    set v ""
    while {[gets $f line] >= 0} {
        if {[regexp "^${name}: equ 0000(....)h" $line -> v]} { break }
    }
    close $f
    return 0x$v
}
set ::SHOWN [hq_sym rt_spr_shown]
set ::OLD [hq_sym rt_cache_old]
set ::PENDING [hq_sym rt_spr_pending]
set ::DIRTY [hq_sym rt_dirty]
proc hq_key {row mask hold} { keymatrixdown $row $mask; after time $hold "keymatrixup $row $mask" }
array set names {space {8 1} left {8 16} up {8 32} down {8 64} right {8 128}}
foreach {t k} $::env(HQ_KEYS) {
    set hold 0.3
    if {[regexp {^(.*)/(.*)$} $k -> k hold]} {}
    set rm $names($k)
    after time $t "hq_key [lindex $rm 0] [lindex $rm 1] $hold"
}
proc active_slots {} {
    set n 0
    for {set i 0} {$i < 14} {incr i} { if {[peek [expr {0x6A8E + 18*$i}]] != 0} { incr n } }
    return $n
}
set ::nchk 0
set ::nspr 0
proc check {} {
    after time 0.05 check
    if {[peek 0x0038] != 0xF5} { return }
    if {[debug read {VDP status regs} 2] & 1} { return }
    incr ::nchk
    set shown [peek $::SHOWN]
    set n [peek $::OLD]
    set frozen [peek 0xA989]
    set act [active_slots]
    set t [format %.2f [machine_info time]]
    if {$shown && $n > 0} {
        for {set i 0} {$i < $n} {incr i} {
            incr ::nspr
            set b [expr {$::OLD + 1 + 7*$i}]
            set x [peek $b]; set y [peek [expr {$b+1}]]; set w [peek [expr {$b+2}]]; set h [peek [expr {$b+3}]]
            set same 1
            for {set yy 0} {$yy < $h && $same} {incr yy 3} {
                set a0 [expr {($y+$yy)*128 + $x/2}]
                set r0 [debug read_block VRAM $a0 [expr {$w/2}]]
                set r1 [debug read_block VRAM [expr {$a0 + 0x8000}] [expr {$w/2}]]
                if {$r0 ne $r1} { set same 0 }
            }
            if {$same} { puts $::lg "$t MISSING sprite $i of $n at x=$x y=$y w=$w h=$h frozen=$frozen" }
        }
    } elseif {$act > 0 && !$frozen && [peek 0x6E55] == 0xCD && [peek $::DIRTY] == 0 && [peek $::PENDING] == 0} {
        set st ""
        for {set i 0} {$i < 10} {incr i} { append st [format "%04X " [peek16 [expr {[reg sp] + 2*$i}]]] }
        puts $::lg "$t NONE-SHOWN active=$act shown=$shown listed=$n pc=[format %04X [reg pc]] stack=$st"
    }
}
after time 30 check
after time $::env(HQ_SECS) { puts $::lg "checks=$::nchk sprites_checked=$::nspr"; close $::lg; exit }
