; Fixed addresses shared by the boot code (ROM) and the runtime (page 0 RAM)

RT_BASE         equ 0x0000      ; the runtime is copied here
RT_VARS         equ 0x0050      ; runtime variables (between the interrupt entry and 0066h)
rt_slot_rom1    equ RT_VARS+0   ; slot register value: page 1 = cartridge, others RAM
rt_slot_ram     equ RT_VARS+1   ; slot register value: all four pages RAM
rt_bank         equ RT_VARS+2   ; Spectrum port 7FFDh value last "paged" by the game
rt_seg          equ RT_VARS+3   ; ROM segment of the current copy
rt_sp           equ RT_VARS+4   ; game stack pointer while the runtime stack is in use (2)
rt_tick         equ RT_VARS+17  ; interrupt counter
rt_mouse_port   equ RT_VARS+18  ; joystick port with a mouse: 0 none, 1, 2
rt_mouse_try    equ RT_VARS+19  ; port polled last while no mouse is known (0, 1)
rt_mouse_miss   equ RT_VARS+20  ; consecutive polls without answer from the mouse
rt_mouse_btn    equ RT_VARS+21  ; not 0 while the left mouse button is down
rt_mouse_raw    equ RT_VARS+22  ; last offsets read: y, x (2)
rt_60hz         equ RT_VARS+24  ; not 0 on a 60 Hz machine
rt_music_skip   equ RT_VARS+25  ; counts interrupts to drop one music frame in six at 60 Hz
rt_mouse_btn2   equ RT_VARS+26  ; not 0 while the right mouse button is down
rt_opl          equ RT_VARS+27  ; not 0: an OPL4 (MoonSound) plays the music
rt_opl_play     equ RT_VARS+28  ; not 0 while an OPL4 tune is playing
rt_opl_tune     equ RT_VARS+29  ; tune whose samples are in the OPL4 wave RAM (FFh none)
rt_opl_seg      equ RT_VARS+30  ; ROM segment and address (4000h-7FFFh) of the next
rt_opl_ptr      equ RT_VARS+31  ; byte of the stream (2)
rt_opl_wait     equ RT_VARS+33  ; ticks without writes still to go
rt_opl_lseg     equ RT_VARS+34  ; loop point of the stream: segment, address (2)
rt_opl_lptr     equ RT_VARS+35
rt_msp          equ RT_VARS+37  ; stack pointer saved while RT_MSTACK is in use (2)
rt_mouse_click  equ RT_VARS+40  ; set when the left mouse button goes down; the menus clear it
rt_incode       equ RT_VARS+41  ; not 0 while the hero code program asks for letters
rt_language     equ RT_VARS+42  ; selected at boot: 0 Spanish, 1 English
rt_opl_once     equ RT_VARS+39  ; not 0: the OPL4 tune stops at its end instead of looping (intro)
RT_MSTACK       equ 0x0100      ; small stack for the OPL4 code (0078h-00FFh is free)

