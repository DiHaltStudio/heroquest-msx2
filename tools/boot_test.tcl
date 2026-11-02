# openMSX script: boots the ROM, waits, saves the SCREEN 5 page 0 VRAM, the palette and a short state
# report, then exits. Environment: HQ_OUT (output prefix), HQ_SECS (emulated
# seconds to run, default 20), HQ_KEYS (optional key presses, see below).
set out $::env(HQ_OUT)
set secs 20
if {[info exists ::env(HQ_SECS)]} { set secs $::env(HQ_SECS) }
set throttle off
proc hq_report {} {
    global out
    set f [open "${out}.txt" w]
    puts $f "pc=[format %04X [reg pc]] sp=[format %04X [reg sp]] im=[reg im] iff=[reg iff]"
    puts $f "slots=[format %02X [debug read ioports 0xA8]]"
    puts $f "mouse port=[peek 0x62] try=[peek 0x63] miss=[peek 0x64] btn=[peek 0x65] raw=[format %04X [peek16 0x66]] plugged=[plug joyporta]/[plug joyportb]  cursor x=[peek 0xAA69] y=[peek 0xAA6A]"
    set v ""
    for {set i 0} {$i < 9} {incr i} { append v [format "%02X " [debug read VRAM [expr {0x7600 + $i}]]] }
    puts $f "sprite attrs: $v"
    puts $f "rt_bank=[format %02X [peek 0x52]]"
    puts $f "opl4: present=[peek 0x6B] playing=[peek 0x6C] tune=[peek 0x6D] segment=[peek 0x6E] address=[format %04X [peek16 0x6F]] wait=[peek 0x71]"
    set nz 0
    for {set a 0} {$a < 0x6A00} {incr a 7} { if {[debug read VRAM $a] != 0} { incr nz } }
    puts $f "vram sampled nonzero=$nz"
    set st ""
    for {set i 0} {$i < 24} {incr i} { append st [format "%04X " [peek16 [expr {[reg sp] + 2*$i}]]] }
    puts $f "stack: $st"
    set v ""
    for {set i 0} {$i < 14} {incr i} { append v [format "%02X " [debug read {PSG regs} $i]] }
    puts $f "psg regs: $v"
    set v ""
    for {set i 0} {$i < 24} {incr i} { append v [format "%02X " [debug read {VDP regs} $i]] }
    puts $f "vdp regs: $v"
    set v ""
    for {set i 0} {$i < 32} {incr i} { append v [format "%02X " [debug read {VDP palette} $i]] }
    puts $f "palette: $v"
    puts $f "5B00: [format %02X [peek 0x5B00]] [format %02X [peek 0x5B01]] [format %02X [peek 0x5B02]]  FDFD: [format %02X [peek 0xFDFD]] [format %04X [peek16 0xFDFE]]"
    close $f
    if {[info exists ::hq_logf]} { close $::hq_logf }
    if {[info exists ::hq_vdpf]} { close $::hq_vdpf }
    set vf [open "${out}.vram" w]
    fconfigure $vf -translation binary
    puts -nonewline $vf [debug read_block VRAM 0 0x20000]
    close $vf
    set pf [open "${out}.pal" w]
    fconfigure $pf -translation binary
    puts -nonewline $pf [debug read_block {VDP palette} 0 32]
    close $pf
    exit
}
# HQ_KEYS: list of "seconds key" pairs; key = space left right up down or
# "row:mask" of the keyboard matrix. Each key is held for 0.3 s, or key/seconds.
proc hq_key {row mask hold} {
    keymatrixdown $row $mask
    after time $hold "keymatrixup $row $mask"
}
if {[info exists ::env(HQ_KEYS)]} {
    array set names {space {8 1} left {8 16} up {8 32} down {8 64} right {8 128}}
    foreach {t k} $::env(HQ_KEYS) {
        set hold 0.3
        if {[regexp {^(.*)/(.*)$} $k -> k hold]} {}
        if {[info exists names($k)]} { set rm $names($k) } else { set rm [split $k :] }
        after time $t "hq_key [lindex $rm 0] [lindex $rm 1] $hold"
    }
}
if {[info exists ::env(HQ_PLUG)]} { after time 6 { eval $::env(HQ_PLUG) } }
# HQ_TCL: list of "seconds {tcl command}" pairs run at those times (pokes,
# forced calls) to set up situations for a test.
if {[info exists ::env(HQ_TCL)]} {
    foreach {t cmd} $::env(HQ_TCL) { after time $t $cmd }
}
# HQ_LOG: "seconds addr name addr name ...": from that time on, log every
# hit of those addresses (hex) to ${out}.log with HL, DE, IX and A.
proc hq_loghit {name} {
    puts $::hq_logf [format "%.3f %-14s hl=%04X de=%04X ix=%04X a=%02X" [machine_info time] $name [reg hl] [reg de] [reg ix] [reg a]]
    flush $::hq_logf
}
proc hq_logstart {pairs} {
    set ::hq_logf [open "$::out.log" w]
    foreach {a n} $pairs { debug set_bp 0x$a {} "hq_loghit $n" }
}
if {[info exists ::env(HQ_LOG)]} {
    after time [lindex $::env(HQ_LOG) 0] [list hq_logstart [lrange $::env(HQ_LOG) 1 end]]
}
# HQ_VDPLOG: "seconds minNY": from that time on, log to ${out}.vdp every VDP
# command given to rt_vdp_cmd (address from HQ_SYM) whose NY is at least
# minNY: the 15 register bytes and the caller.
proc hq_vdphit {} {
    set hl [reg hl]
    if {[peek [expr {$hl+10}]] + 256*[peek [expr {$hl+11}]] < $::hq_vdpmin} { return }
    set l ""
    for {set i 0} {$i < 15} {incr i} { append l [format "%02X " [peek [expr {$hl+$i}]]] }
    puts $::hq_vdpf "[format %.3f [machine_info time]] $l ret=[format %04X [peek16 [reg sp]]]"
    flush $::hq_vdpf
}
proc hq_vdpstart {min} {
    set ::hq_vdpmin $min
    set ::hq_vdpf [open "$::out.vdp" w]
    set f [open $::env(HQ_SYM)]
    while {[gets $f line] >= 0} {
        if {[regexp {^rt_vdp_cmd: equ 0000(....)h} $line -> v]} { debug set_bp 0x$v {} hq_vdphit }
    }
    close $f
}
if {[info exists ::env(HQ_VDPLOG)]} {
    after time [lindex $::env(HQ_VDPLOG) 0] [list hq_vdpstart [lindex $::env(HQ_VDPLOG) 1]]
}
after time $secs hq_report
