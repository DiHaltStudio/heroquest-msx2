# Expanded by check_logo.py. No timed key injection: every input follows a
# playback tick or a boot-stage breakpoint. The timeout is only a watchdog.
set throttle off
array set ::logo_sym {@SYMBOLS@}
set ::logo_expected_psg {@PSG@}
set ::logo_expected_opl {@OPL@}
set ::logo_expected_ticks @TICKS@
set ::logo_stage boot
set ::logo_ticks 0
set ::logo_psg_index 0
set ::logo_opl_index 0
set ::logo_psg_audible 0
set ::logo_opl_keyon 0
set ::logo_report [open "$::env(HQ_OUT).checks" w]
proc logo_fail {message} {
    puts $::logo_report "FAIL: $message"
    close $::logo_report
    exit
}
proc logo_assert {condition message} {
    if {![uplevel 1 [list expr $condition]]} {logo_fail $message}
}
proc logo_ready_check {} {
    debug remove_bp $::logo_ready_bp
    logo_assert {$::logo_stage eq "boot"} "logo restarted"
    logo_assert {([peek $::logo_sym(rt_opl)] != 0) == @OPL4@} "wrong automatic sound backend"
    logo_assert {([peek $::logo_sym(rt_60hz)] != 0) == @HZ60@} "wrong machine frame rate"
    logo_assert {[peek16 $::logo_sym(logo_remaining)] == $::logo_expected_ticks} "incorrect initial duration"
    logo_assert {([debug read {VDP regs} 1] & 64) != 0} "logo display is disabled"
    set ::logo_vram [debug read_block VRAM 0 0x6A00]
    set ::logo_palette [debug read_block {VDP palette} 0 32]
    if {@OPL4@} {
        logo_assert {[peek $::logo_sym(rt_opl_once)] == 1} "OPL4 fanfare could loop"
        logo_assert {[peek $::logo_sym(rt_opl_tune)] == 3} "OPL4 fanfare is not third tune"
        set expected [binary decode hex {@PCM@}]
        logo_assert {[debug read_block {Sunrise MoonSound wave mem} 0x200000 [string length $expected]] eq $expected} "OPL4 sample RAM differs from dihalt.pcm"
        puts $::logo_report "PASS: OPL4 sample RAM matches source"
    }
    set ::logo_started [machine_info time]
    set ::logo_stage playing
}
proc logo_tick_check {} {
    if {$::logo_stage ne "playing"} {return}
    incr ::logo_ticks
    logo_assert {$::logo_ticks <= $::logo_expected_ticks} "fanfare looped"
    logo_assert {[peek16 $::logo_sym(logo_remaining)] == $::logo_expected_ticks - $::logo_ticks + 1} "tick counter skipped"
    # Try both skip keys while notes are playing. Release after 25 music
    # ticks, so a held key cannot unintentionally advance the opening.
    if {$::logo_ticks == 100} {
        keymatrixdown 8 1
        keymatrixdown 7 4
    }
    if {$::logo_ticks == 125} {
        keymatrixup 8 1
        keymatrixup 7 4
        logo_assert {[debug read_block VRAM 0 0x6A00] eq $::logo_vram} "skip keys changed the logo"
    }
}
proc logo_psg_register {} {
    if {$::logo_stage eq "playing"} {set ::logo_psg_register [reg a]}
}
proc logo_psg_value {} {
    if {$::logo_stage ne "playing"} {return}
    set actual [list [expr {$::logo_ticks - 1}] $::logo_psg_register [reg a]]
    set expected [lindex $::logo_expected_psg $::logo_psg_index]
    logo_assert {$actual eq $expected} "PSG write $::logo_psg_index: expected {$expected}, got {$actual}"
    logo_assert {$::logo_psg_register <= 13} "PSG fanfare changed joystick I/O registers"
    if {$::logo_psg_register == 7} {
        logo_assert {([reg a] & 192) == 128} "PSG mixer corrupted MSX I/O directions"
    }
    if {$::logo_psg_register in {8 9 10} && ([reg a] & 31) != 0} {incr ::logo_psg_audible}
    incr ::logo_psg_index
}
proc logo_opl_value {} {
    if {$::logo_stage ne "playing"} {return}
    set actual [list [expr {$::logo_ticks - 1}] [expr {[reg c] - 1}] [reg e] [reg d]]
    set expected [lindex $::logo_expected_opl $::logo_opl_index]
    logo_assert {$actual eq $expected} "OPL4 write $::logo_opl_index: expected {$expected}, got {$actual}"
    if {[reg c] == 127 && [reg e] >= 104 && [reg e] <= 127 && ([reg d] & 128)} {incr ::logo_opl_keyon}
    incr ::logo_opl_index
}
proc logo_silence_check {} {
    foreach register {8 9 10} {
        logo_assert {[debug read {PSG regs} $register] == 0} "PSG channel still sounding"
    }
    logo_assert {[debug read {PSG regs} 7] == 191} "PSG mixer not silent or I/O bits changed"
    logo_assert {[peek $::logo_sym(rt_opl_once)] == 0} "one-shot flag leaked into intro"
    if {@OPL4@} {
        logo_assert {[peek $::logo_sym(rt_opl_play)] == 0} "OPL4 player still active"
        for {set reg 104} {$reg < 128} {incr reg} {
            logo_assert {[debug read {Sunrise MoonSound wave regs} $reg] == 0} "OPL4 voice key remains on"
        }
    }
}
proc logo_done_check {} {
    debug remove_bp $::logo_done_bp
    logo_assert {$::logo_stage eq "playing"} "logo exit without playback"
    logo_assert {$::logo_ticks == $::logo_expected_ticks} "logo skipped or ended early"
    logo_assert {$::logo_psg_index == [llength $::logo_expected_psg]} "missing PSG writes"
    logo_assert {$::logo_opl_index == [llength $::logo_expected_opl]} "missing OPL4 writes"
    if {@OPL4@} {
        logo_assert {$::logo_opl_keyon > 0} "OPL4 fanfare never keyed on"
        logo_assert {$::logo_psg_audible == 0} "PSG tune leaked into OPL4 mode"
    } else {
        logo_assert {$::logo_psg_audible > 0} "PSG fanfare was silent throughout"
    }
    logo_silence_check
    logo_assert {[debug read_block VRAM 0 0x6A00] eq $::logo_vram} "logo was replaced before music ended"
    logo_assert {[debug read_block {VDP palette} 0 32] eq $::logo_palette} "logo palette changed during fanfare"
    set duration [expr {[machine_info time] - $::logo_started}]
    logo_assert {abs($duration - $::logo_expected_ticks / 50.0) < 0.05} "fanfare duration is not normalized: $duration seconds"
    puts $::logo_report "DURATION $duration"
    puts $::logo_report "PASS: exact source writes, 50 Hz timing, skip keys ignored and silent exit"
    set ::logo_stage done
    # The intro replaces logo code at 8000h. Remove all its breakpoints so
    # unrelated intro instructions at reused addresses cannot trigger them.
    foreach bp $::logo_play_bps {debug remove_bp $bp}
}
proc logo_opening_check {} {
    if {$::logo_stage ne "done"} {return}
    debug remove_bp $::logo_opening_bp
    logo_silence_check
    set ::logo_stage opening
    keymatrixdown 8 1
}
proc logo_opening_release {} {
    if {$::logo_stage ne "opening"} {return}
    debug remove_bp $::logo_release_bp
    keymatrixup 8 1
    set ::logo_stage selector
}
proc logo_selector_check {} {
    if {$::logo_stage ne "selector"} {return}
    logo_assert {[peek $::logo_sym(rt_language)] == 0} "selector default changed"
    logo_silence_check
    puts $::logo_report "PASS: fanfare, opening and selector"
    close $::logo_report
    exit
}
set ::logo_ready_bp [debug set_bp $::logo_sym(logo_ready) {} logo_ready_check]
set ::logo_done_bp [debug set_bp $::logo_sym(logo_done) {} logo_done_check]
set ::logo_play_bps [list \
    [debug set_bp $::logo_sym(logo_tick) {} logo_tick_check] \
    [debug set_bp $::logo_sym(logo_psg_write) {} logo_psg_register] \
    [debug set_bp $::logo_sym(logo_psg_value) {} logo_psg_value] \
    [debug set_bp [expr {$::logo_sym(rt_ow_data) + 5}] {} logo_opl_value]]
set ::logo_opening_bp [debug set_bp $::logo_sym(in_op_press) {} logo_opening_check]
set ::logo_release_bp [debug set_bp $::logo_sym(in_op_release2) {} logo_opening_release]
debug set_bp $::logo_sym(in_select_poll) {} logo_selector_check
after time 60 {logo_fail "boot watchdog expired at $::logo_stage after $::logo_ticks ticks"}
