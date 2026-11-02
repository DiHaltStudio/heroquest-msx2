# Combat and damage checks, sourced by boot_test.tcl via check_modes.py.
set ::cheat_log [open "${out}.checks" w]
set ::cheat_index 0
proc cheat_symbols {} {
    set f [open build/runtime2.sym]
    while {[gets $f line] >= 0} {
        if {[regexp {^(\w+): equ ([0-9A-Fa-f]+)h} $line -> name value]} { set ::csym($name) [expr "0x$value"] }
    }
    close $f
}
cheat_symbols
proc cheat_assert {condition message} {
    if {![uplevel 1 [list expr $condition]]} { puts $::cheat_log "FAIL: $message"; flush $::cheat_log; error $message }
}
proc cheat_poke16 {addr value} { poke $addr [expr {$value&255}]; poke [expr {$addr+1}] [expr {$value>>8}] }
# Four zero-dice hero attacks, four monster attacks against a hero on their
# last body point, then every damage calculation and both expansion paths.
set ::cheat_cases {
    {attack 0 0x99A2} {attack 1 0x99A2} {attack 2 0x99A2} {attack 3 0x99A2}
    {defend 0 0x996B} {defend 1 0x996B} {defend 2 0x996B} {defend 3 0x996B}
    {damage 0 0x9B04} {treasure 0 0x81E3} {disarm 0 0xA037}
    {pit 0 0xA13F} {rock 0 0xA20B} {other-rock 0 0xA223}
    {ball-flame 0 0x7A48} {fire-wrath 0 0x7A7A} {genie 0 0x7AD1}
    {chest 0 0x9025} {gold-chest 0 0x908B}
    {expansion-chest 0 r2_ev_trap_damage} {mist 0 r2_mist_contact}
}
proc cheat_next {} {
    if {$::cheat_index >= [llength $::cheat_cases]} {
        puts $::cheat_log "PASS: all [llength $::cheat_cases] cheat cases"
        close $::cheat_log
        hq_report
        return
    }
    lassign [lindex $::cheat_cases $::cheat_index] ::cheat_case hero entry
    if {[info exists ::csym($entry)]} { set entry $::csym($entry) }
    set ::cheat_hero [expr {0xA9E5+26*$hero}]
    set h $::cheat_hero
    poke $h 1
    poke [expr {$h+6}] 1
    cheat_poke16 0xA9DD $h
    cheat_poke16 0xA9C7 $h
    poke 0xA998 $hero
    poke 0xA9AD $hero
    poke 0xA9BB $hero
    # A valid ordinary monster, with a harmless standard death handler.
    debug write_block memory 0x4300 [binary format cu* {1 1 1 0 0 96 1 49 0 0}]
    cheat_poke16 0xA9C5 0x4300
    poke 0x6600 1
    poke 0xA9A9 0
    poke 0xA9AA 0
    poke 0xA9AB 10
    poke 0xA9AC 10
    poke 0xA9C3 10
    poke 0xA9C4 0
    reg IX $h
    reg IY $h
    reg DE 5
    reg SP $::cheat_sp
    poke 0x4010 0xCD
    cheat_poke16 0x4011 $entry
    reg PC 0x4010
}
proc cheat_return {} {
    cheat_assert {[peek [expr {$::cheat_hero+6}]] == 1} "$::cheat_case changed body points"
    cheat_assert {[peek $::cheat_hero] == 1} "$::cheat_case killed hero"
    if {$::cheat_case eq "attack"} {
        cheat_assert {[peek 0x4300] == 0} "zero-dice attack did not kill monster"
        cheat_assert {[peek 0xA9C3] == 1 && [peek 0xA9C4] == 0} "winning dice do not match result"
    }
    if {$::cheat_case eq "defend"} { cheat_assert {[peek 0xA9C3] == 0} "monster rolled skulls" }
    puts $::cheat_log "PASS $::cheat_case hero=$::cheat_hero body=1"
    flush $::cheat_log
    incr ::cheat_index
    cheat_next
}
proc cheat_start {} {
    set ::cheat_sp [reg SP]
    debug set_bp 0x4013 {} cheat_return
    cheat_next
}
after time 55 cheat_start