RT_CODE_END     equ 0x1B70      ; the runtime code and data end below this
RT_STACK        equ 0x1BF0      ; runtime stack top (grows down from here)
RT_BOUNCE       equ 0x1BF0      ; 256-byte bounce buffer for ROM -> RAM copies
SOUND_BASE      equ 0x1CF0      ; sound driver (the Spectrum's RAM bank 4 code and music, relocated)
RT_BOUNCE_SIZE  equ 0x0100

RT_CELLMAP      equ 0x4500      ; glyph shown in each of the 32 x 24 character cells (0 = none)
RT_ATTRSHADOW   equ 0x4800      ; attribute each cell was last drawn with

rt_cache_old    equ 0x4B00      ; sprites on the screen (1 + 14*7 bytes), zeroed at boot
rt_cache_new    equ 0x4B80      ; sprites wanted now

ROM_RUNTIME     equ 0x4400      ; where the runtime image sits in ROM segment 0
RT2_BASE        equ 0x4C00      ; second part of the runtime, in page 1 RAM: code that
RT2_SIZE        equ 0x0C00      ; never runs while the cartridge is in page 1
RT2_ROM         equ 0x6000      ; its image in ROM segment 0
RT2_SNDCMD      equ RT2_BASE    ; entries (jump table)
RT2_DETECT      equ RT2_BASE+3
RT2_MENU        equ RT2_BASE+6
RT2_QUEST       equ RT2_BASE+9
RT2_QMENU       equ RT2_BASE+12
RT2_QFIRE       equ RT2_BASE+15
RT2_XEXIT       equ RT2_BASE+18
RT2_XEVENT      equ RT2_BASE+21
RT2_PLAY        equ RT2_BASE+24
RT2_MONNUM      equ RT2_BASE+27
RT2_BREAK       equ RT2_BASE+30
RT2_STEP        equ RT2_BASE+33
RT2_ROCK        equ RT2_BASE+36
RT2_KEYLABEL    equ RT2_BASE+39
RT2_MIST        equ RT2_BASE+42
RT2_MAPMIST     equ RT2_BASE+45
RT2_CODESAVE    equ RT2_BASE+48
RT2_CODELOAD    equ RT2_BASE+51
RT2_CTRL        equ RT2_BASE+54
RT2_DIR         equ RT2_BASE+57
RT2_DIRWAIT     equ RT2_BASE+60
RT2_STEP5       equ RT2_BASE+63
RT2_QUICK       equ RT2_BASE+66      ; TEMPORARY (shop speed test)
RT2_SHOPSCR     equ RT2_BASE+69
RT2_SHOPEXIT    equ RT2_BASE+72
RT2_CLASSPRINT  equ RT2_BASE+75
RT2_AFTERITEM   equ RT2_BASE+78
RT2_AFTERHERO   equ RT2_BASE+81
RT2_JUMP        equ RT2_BASE+84
ZX_LETTERCUR    equ 0x60C4      ; ToggleLetterCursor (MenuCursor 0-26)
ZX_NAMELEN      equ 0x65F4      ; NameLength
ZX_NAMEFIELD    equ 0x6B03      ; TxtNameField: the name being typed, from +5
ZX_PRINTNORMAL  equ 0x613B     ; PrintThenNormal (overlay)
CTRL_ROM        equ 0xFD00      ; image of the options menu (src/ctrlmenu.asm) in the same bank
CTRL_SIZE       equ 0x0300
CODE_BASE       equ 0x4000      ; the hero code program runs here (src/savecode.asm)
CODE_ROM        equ 0xF800      ; its image in the second expansion bank
CODE_SIZE       equ 0x04F0      ; the loader's work area and the free bytes up to the cell map
SCROLL_BASE     equ 0x4100      ; transient renderer, shares the hero-code work area
SCROLL_ROM      equ 0x6C00      ; segment 0, after the second runtime image
SCROLL_SIZE     equ 0x0400
RT2_MNAMES      equ 0x5620      ; live monster tables, indexed by kind 0-15: names (words),
RT2_MPICS       equ 0x5640      ; death pictures (address, bank value),
RT2_MGLYPHS     equ 0x5670      ; map glyphs (words)
RT2_ROOMS       equ 0x5690      ; the two tables of search events, 43 bytes each
RT2_ROOMS_B     equ RT2_ROOMS+43
XMONSTERS       equ 0x6BB6      ; the 32 monster records (the base game has 25 at 6C0Ch)
ZX_DRAWMENUPAGE equ 0x64EF      ; DrawMenuPage (overlay)
ZX_PRINTSTRING  equ 0x8BF9      ; PrintString
ZX_BLIT         equ 0x8D03      ; BlitBackBuffer (rt_present)
ZX_QUESTINDEX   equ 0xA981      ; QuestIndex
ZX_GETTABLEWORD equ 0xA978      ; GetTableWord: DE = word at HL + 2*A
ZX_QUESTPTRS    equ 0x6637      ; QuestDataPtrs (overlay)
ZX_TXTQUESTMENU equ 0x689A      ; TxtQuestMenu (overlay)
ZX_QMENU_REDRAW equ 0x6166      ; PlayOption: draw the quest menu
ZX_QMENU_COUNT  equ 0x618C      ; operand: number of lines (wrap from the first to the last)
ZX_QMENU_LAST   equ 0x6197      ; operand: last line
ZX_WAITRELEASE  equ 0x64CE      ; WaitInputRelease (overlay)
ZX_SEARCHTAB    equ 0x82A2      ; QuestSearchHandlers: 18 words
ZX_ADDGOLD      equ 0x8221      ; AddGold: DE coins to the current hero
ZX_SHOWBOX      equ 0x8FCF      ; ShowBoxAndPause: IX = text window
ZX_GIVEGOLD     equ 0x9067      ; GiveGoldShowBox: DE coins, IX = window
ZX_GIVEPOTION   equ 0x9057      ; GivePotionAndGold: IY = hero, DE, IX
ZX_TRAPKILLS    equ 0x90A6      ; TrapKillsHero
ZX_GOLD200      equ 0x9173      ; TreasGold200 (event 18 of the base game)
ZX_GOLDHUD      equ 0x91F7      ; UpdateGoldHud
ZX_BODYHUD      equ 0x926A      ; UpdateBodyMindHud
ZX_CURHERO      equ 0xA9DD      ; CurHeroPtr
ZX_BOX_TRAP     equ 0xBD30      ; window: the chest holds a trap, lose 1 point
ZX_BOX_DISARM   equ 0xBD76      ; window: the chest holds a trap, you disarm it
HERO_BODY       equ 6           ; fields of the hero record
HERO_QFLAGS     equ 15
HERO_POTIONS    equ 16
ZX_PLAYQUEST    equ 0x6D89      ; PlayQuest
ZX_WAITFIRE     equ 0x8DA3      ; WaitFirePressRelease
ZX_REDRAW       equ 0xA987      ; RedrawRequest
ZX_OBJECTS      equ 0x6600      ; object layer of the board, 26 cells per row
ZX_TYPETAB      equ 0xAA8C      ; MonsterTypeTable: move, attack, defend, death handler (5 bytes)
ZX_NODEATH      equ 0x9A25      ; the death handler of the ordinary monsters (a RET)
ZX_IMMUNE1      equ 0x7563      ; "inc a / and FEh / cp 0Ch": types only the Spirit Blade harms
ZX_IMMUNE2      equ 0x792C      ; the same test for the spells
ZX_REDRAWROOM   equ 0x8295      ; RequestRoomRedraw
ZX_RANDOM6      equ 0x9BD3      ; Random0To5: C = 0-5
ZX_MAPCELLAT    equ 0x89AD      ; MapCellAt: C = x, B = y -> HL
ZX_MAPCELLOFF   equ 0xA0D4      ; MapCellOffset: E = x, D = y -> HL
ZX_PROBECELL    equ 0x9FAF      ; ProbeCellOccupancy
ZX_LASTDOOR     equ 0xA9BF      ; LastDoorCell
ZX_HEROINDEX    equ 0xA998      ; CurHeroIndex
ZX_TARGETHERO   equ 0xA9AD      ; TargetHeroIndex
ZX_TARGETID     equ 0xA9BB      ; TargetId
ZX_ROCKONHERO   equ 0xA1AC      ; HandleTrapEvent: the rock falls on another hero
ZX_TXT_FAILED   equ 0xB8F7      ; "EL ATAQUE HA FRACASADO"
ZX_TXT_MAGNUS   equ 0xB82E      ; "ORO MAGNUS"
ZX_GETHERO      equ 0x7B62      ; GetHeroRecord: A = hero -> IX
ZX_KILLHERO     equ 0x7B31      ; KillHero
ZX_REVEAL       equ 0xA2EB      ; RevealLineOfSight, entered with IY = the figure
ZX_TXT_MORCAR   equ 0xA438      ; "ES EL TURNO DE MORCAR"
ZX_DRAWMAP      equ 0x92A0      ; DrawBoardMap
ZX_COLOURMAP    equ 0x94F8      ; ColourMapRevealed
ZX_WAITFRAMES   equ 0x9D66      ; WaitFrames: B frames
ZX_PRINTBLIT    equ 0x991B      ; PrintTextAndBlit
ZX_CLEARBITMAP  equ 0x9C3F      ; ClearScreenBitmap
ZX_ORMAPGLYPH   equ 0x945C      ; OrMapGlyph: HL = glyph, DE = buffer cell
ZX_MAPDOT       equ 0xB1C0      ; MapDotGlyph (map glyph 0)
ZX_MAPPLAIN     equ 0xA9A1      ; MapPlainMarkers
ZX_MISTGLYPH    equ 0xB2C8      ; "address" of map glyph 33, the Death Mist (the native map only uses its number)
ZX_ROOMLAYER    equ 0x6200      ; room layer of the board: bit 7 known, bit 6 explored
ZX_SETUP_NEXT   equ 0x5CA3      ; quest set-up: next monster record
HERO_ROOM       equ 3
ZX_TOGGLEBAR    equ 0x64D7      ; ToggleMenuBar: highlight of menu line MenuCursor
ZX_MUSICON      equ 0x6FD6      ; MusicOn
ZX_FONTFLAG     equ 0xA982      ; 0 = the first font, 1 = the second one
ZX_STARTTUNE    equ 0x7BC5      ; StartTune: D = tune (0 silence, 2 menus)
ZX_MAINMENU     equ 0x5B00      ; OverlayEntryA
BASE_QUESTS     equ 14          ; quests of the base game; the expansion quests follow
RT2_BUF         equ 0x5780      ; 128-byte buffer: sample upload and texts fetched from ROM
INTRO_BASE      equ 0x8000      ; the intro runs here, before the game is copied

; ROM segments
SEG_GAME        equ 1           ; 3 segments: Spectrum image 6400h-FFFDh
SEG_BANK4       equ 4
SEG_BANK1       equ 5
SEG_BANK3       equ 6
SEG_BANK6       equ 7
SEG_BANK7       equ 8
SEG_SOUND       equ 8           ; the sound driver image, at 1000h of that segment
SOUND_ROM       equ 0x5000

; Spectrum addresses used by the runtime
ZX_SCREEN       equ 0x4000
ZX_ATTRS        equ 0x5800
GAME_START      equ 0x6400      ; ColdStart
GAME_IRQ_JP     equ 0xFDFD      ; "jp InterruptHandler", written by ColdStart
GAME_INPUT      equ 0xA997      ; InputBits: 0 right, 1 left, 2 down, 3 up, 4 fire
GAME_MENUCURSOR equ 0x65F1      ; MenuCursor of the overlay; HeroSlotCursor is the byte before
ZX_READINPUT    equ 0x9F89      ; ReadInput
ZX_CLEARALL     equ 0x8FDB      ; ClearScreenAndBuffer
GAME_CURSOR_X   equ 0xAA69      ; CursorX: centre of the 24-pixel Spectrum pointer, 0Ch..FCh
GAME_CURSOR_Y   equ 0xAA6A      ; CursorY: buffer line below the pointer, 08h..AEh
CURSOR_MIN_X    equ 0x0C
CURSOR_MAX_X    equ 0xFC
CURSOR_MIN_Y    equ 0x08
CURSOR_MAX_Y    equ 0xAE

; MSX hardware
VDP_DATA        equ 0x98
VDP_CTRL        equ 0x99
VDP_PAL         equ 0x9A
VDP_REGS        equ 0x9B        ; indirect register access (R#17)
VCMD_HMMV       equ 0xC0        ; fill, byte aligned
VCMD_LMMM_TIMP  equ 0x98        ; copy VRAM to VRAM, colour 0 transparent
PPI_SLOT        equ 0xA8
PPI_KEYS        equ 0xA9
PPI_ROW         equ 0xAA
PSG_ADDR        equ 0xA0
PSG_WRITE       equ 0xA1
PSG_READ        equ 0xA2
OPL4_FM         equ 0xC4        ; FM bank 0 address port, and the status port
OPL4_FM2        equ 0xC6        ; FM bank 1 address port
OPL4_WAVE       equ 0x7E        ; wave part address port
SPR_PATTERNS    equ 0x7800      ; sprite tables in the hidden lines of VRAM page 0
SPR_COLOURS     equ 0x7400      ; (the SCREEN 5 defaults of the BIOS)
SPR_ATTRS       equ 0x7600
ASCII16_PAGE1   equ 0x6000      ; mapper register: segment shown at 4000h-7FFFh
