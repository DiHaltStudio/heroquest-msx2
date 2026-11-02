# Native calls return through unused RAM 4000h to the fixture dispatcher.
# Text and artwork always come from the English cartridge data.
array set ::mc_sym {@SYMBOLS@}
set ::mc_case @CASE@
set ::mc_queue {}
set ::mc_active 0
proc mc_word {address value} {
    poke $address [expr {$value & 255}]
    poke [expr {$address + 1}] [expr {$value >> 8}]
}
proc mc_call {address} {
    reg SP 0x6D60
    mc_word 0x6D60 0x4000
    reg PC $address
}
proc mc_next {} {
    if {!$::mc_active} {return}
    if {[llength $::mc_queue] == 0} {
        set f [open "${::out}.ready" w]
        puts $f "Current English ROM fixture $::mc_case completed"
        close $f
        hq_report
        return
    }
    set command [lindex $::mc_queue 0]
    set ::mc_queue [lrange $::mc_queue 1 end]
    eval $command
}
proc mc_finish {} {
    lappend ::mc_queue {reg B 20; mc_call 0x9D66}
    mc_next
}
proc mc_enter {} {
    if {[peek $::mc_sym(rt_language)] != 1 || [debug read_block memory 0x6667 4] ne "PLAY"} {
        error "English main menu was not reached"
    }
    set ::mc_active 1
    foreach a {0x8FE4 0x8FE5 0x8FE6 0x8FE7} {poke $a 255}
    poke 0xA998 0
    mc_word 0xA9DD 0xA9E5
    poke 0xA9E5 1
    poke 0xA9EB 8
    poke 0xA9EC 2
    poke 0xA989 1
    # Ordinary one-body, two-mind orc, using the original name/portrait tables.
    debug write_block memory 0x61E0 [binary format cu* {1 1 1 0 0 98 1 18 1 1}]
    mc_word 0xA9C5 0x61E0
    if {$::mc_case eq "buscar_en"} {
        set ::mc_active 0
        poke 0xA981 1
        reg SP 0x6D70
        mc_word 0x6D70 0x6D84
        reg PC 0x5B3F
        return
    }
    set ::mc_queue {{mc_call 0x8FDB} {reg A 7; mc_call 0x9C30}}
    if {[string match hoja_* $::mc_case]} {
        if {$::mc_case eq "hoja_hechicero_en"} {
            poke 0xA998 3
            mc_word 0xA9DD 0xAA33
            poke 0xAA3E 56
            poke 0xAA3F 63
        }
        lappend ::mc_queue {mc_call 0x95BE} {mc_call 0x8D03}
    } elseif {[regexp {^lamina_([0-9]+)_en$} $::mc_case -> n]} {
        set ids {{3 0xF382} {3 0xF802} {7 0xC440} {7 0xC8C0} {4 0xE400} {4 0xE880} {4 0xED00} {4 0xF180} {4 0xF600} {4 0xFA80}}
        lassign [lindex $ids $n] bank address
        lappend ::mc_queue "reg HL $address; reg B [expr {$bank + 16}]; reg C 2; reg IX 0xB82D; mc_call 0x9A7B"
    } else {
        lappend ::mc_queue \
            {reg IX 0xAA88; mc_call 0x8BF9} \
            {mc_call 0x9C62} {mc_call 0xA3E1} {mc_call 0x764A} \
            {mc_call 0x75ED} {mc_call 0x751D}
        if {$::mc_case eq "combate_victoria_en"} {
            poke 0xA9C3 2
            poke 0xA9C4 0
            lappend ::mc_queue {mc_call 0x99DB} {mc_call 0x9A26}
        } else {
            poke 0xA9C3 1
            poke 0xA9C4 [expr {$::mc_case eq "combate_bloqueado_en" ? 1 : 0}]
            lappend ::mc_queue {mc_call 0x99F8} {mc_call 0x9A4D}
        }
    }
    mc_finish
}
proc mc_briefing_skip {} {
    if {$::mc_case ne "buscar_en" || $::mc_active} {return}
    reg PC 0x5C56
}
proc mc_search_room {} {
    if {$::mc_case ne "buscar_en" || $::mc_active} {return}
    set ::mc_active 1
    poke 0xA98C 7
    poke 0xA98B 0
    set ::mc_queue {{mc_call 0x9242} {mc_call 0x804E} {mc_call 0x8D03}}
    mc_finish
}
debug set_bp 0x4000 {} mc_next
debug set_bp 0x5C53 {} mc_briefing_skip
debug set_bp 0x6E50 {} mc_search_room
after time 32 mc_enter
