# Native scroll integration checks in a real MSX2 emulator.
# Run through tools/check_scrolls.py; output prefix in HQ_OUT.
set throttle off
set ::sc_out $::env(HQ_OUT)
set ::sc_log [open "${::sc_out}.txt" w]
set ::sc_cases {
    {ivory 1 0 12 1 0x78 0}
    {fibres 17 0 12 1 0x38 0}
    {ochre 1 4 12 1 0x70 0}
    {leather 17 4 12 1 0x18 0}
    {aged 1 8 12 1 0x58 0}
    {moss 17 8 12 1 0x28 0}
    {light-moss 1 12 12 1 0x68 0}
    {green-ash 17 12 12 1 0x20 0}
    {ash 1 16 12 1 0x60 0}
    {scorched 17 16 12 1 0x47 0}
    {search 8 11 15 3 0x78 0}
    {inverse 8 11 15 3 0x47 0x2F}
    {minimum 10 8 1 1 0x78 0}
    {maximum 0 0 30 20 0x70 0}
    {disabled 10 8 1 1 0x78 0}
}
set ::sc_index 0
set ::sc_failed 0
proc sc_assert {condition message} {
    if {![uplevel 1 [list expr $condition]]} {
        puts $::sc_log "FAIL $message"
        set ::sc_failed 1
    }
}
proc sc_start {} {
    # Public game entry + presentation. Stop at the following JP, before
    # starting another call. The CPU keeps running its normal interrupt.
    set p 0x4010
    foreach byte {0xCD 0xD1 0x8D 0xCD 0x03 0x8D 0xC3 0x16 0x40} {
        poke $p $byte; incr p
    }
    debug set_bp 0x4013 {} sc_return
    debug set_bp 0x4016 {} sc_done
    # Plain background for the gallery; no game sprites are requested.
    debug write_block VRAM 0x8000 [string repeat [binary format c 0xCC] 0x8000]
    debug write_block VRAM 0 [string repeat [binary format c 0xCC] 0x6A00]
    sc_next
}
proc sc_next {} {
    lassign [lindex $::sc_cases $::sc_index] name x row w h attr inverse
    set ::sc_case $name
    set ::sc_started [machine_info time]
    set ::sc_capture_ready 0
    set ::sc_capture_wait 0
    set ::sc_sp [reg SP]
    set ::sc_slots [debug read ioports 0xA8]
    if {$name eq "disabled"} { reg IFF 0 }
    set ::sc_iff [reg IFF]
    # Deliberately destroy the transient module between calls, as the hero
    # save/options modules do. Every call must restore its code from ROM.
    for {set p 0x4100} {$p < 0x4500} {incr p} { poke $p 0xA5 }
    for {set r [expr {$row+2}]} {$r < $row+$h+4} {incr r} {
        for {set c $x} {$c < $x+$w+2} {incr c} {
            poke [expr {0x5800+$r*32+$c}] $attr
        }
    }
    set p 0xE700
    foreach byte [list $x $row $w $h] { poke $p $byte; incr p }
    if {$name in {search inverse}} {
        # Use the actual search menu record, including its spaces.
        for {set i 4} {$i < 49} {incr i} {
            poke $p [peek [expr {0xAFE2+$i}]]; incr p
        }
    } else {
        set text [string toupper [string map {- " "} $name]]
        for {set i 0} {$i < $w*$h} {incr i} {
            set v 0x5F
            if {$i < [string length $text]} { scan [string index $text $i] %c v }
            poke $p $v; incr p
        }
    }
    set ::sc_expected_ix $p
    poke 0x8E72 $inverse
    reg IX 0xE700
    reg PC 0x4010
}
proc sc_return {} {
    sc_assert {[reg IX] == $::sc_expected_ix} "$::sc_case: record consumption"
    sc_assert {[reg SP] == $::sc_sp} "$::sc_case: stack balance"
    sc_assert {[debug read ioports 0xA8] == $::sc_slots} "$::sc_case: RAM slots"
    sc_assert {[reg IFF] == $::sc_iff} "$::sc_case: interrupt state"
    puts $::sc_log [format "%s IX=%04X SP=%04X %.4f seconds" $::sc_case [reg IX] [reg SP] [expr {[machine_info time]-$::sc_started}]]
}
proc sc_done {} {
    # rt_present starts an asynchronous VDP copy. Keep the CPU in its JP
    # loop until it has completed before taking a visible-page snapshot.
    if {!$::sc_capture_wait} {
        set ::sc_capture_wait 1
        after time 0.02 {set ::sc_capture_ready 1}
    }
    if {!$::sc_capture_ready} { return }
    set name $::sc_case
    if {$name eq "scorched"} { set name gallery }
    if {$::sc_index >= 9} {
        set f [open "${::sc_out}-${name}.vram" w]
        fconfigure $f -translation binary
        puts -nonewline $f [debug read_block VRAM 0 0x20000]
        close $f
        set f [open "${::sc_out}-${name}.pal" w]
        fconfigure $f -translation binary
        puts -nonewline $f [debug read_block {VDP palette} 0 32]
        close $f
    }
    incr ::sc_index
    if {$::sc_index == [llength $::sc_cases]} {
        puts $::sc_log "failed=$::sc_failed"
        close $::sc_log
        exit
    }
    sc_next
}
proc sc_key {row mask} {
    keymatrixdown $row $mask
    after time 0.5 [list keymatrixup $row $mask]
}
foreach t {18 21 24 28 33} { after time $t {sc_key 8 1} }
after time 36 sc_start
after time 53 {
    puts $::sc_log "FAIL renderer did not return"
    close $::sc_log
    exit
}
