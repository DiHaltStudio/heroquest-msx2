"""Patch manifest: changes applied to the Spectrum images for the MSX2 build.

Each entry: (part, run-time address, expected original bytes, replacement,
reason). part is 'game' (the image loaded at 6400h-FFFDh) or 'overlay'
(5B00h-6CEDh at run time, stored in bank 6). Optional cheat patches may also
target 'runtime2' using an assembled label as the address. The replacement is a hex string
(shorter replacements are filled with NOPs; "{name}" is the address of the
runtime label name, "{snd}" the entry of the sound driver) or ('jp'|'call', runtime label). The build fails if the
expected bytes are not found. An optional sixth element gives the length of
the replaced instruction when it is longer than the expected bytes listed.
"""

LDIR = 'ed b0'
BANK_LDIR = 'cf 00'     # RST 08h + NOP: LDIR from the paged Spectrum bank

PATCHES = [
    # ---- cold start --------------------------------------------------------
    ('game', 0x6410, '01 fd 7f 3e 10 ed 79', '', 'no 128K paging port'),
    ('game', 0x6418, 'd3 fe', '', 'no border port (FEh is the mapper on MSX)'),
    ('game', 0x641E, 'ed 5e', 'ed 56', 'IM 1: the runtime entry at 0038h jumps to FDFDh'),

    # ---- bank paging: remember the bank instead of writing port 7FFDh ------
    ('game', 0x9CD0, 'f3 01 fd 7f ed 79 c9', 'f3 32 {rt_bank} c9', 'PageBankA'),
    ('game', 0x9CD7, '01 fd 7f 3e 10 ed 79 fb c9', '3e 10 32 {rt_bank} fb c9', 'PageBank0'),
    ('game', 0x886C, LDIR, BANK_LDIR, 'furniture graphic from bank 6'),
    ('game', 0x9422, LDIR, BANK_LDIR, 'overview-map furniture from bank 6'),
    ('game', 0x9A86, LDIR, BANK_LDIR, 'combat picture bitmap'),
    ('game', 0x9AAC, LDIR, BANK_LDIR, 'CopyRows16: also reads picture attributes from the bank'),
    ('game', 0x9C0E, LDIR, BANK_LDIR, 'ShowBackdrop: frame picture from bank 6'),
    ('game', 0x9CC9, LDIR, BANK_LDIR, 'overlay from bank 6'),
    ('overlay', 0x5B6D, LDIR, BANK_LDIR, 'quest map from bank 1/3'),
    ('overlay', 0x5B75, LDIR, BANK_LDIR, 'rest of the quest data'),
    ('overlay', 0x5D95, LDIR, BANK_LDIR, 'font from bank 7'),

    # ---- sound: the driver of RAM bank 4 runs relocated in page 0 ----------
    ('game', 0x6FAE, '01 fd 7f 3e 14 ed 79 af cd 88 d3 3e 01 cd 88 d3 01 fd 7f 3e 10 ed 79',
     'cd {rt_music_tick} 18 12', 'interrupt: music frame and modulation frame'),
    ('game', 0x7BD3, 'f5 01 fd 7f 3e 14 ed 79 f1 cd 88 d3 01 fd 7f 3e 10 ed 79',
     'cd {RT2_SNDCMD} 18 0e', 'SoundCommand: the driver in page 0, or the OPL4 for the tunes'),

    # ---- input -------------------------------------------------------------
    ('game', 0x9F80, 'e5 69 0e fe ed 78 a5 e1 c9', ('jp', 'rt_test_key'), 'TestKey'),
    ('game', 0xFD60, '21 97 a9', ('jp', 'rt_read_input'), 'keyboard reader'),
    ('game', 0xFD90, '21 97 a9', ('jp', 'rt_read_input'), 'Sinclair reader'),
    ('game', 0xFDB8, '21 97 a9', ('jp', 'rt_read_input'), 'Sinclair reader'),
    ('overlay', 0x64E7, '7e ee 07 77 23 10 f9 c9', ('jp', 'rt_attr_bar'), 'ToggleAttrBar: present the highlight'),
    ('overlay', 0x5B03, 'cd ef 64', 'cd {rt_front_menu}', 'main menu: credits and mouse-only pointer'),
    # ---- the ten quests of the expansion (quests 14-23) ---------------------
    ('overlay', 0x5B50, '06 11 3a 81 a9 fe 07 38 02 06 13 21 37 66 cd 78 a9', 'cd {RT2_QUEST} 18 0c',
     'quest loader: bank and address of the quest, base or expansion'),
    # 32 monster records instead of 25: the records start where the two
    # tables of search events were (they move into the runtime), as in the
    # expansion program
    ('game', 0x72A8, 'fd 21 1c 6c', 'fd 21 c6 6b', 'monster record area moved'),
    ('game', 0x7872, '11 0c 6c', '11 b6 6b', 'monster record area moved'),
    ('game', 0x8103, 'fd 21 0c 6c', 'fd 21 b6 6b', 'monster record area moved'),
    ('game', 0x8997, '21 0c 6c', '21 b6 6b', 'monster record area moved'),
    ('game', 0x9CEA, 'fd 21 0c 6c', 'fd 21 b6 6b', 'monster record area moved'),
    ('game', 0xA2C1, 'dd 21 0c 6c', 'dd 21 b6 6b', 'monster record area moved'),
    ('game', 0x91D5, 'fd 21 16 6c', 'fd 21 c0 6b', 'monster record area moved'),
    ('game', 0x8089, '11 e1 6b', '11 {RT2_ROOMS_B}', 'search event table B moved'),
    ('game', 0x80C0, '11 b6 6b', '11 {RT2_ROOMS}', 'search event table A moved'),
    ('game', 0x814A, '11 b6 6b', '11 {RT2_ROOMS}', 'search event table A moved'),
    ('game', 0x899A, '06 19', '06 20', '32 monster records'),
    ('game', 0x9CEE, '06 19', '06 20', '32 monster records'),
    ('game', 0xA2C8, '06 19', '06 20', '32 monster records'),
    ('overlay', 0x5BD4, '11 b6 6b', '11 {RT2_ROOMS}', 'quest set-up: search event tables moved'),
    ('overlay', 0x5BF1, '21 0c 6c 11 0d 6c 01 fa 00', '21 b6 6b 11 b7 6b 01 40 01', 'quest set-up: clear 32 monster records'),
    ('overlay', 0x5C0F, '11 0c 6c', '11 b6 6b', 'quest set-up: monster records'),
    ('overlay', 0x5C75, 'dd 21 0c 6c 06 19', 'dd 21 b6 6b 06 20', 'quest set-up: 32 monster records'),
    ('overlay', 0x5C9A, '3e 19 90 3c', 'cd {RT2_MONNUM}', 'quest set-up: record number 1-32; the Death Mist is not on the board'),
    ('game', 0x73D1, 'dd 21 f7 b8', 'cd {RT2_BREAK}', 'ActionAttack: monsters that break the weapon (expansion)'),
    ('game', 0x855E, 'b7 c2 95 82', 'cd {RT2_STEP}', 'FinishStep: teleport of quest 15'),
    ('game', 0xA188, '3a 81 a9', 'cd {RT2_ROCK}', 'HandleTrapEvent: falling rock of the expansion quests'),
    ('game', 0x95D5, 'dd 21 2e b8', 'cd {RT2_KEYLABEL}', 'hero sheet: key of Agrain in quest 17'),
    ('game', 0x9D73, 'fd cb 06 46 c8', 'cd {RT2_MIST}', 'MonsterTakeTurn: the Death Mist of quest 16'),
    ('game', 0x931A, 'dd e1 c9', 'c3 {RT2_MAPMIST}', 'DrawBoardMap: the Death Mist on the map'),
    # monster tables indexed by kind: 16 entries each, in the runtime
    ('game', 0x765A, '21 2d b5', '21 {RT2_MNAMES}', 'monster names'),
    ('game', 0x77B3, '21 2d b5', '21 {RT2_MNAMES}', 'monster names'),
    ('game', 0x9A44, '21 ca 9a', '21 {RT2_MPICS}', 'monster death pictures'),
    ('game', 0x93B0, '21 b2 c3', '21 {RT2_MGLYPHS}', 'monster map glyphs'),
    ('game', 0x6D84, 'cd 89 6d', 'cd {RT2_PLAY}', 'main loop: epilogue of the expansion after the quest'),
    ('game', 0x8EAF, '3a 81 a9', 'cd {RT2_XEXIT}', 'HeroReachesExit: the expansion quests have no exit rule'),
    ('game', 0x827D, '3d 21 a2 82 cd 78 a9', 'cd {RT2_XEVENT}', 'RunRoomSpecial: search events 19-29 of the expansion'),
    ('overlay', 0x668F, 'ff 0b 07 43 4f 4e 54 52 4f 4c 45 53', 'ff 0c 07 4f 50 43 49 4f 4e 45 53 5f',
     'main menu: OPCIONES instead of CONTROLES'),
    ('overlay', 0x5D3F, 'af 32 9c a9', 'c3 {RT2_CTRL}', 'controls menu: the options menu of the cartridge'),
    ('overlay', 0x5E3A, 'cb 57 20 23 cb 67 c2 77 5e', 'cd {RT2_DIR} 20 22 cb 67 20 34',
     'character menu: up as well as down'),
    ('overlay', 0x5E64, 'fe 04 20 02 3e ff 3c', 'cd {RT2_STEP5}', 'character menu: step the hero cursor up or down'),
    ('overlay', 0x62F2, 'cb 57 28 f5 cd ce 64', 'e6 0c 28 f5 cd {RT2_DIRWAIT}', 'shop heroes: up as well as down'),
    ('overlay', 0x62FF, '3c fe 05 20 01 af', 'cd {RT2_STEP5}', 'shop heroes: step the cursor up or down'),
    ('overlay', 0x5EA5, 'cb 47 28 f5 cd ce 64 3a f1 65 3c fe 03 28 0e fe 02 20 0b 3a ef 65 b7 28 04 3e 02 18 01 af',
     'e6 03 28 f5 f5 cd ce 64 3a ef 65 c6 02 47 f1 0f 3a f1 65 38 03 80 3d 3d 3c b8 38 02 90',
     'hero submenu: left as well as right (B = 2 options, 3 if the hero exists)'),
    ('overlay', 0x6224, 'dd 21 6a 68', 'dd 21 {rt_spell_prompt_wizard}', 'spell selection: wizard alone, centred prompt'),
    ('overlay', 0x622E, 'dd 21 3a 68', 'dd 21 {rt_spell_prompt_wizard}', 'spell selection: wizard first, centred prompt'),
    ('overlay', 0x6245, 'dd 21 0a 68', 'dd 21 {rt_spell_prompt_elf}', 'spell selection: elf next, centred prompt'),
    ('overlay', 0x625B, 'cb 47 28 f5 3a f1 65 3c e6 03', 'cd {rt_spell} 30 f4',
     'spell groups: left, up and down as well as right'),
    ('game', 0xB881, '45 4c 5f 41 54 41 51 55 45 5f 45 4e 45 49 47 4f 5f 53 49 4e 5f 45 58 49 54 4f 5f 5f 5f',
     '5f 5f 5f 5f 41 54 41 51 55 45 5f 45 4e 45 4d 49 47 4f 5f 53 49 4e 5f 45 58 49 54 4f 5f',
     'defect D10: "EL ATAQUE ENEIGO SIN EXITO" -> "ATAQUE ENEMIGO SIN EXITO", centred'),
    # TEMPORARY (shop speed test): no wait for the key release in the item list
    ('overlay', 0x63B5, 'cd fd 63 c3 39 63', 'cd fd 63 c3 {RT2_AFTERITEM}', 'shop items up: wait for the release after the step'),
    ('overlay', 0x63F7, 'cd fd 63 c3 39 63', 'cd fd 63 c3 {RT2_AFTERITEM}', 'shop items down: wait for the release after the step'),
    ('overlay', 0x6308, 'cd 3e 64 18 de', 'c3 {RT2_AFTERHERO} 00 00', 'shop heroes: wait for the release after the step'),
    ('overlay', 0x639F, 'cd ce 64', 'cd {RT2_QUICK}', 'TEMPORARY shop items up: no wait for the release'),
    ('overlay', 0x63E0, 'cd ce 64', 'cd {RT2_QUICK}', 'TEMPORARY shop items down: no wait for the release'),
    # FINAL -> VOLVER in the three menus
    ('overlay', 0x6A10, 'ff 00 06 46 49 4e 41 4c', 'fa 00 00 00 00 00 00 00', 'shop screen: the line FINAL is printed by r2_shopscr'),
    ('overlay', 0x6A89, 'ff 11 13 46 49 4e 41 4c', 'fa 00 00 00 00 00 00 00', 'shop screen: the item-list FINAL, printed by r2_shopscr as well'),
    ('overlay', 0x62D7, 'dd 21 e2 69 cd f9 8b', 'cd {RT2_SHOPSCR} 00 00 00 00', 'shop screen: with VOLVER'),
    ('overlay', 0x6435, 'dd 21 87 6a cd 3b 61', 'cd {RT2_SHOPEXIT} 00 00 00 00', 'shop item list: VOLVER'),
    ('overlay', 0x612C, 'cd 3b 61', 'cd {RT2_CLASSPRINT}', 'character menu: VOLVER'),
    ('overlay', 0x5F02, 'cd ce 64', 'c3 {RT2_CODESAVE}', 'hero submenu GUARDAR: show the hero code'),
    ('overlay', 0x5F61, 'dd 21 9a 65', 'c3 {RT2_CODELOAD}', 'hero submenu CARGAR: ask for the hero code'),
    ('overlay', 0x6166, '21 9a 68 cd ef 64', 'cd {RT2_QMENU}', 'quest menu: two pages'),
    ('overlay', 0x617B, '3a f1 65 32 81 a9 c9', 'c3 {RT2_QFIRE}', 'quest menu: MAS / VOLVER and the quest number'),
    ('overlay', 0x5B06, 'cd 89 9f', ('call', 'rt_menu_input'), 'main menu: pointer'),
    ('overlay', 0x616C, 'cd 89 9f', ('call', 'rt_menu_input'), 'quest menu: pointer'),
    ('overlay', 0x5E37, 'cd 89 9f', ('call', 'rt_menu_input'), 'hero slots: pointer'),
    ('overlay', 0x5E9E, 'cd 89 9f', ('call', 'rt_menu_input'), 'hero submenu: pointer'),
    ('overlay', 0x6015, 'cd 89 9f', ('call', 'rt_menu_input'), 'name letters: pointer'),
    ('overlay', 0x6254, 'cd 89 9f', ('call', 'rt_menu_input'), 'spell groups: pointer'),
    ('overlay', 0x62EB, 'cd 89 9f', ('call', 'rt_menu_input'), 'shop heroes: pointer'),
    ('overlay', 0x6339, 'cd 89 9f', ('call', 'rt_menu_input'), 'shop items: pointer'),
    ('overlay', 0x5B21, '3e 05', '3e 04', 'main menu: four options (the tape option is gone)'),
    ('overlay', 0x5B2C, 'fe 04', 'fe 03', 'main menu: four options'),
    ('game', 0xFDE0, 'db 1f', 'c9', 'Kempston reader: no such port'),

    # ---- native drawing hooks (stage 2) -----------------------------------
    ('game', 0x9C02, 'cd ce 9c', ('jp', 'rt_showbackdrop'), 'ShowBackdrop: frame picture'),
    ('game', 0x8722, '22', ('call', 'rt_room'), 'BuildRoomView: room window, after SelectRoom', 3),
    ('game', 0x8B8C, '22', ('call', 'rt_floor'), 'DrawCellFloor', 3),
    ('game', 0x8B46, '2a', ('call', 'rt_wall'), 'BlitWallStrip', 3),

    # ---- stage 2: nothing is drawn through the Spectrum screen any more ---
    ('game', 0x8D03, 'dd 21', ('jp', 'rt_present'), 'BlitBackBuffer: present with VDP copies', 4),
    ('game', 0xA539, '21 00 fd', ('jp', 'rt_spr_mark'), 'DrawSpritesByDepth: drawn by rt_present'),
    ('game', 0xA8DE, '3a 89 a9', ('jp', 'rt_spr_unmark'), 'RestoreSprites: the sprite request ends with the pass'),
    ('game', 0xA7B6, 'dd 21 67 aa', 'c9', 'PrepareCursor: the pointer is a hardware sprite'),
    ('game', 0xA57E, 'dd 21 67 aa', 'c9', 'DrawCursor'),
    ('game', 0xA8FA, 'dd 21 67 aa', 'c9', 'RestoreCursor'),
    ('game', 0x8E6F, '06 08 7e', ('jp', 'rt_glyph'), 'PlotGlyph: native text'),
    ('game', 0x8DD1, 'd9 06 68', ('jp', 'rt_scroll'), 'DrawTextBox: textured native scrolls'),
    ('game', 0x9C4D, '21 00 e7', ('call', 'rt_clear_scene'), 'ClearBackBuffer'),
    ('game', 0x9C3F, '21 00 40', ('call', 'rt_clear_all'), 'ClearScreenBitmap'),

    # ---- work of the original that nothing needs any more ------------------
    ('game', 0x8B8F, 'dd 21', 'c9', 'DrawCellFloor: no tile into the buffer'),
    ('game', 0x8B49, '09 3e 32', 'c9', 'BlitWallStrip: no strip into the buffer'),
    ('game', 0xA865, 'd9 dd 6e 06', 'c9', 'PrepareSprite: no background save'),
    ('game', 0x9C42, '11 01 40', 'c9', 'ClearScreenBitmap: the display file is not used'),
    ('game', 0x9C50, '11 01 e7', 'c9', 'ClearBackBuffer: only the native scene is cleared'),
    ('game', 0x750B, 'cd 4d 9c', ('call', 'rt_map_plan'), 'board plan: buffer cleared for the line of sight, parchment'),
    ('game', 0xA3C8, 'cd db 8f', ('call', 'rt_map_show'), 'ShowBoardMap: parchment under the map'),
    ('game', 0x9C77, 'dd 21', 'c9', 'ClearRoomViewport: the room window is painted by rt_room'),

    ('game', 0x9A99, 'cd a6 9a', '', 'ShowCombatPicture: the picture is loaded into VRAM by rt_ldir'),

    # ---- overview map: native cells next to the original buffer drawing ----
    ('game', 0x9449, '06 08 d5', ('call', 'rt_maptile'), 'CopyMapTile'),
    ('game', 0x945C, '06 08 d5', ('call', 'rt_mapglyph'), 'OrMapGlyph'),
    ('game', 0x9410, 'cd ce 9c', ('call', 'rt_mapobj'), 'large map object (replaces call PageBank6)'),

    ('game', 0x7F65, '79 b6 77', ('call', 'rt_los_plot'), 'line of sight: point of the line'),
    ('game', 0xA3FB, 'e5 6f 26 00', ('jp', 'rt_portrait'), 'DrawFrameInverted: combat portraits'),

    # ---- tape options: not ported ------------------------------------------
    ('overlay', 0x5D3C, 'ca 1f 65', 'ca 00 5b', 'main menu option 4 (load other adventures): back to the menu'),
    ('overlay', 0x669E, '43 41 52 47 41 52 5f 4f 54 52 41 53 5f 41 56 45 4e 54 55 52 41 53',
     '5f 5f 5f 5f 5f 5f 5f 5f 5f 5f 5f 5f 5f 5f 5f 5f 5f 5f 5f 5f 5f 5f', 'and its menu line is blank'),

    ('game', 0x8060, 'cd 34 a5', ('call', 'rt_bake'), 'SearchCommand: sprites stay under the menu box'),
    ('game', 0x8DC8, 'cd 34 a5', ('call', 'rt_bake'), 'RebuildSceneBuffer: sprites stay under the message box'),

    # ---- overlay: border writes --------------------------------------------
    ('overlay', 0x5FE9, 'd3 fe', '', 'border port'),
    ('overlay', 0x6510, 'd3 fe', '', 'border port'),
    ('overlay', 0x651A, 'd3 fe', '', 'border port'),
    ('overlay', 0x6559, 'd3 fe', '', 'border port'),
]
