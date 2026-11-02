# Template expanded by check_languages.py. Test inputs use the real keyboard.
array set ::lsym {@SYMBOLS@}
set ::wanted @LANGUAGE@
set ::wanted_banks @BANKS@
set ::quest_texts {@QUESTS@}
set ::language_report [open "${out}.checks" w]
set ::language_stage boot
set ::quest_number 0
set ::saw_story 0

proc language_fail {message} {
    puts $::language_report "FAIL: $message"
    flush $::language_report
    close $::language_report
    hq_report
}
proc language_assert {condition message} {
    if {![uplevel 1 [list expr $condition]]} { language_fail $message }
}
proc language_hex {address length} {
    binary encode hex [debug read_block memory $address $length]
}
proc language_opening {} {
    debug remove_bp $::opening_bp
    after time 0.1 {hq_key 8 1 0.3}
}
proc language_confirm_key {} {
    if {$::wanted} {hq_key 7 128 0.3} else {hq_key 8 1 0.3}
}
proc language_selector_frame {} {
    if {$::language_stage ni {round_up round_down final_up confirming}} {return}
    language_assert {([debug read {VDP regs} 1] & 64) != 0} "selector blanked during a language change"
    foreach page {0 1} {
        language_assert {[debug read_block VRAM [expr {$page * 0x8000}] 0x6A00] eq $::selector_page($page)} "selector redrew a prepared page"
    }
    after frame language_selector_frame
}
proc language_select {} {
    set current [peek $::lsym(rt_language)]
    language_assert {(([debug read {VDP regs} 2] >> 5) & 3) == $current} "selector shows the wrong page"
    if {$::language_stage eq "boot"} {
        language_assert {$current == 0} "selector does not default to Spanish"
        set ::language_stage round_up
        foreach page {0 1} {
            set ::selector_page($page) [debug read_block VRAM [expr {$page * 0x8000}] 0x6A00]
        }
        language_assert {$::selector_page(0) ne $::selector_page(1)} "selector pages have identical highlights"
        after frame language_selector_frame
        after time 0.1 {hq_key 8 32 0.3}
    } elseif {$::language_stage eq "round_up" && $current == 1} {
        set ::language_stage round_down
        after time 0.1 {hq_key 8 64 0.3}
    } elseif {$::language_stage eq "round_down" && $current == 0} {
        if {$::wanted} {
            set ::language_stage final_up
            after time 0.1 {hq_key 8 32 0.3}
        } else {
            set ::language_stage confirming
            after time 0.1 language_confirm_key
        }
    } elseif {$::language_stage eq "final_up" && $current == 1} {
        set ::language_stage confirming
        after time 0.1 language_confirm_key
    }
}
proc language_story {} {
    debug remove_bp $::story_bp
    language_assert {[peek $::lsym(rt_language)] == $::wanted} "wrong selected language"
    language_assert {[peek $::lsym(in_skip)] == 0} "confirmation key skipped intro"
    language_assert {[language_hex $::lsym(rt_bank_segs) 8] eq $::wanted_banks} "wrong ROM bank table"
    language_assert {([peek $::lsym(rt_60hz)] != 0) == @HZ60@} "wrong machine frame-rate flag"
    language_assert {([peek $::lsym(rt_opl)] != 0) == @OPL4@} "wrong sound backend"
    language_assert {[language_hex [expr {$::lsym(sc_txt_save)+5}] [expr {[string length @CODE@] / 2}]] eq "@CODE@"} "hero-code language is wrong"
    set ::language_stage story
    puts $::language_report "PASS: selector and bank mapping"
    puts $::language_report "PASS: selector stays visible with immutable pages while changing language"
}
proc language_first_text {} {
    if {$::language_stage ne "story"} { return }
    set expected $::lsym(in_text_es_0)
    if {$::wanted} {set expected $::lsym(in_text_en_0)}
    language_assert {[reg hl] == $expected} "intro uses wrong text table"
    set ::saw_story 1
    set ::language_stage skipping
    after time 0.2 {hq_key 8 1 0.3}
    puts $::language_report "PASS: first narrative text rendered in selected language"
}
proc language_menu {} {
    if {$::language_stage eq "returning"} {
        language_assert {[language_hex 0x6667 [expr {[string length @MENU@] / 2}]] eq "@MENU@"} "language lost on menu reload"
        language_assert {[peek $::lsym(rt_language)] == $::wanted} "language flag lost"
        puts $::language_report "PASS: language retained after overlay reload"
        puts $::language_report "PASS: 24 bilingual quest loaders"
        close $::language_report
        hq_report
        return
    }
    if {$::language_stage ne "skipping"} { return }
    language_assert {$::saw_story} "intro was skipped before its first text"
    language_assert {[language_hex 0x6667 [expr {[string length @MENU@] / 2}]] eq "@MENU@"} "main menu text is wrong"
    language_assert {[language_hex 0x7837 9] eq "@HERO@"} "resident hero name is wrong"
    set ::saved_overlay [debug read_block memory 0x5B00 0x11EE]
    set ::language_stage quests
    puts $::language_report "PASS: game and overlay language"
    language_next_quest
}
proc language_next_quest {} {
    debug write_block memory 0x5B00 $::saved_overlay
    poke 0xA981 $::quest_number
    foreach address {0x8FE4 0x8FE5 0x8FE6 0x8FE7} {poke $address 255}
    reg SP 0x6D70
    reg PC 0x5B3F
}
proc language_briefing {} {
    if {$::language_stage ne "quests"} {return}
    set expected [lindex $::quest_texts $::quest_number]
    set size [expr {[string length $expected] / 2}]
    language_assert {[reg ix] == 0xFA00} "quest text pointer"
    language_assert {[language_hex 0xFA00 $size] eq $expected} "quest $::quest_number loaded wrong text"
}
proc language_rendered {} {
    if {$::language_stage ne "quests"} {return}
    puts $::language_report "PASS: quest $::quest_number loaded and rendered"
    incr ::quest_number
    if {$::quest_number == 24} {
        set ::language_stage returning
        reg SP 0x6D70
        reg PC 0x6D81
    } else {
        language_next_quest
    }
}
proc language_arm_intro {} {
    set ::opening_bp [debug set_bp $::lsym(in_op_press) {} language_opening]
    debug set_bp $::lsym(in_select_poll) {} language_select
    set ::story_bp [debug set_bp $::lsym(in_start_script) {} language_story]
    debug set_bp $::lsym(in_draw_glyphs) {} language_first_text
    debug set_bp 0x5B06 {} language_menu
    debug set_bp 0x5C40 {} language_briefing
    debug set_bp 0x5C53 {} language_rendered
}
# The transient logo player occupies the intro addresses until this bridge.
debug set_bp $::lsym(rt_boot_intro) {} language_arm_intro
