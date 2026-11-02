"""Optional patches for heroquest-cheat.rom; never applied to the normal ROM.

Combat keeps its pictures, dice panels, monster death handlers and rewards.
Heroes inflict one unblocked skull and monsters inflict none. Also protect
heroes against spell, treasure, trap, falling-rock and expansion mist damage,
including the branches that would kill a hero on their last body point.
"""

PATCHES = [
    ('game', 0x99AC, '28 03', '', 'cheat: even zero attack dice hit'),
    ('game', 0x99AE, 'cd 1c 7b', '1e 01', 'cheat: hero rolls one skull'),
    ('game', 0x99C8, '7b', 'af', 'cheat: monster rolls no shields'),
    ('game', 0x998D, 'cd 1c 7b', 'af', 'cheat: monster rolls no skulls'),
    ('game', 0x9B04, 'ed 5b c3 a9', 'c9', 'cheat: no combat damage to heroes'),
    ('game', 0x7A48, 'dd 7e 06', 'c3 19 7a', 'cheat: deflect Ball of Flame on heroes'),
    ('game', 0x7A7A, 'dd 7e 06', 'c3 19 7a', 'cheat: deflect Fire of Wrath on heroes'),
    ('game', 0x7AD1, 'dd 7e 06', 'c3 19 7a', 'cheat: deflect Genie on heroes'),
    ('game', 0x81E6, '3d', 'b7', 'cheat: no treasure-card trap damage'),
    ('game', 0x902C, 'fe 01', 'b7', 'cheat: chest cannot kill a hero on one body point'),
    ('game', 0x9030, 'fd 35 06', '', 'cheat: no explosive chest damage'),
    ('game', 0x9092, 'fe 01', 'b7', 'cheat: gold chest cannot kill a hero on one body point'),
    ('game', 0x9096, 'fd 35 06', '', 'cheat: no gold chest trap damage'),
    ('game', 0xA03A, '3d', 'b7', 'cheat: no failed disarm damage'),
    ('game', 0xA142, '3d', 'b7', 'cheat: no pit or spear damage'),
    ('game', 0xA20E, '3d', 'b7', 'cheat: no falling rock damage'),
    ('game', 0xA226, '93', 'b7', 'cheat: no falling rock damage to another hero'),
    ('runtime2', 'r2_ev_trap_damage', 'fd 7e 06', ('jp', 'ZX_BODYHUD'),
     'cheat: no expansion chest damage'),
    ('runtime2', 'r2_mist_contact', 'af f5 cd', ('jp', 'rt_present'),
     'cheat: no expansion mist damage', 5),
]
