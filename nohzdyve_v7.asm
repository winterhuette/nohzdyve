; NOHZDYVE Amiga 500 / A570 / CDTV - V7.8b DISPLAY FIX / CONNECTED OPENING / GAMEPLAY-ONLY ZX AUDIO
; (based on V7.8a TITLE MENU / MULTI-INPUT / AUDIO OPTIONS - INPUT FIX)
; This revision intentionally contains no absolute-address binary patch logic.
; All gameplay changes are labels/routines assembled as one program.
; Derived from the known-working v5.2 startup/display source plus the readable
; nohzdyve-master object/animation data and the user's Spectrum video reference.
;
; NOHZDYVE Amiga 500 / Kickstart 1.3 / CDTV port - v5.2 performance+scroll revision
; Gameplay reference: original ZX Spectrum nohzdyve.tap supplied by user.
; Startup/display base: user's working nohzdyve2.asm pattern.
;
; Target: 68000, OCS, PAL, KS1.3, 512 KiB Chip RAM
; V5.2: CDTV/KS1.3 performance pass: unrolled framebuffer clear, bitmap brick walls,
; byte-aligned scrolling scenery, restored upward-scrolling yellow side/window object,
; cyan fan color, slower 54-frame entry, and restored side-object collision path.
; Build example:
;   vasmm68k_mot -m68000 -Fhunkexe -o Nohzdyve nohzdyve_a500_v4.asm
;
; NOTE: this source intentionally uses a simple CPU-rendered Bob layer.
; It prioritizes original mechanics/assets over optimization. Once verified,
; the same renderer can be replaced with blitter Bobs without changing game logic.
;
; V5 REVISION: adds entry sequence, score/high-score display, death animation,
; dynamic object colors, denser shaft scenery, dual-port joystick support, and
; removes the artificial post-respawn invulnerability workaround.
; Colors were sampled directly from the user's reference screenshots of the
; real game (walls, player, eyeball, title logo) since no attribute-byte
; data was extracted from the original TAP - see draw call sites below for
; the per-object color assignments and reasoning.

LOADADDR equ $40000
        section code
        org     LOADADDR

LVOOpenLibrary  equ -552
LVOCloseLibrary equ -414
LVOLoadView     equ -222
LVOWaitTOF      equ -270
LVOSupervisor   equ -30
LVODisable      equ -120
LVOEnable       equ -126
LVOFindTask     equ -294
LVOAllocSignal  equ -330
LVOFreeSignal   equ -336
LVOOpenDevice   equ -444
LVOCloseDevice  equ -450
LVODoIO         equ -456
LVOSendIO       equ -462
LVOCheckIO      equ -468
LVOWaitIO       equ -474
LVOAbortIO      equ -480
LVOAddIntServer equ -168
LVORemIntServer equ -174
INTB_VERTB      equ 5
NT_INTERRUPT    equ 2

gb_ActiView     equ 34

CUSTOM      equ $dff000
DMACON      equ CUSTOM+$096
INTENA      equ CUSTOM+$09a
INTREQ      equ CUSTOM+$09c
AUD0LCH     equ CUSTOM+$0a0
AUD0LEN     equ CUSTOM+$0a4
AUD0PER     equ CUSTOM+$0a6
AUD0VOL     equ CUSTOM+$0a8
AUD1LCH     equ CUSTOM+$0b0
AUD1LEN     equ CUSTOM+$0b4
AUD1PER     equ CUSTOM+$0b6
AUD1VOL     equ CUSTOM+$0b8
AUD2LCH     equ CUSTOM+$0c0
AUD2LEN     equ CUSTOM+$0c4
AUD2PER     equ CUSTOM+$0c6
AUD2VOL     equ CUSTOM+$0c8
AUD3LCH     equ CUSTOM+$0d0
AUD3LEN     equ CUSTOM+$0d4
AUD3PER     equ CUSTOM+$0d6
AUD3VOL     equ CUSTOM+$0d8
COP1LCH     equ CUSTOM+$080
COP1LCL     equ CUSTOM+$082
COPJMP1     equ CUSTOM+$088
JOY0DAT     equ CUSTOM+$00a
JOY1DAT     equ CUSTOM+$00c
VHPOSR      equ CUSTOM+$006
CIAAPRA     equ $bfe001
CIADDRA     equ $bfe201       ; CIA-A Data Direction Register A (OVL=bit0, LED=bit1)
CIAATODLO   equ $bfe801       ; CIA-A TOD low byte, advances from PAL VBlank

SCREEN_W        equ 320
SCREEN_H        equ 256
ROWBYTES        equ 40
PLANESIZE       equ ROWBYTES*SCREEN_H
VIEW_X          equ 32          ; centered original 256x192 Spectrum playfield
VIEW_Y          equ 32
WORLD_W         equ 256
WORLD_H         equ 192

; Fixed window position (screen coordinates, not world-relative) - the
; player exits through this at the start of each life. Position estimated
; from the reference video (window sits on the left wall roughly 60% down
; the shaft) - not pixel-exact, a reasonable read of the footage.
WINDOW_X        equ VIEW_X+4
WINDOW_Y        equ VIEW_Y+118

STATE_TITLE      equ 0
STATE_ENTER      equ 1
STATE_PLAY       equ 2
STATE_DEAD       equ 3
STATE_GAMEOVER   equ 4
STATE_TITLE_EXIT equ 5
STATE_OPTIONS    equ 6
STATE_HISCORE    equ 7
STATE_EXIT       equ 8
STATE_CREDITS    equ 9
STATE_HISCORE_ENTRY equ 10

; v7.8 title/options input.
CONTROL_AUTO     equ 0
CONTROL_JOYSTICK equ 1
CONTROL_MOUSE    equ 2
CONTROL_CURSOR   equ 3

MENU_START       equ 0
MENU_OPTIONS     equ 1
MENU_HISCORE     equ 2
MENU_CREDITS     equ 3
MENU_EXIT        equ 4

OPT_CONTROL      equ 0
OPT_DIGI         equ 1
OPT_SOUNDFX      equ 2
OPT_BACK         equ 3

UI_UP            equ 1
UI_DOWN          equ 2
UI_SELECT        equ 4
UI_BACK          equ 8

KBD_READMATRIX   equ 11
KBD_MATRIX_LEN   equ 13          ; mandatory length for Kickstart V34 and earlier
NT_MSGPORT       equ 4
NT_MESSAGE       equ 5
PA_SIGNAL        equ 0

; Original collision thresholds from the ZX code around $8537.
PLAYER_LEFT_DEAD  equ $13
PLAYER_RIGHT_DEAD equ $de

; 8-color palette, indices match COLOR0-7 in the copper list below.
COL_BLACK   equ 0
COL_BLUE    equ 1
COL_RED     equ 2
COL_MAGENTA equ 3
COL_GREEN   equ 4
COL_CYAN    equ 5
COL_YELLOW  equ 6
COL_WHITE   equ 7

; Title-menu palette. Kept as named constants so screenshot matching can be
; tuned without touching any menu logic.
MENU_START_COLOR   equ COL_GREEN
MENU_OPTIONS_COLOR equ COL_CYAN
MENU_HISCORE_COLOR equ COL_MAGENTA
MENU_CREDITS_COLOR equ COL_WHITE
MENU_EXIT_COLOR    equ COL_YELLOW

; ZX Spectrum beeper -> Paula PCM transport.
; Each PCM asset is one 50 Hz slot (250 signed 8-bit bytes).  The actual
; recovered Z80 beeper routine occupies only its original ~3-10 ms at the
; beginning of that slot; the rest is silence.  This preserves the clipped,
; per-frame Spectrum character instead of stretching each event into a drone.
ZX_AUDIO_PERIOD equ 284             ; 3.546895 MHz / 284 = 12489.1 samples/s
ZX_AUDIO_SHORT_LEN equ 250          ; 500 bytes = 20 ms sound + 20 ms guard silence
ZX_AUDIO_NOTE_LEN  equ 1000         ; 2000 bytes = exact 160 ms normal-note slot
ZX_AUDIO_EYE_LEN   equ 1500         ; 3000 bytes = 11 ZX frames + guard
ZX_AUDIO_DEATH_LEN equ 3625         ; 7250 bytes = 28 ZX frames + guard
ZX_AUDIO_VOL       equ 32

; Separate low-fi 8-bit Paula sample bank.  The boot build preloads it at
; $60000; all runtime access goes through sample_bank_ptr so a later AmigaDOS
; / Shell build can load the same bank file anywhere in Chip RAM and bind it.
        include "sample_bank.inc"
        include "gfx/menu/menu_assets.inc"
SAMPLE_VOICE_NONE equ $ff

; New-game dialogue state.  Stefan speaks first, Colin answers, then the
; window-exit animation is allowed to begin.
SAMPLE_OPEN_NONE       equ 0
SAMPLE_OPEN_STEFAN     equ 1
SAMPLE_OPEN_GAP        equ 2
SAMPLE_OPEN_COLIN      equ 3
SAMPLE_OPEN_RESP_STYLE equ 1
SAMPLE_OPEN_RESP_FAIR  equ 2

; v7.8 starts from the supplied v7.7f baseline: every spoken line is an independent 8 kHz one-shot.
; There is no title PCM hidden inside another voice sample any more.

; Fixed entry vectors. Boot uses $40000; the AmigaDOS Shell launcher uses
; $40004. Keep both vectors exactly four bytes (BRA.W).
start:
        bra.w   start_boot
shell_start:
        bra.w   start_shell

start_boot:
        clr.b   shell_mode
        bra.s   start_common
start_shell:
        move.b  #1,shell_mode
start_common:
        move.l  4.w,a6
        lea     gfxname,a1
        moveq   #0,d0
        jsr     LVOOpenLibrary(a6)
        move.l  d0,gfxbase
        beq     nogfx

        move.l  d0,a6
        move.l  gb_ActiView(a6),oldview

        ; Proven-good KS1.3 handover used by the user's title-screen build.
        suba.l  a1,a1
        jsr     LVOLoadView(a6)
        jsr     LVOWaitTOF(a6)
        jsr     LVOWaitTOF(a6)

        ; Set up valid CHIP buffer pointers before Copper/bitplane DMA starts.
        ; This avoids the first-frame zero-pointer fetch present in v4.
        lea     bitplaneA0,a0
        move.l  a0,frontbuf0
        lea     bitplaneA1,a0
        move.l  a0,frontbuf1
        lea     bitplaneA2,a0
        move.l  a0,frontbuf2
        lea     bitplaneB0,a0
        move.l  a0,backbuf0
        lea     bitplaneB1,a0
        move.l  a0,backbuf1
        lea     bitplaneB2,a0
        move.l  a0,backbuf2

        bsr     clear_backbuffer
        bsr     clear_frontbuffer
        clr.b   copper_active               ; copperlistA goes live first
        bsr     prime_copper_front
        ; v7.8b: COP1LCH (high word) is written exactly once, here, while
        ; Copper DMA is still off.  Both lists share the same high word (checked
        ; at assembly time next to the lists), so present_frame only ever
        ; rewrites COP1LCL and never strobes COPJMP1.
        lea     copperlistA,a0
        move.l  a0,COP1LCH
        move.w  #0,COPJMP1

        ; v7.8b: true 50 Hz PAL time base.  A tiny VERTB interrupt server counts
        ; fields so every audio/dialogue/intro timer advances by real elapsed
        ; time instead of by rendered frames (the CPU renderer often needs more
        ; than one field per frame, which used to stretch the opening dialogue).
        move.l  a6,-(sp)
        move.l  4.w,a6
        moveq   #INTB_VERTB,d0
        lea     vbl_interrupt,a1
        jsr     LVOAddIntServer(a6)
        move.l  (sp)+,a6
        move.l  vbl_counter,audio_vbl_seen
        move.w  #$8380,DMACON       ; MASTER + BPL + COPPER
        ; Explicitly disable sprite DMA. We don't use hardware sprites
        ; anywhere in this renderer, but DMACON writes with the SET bit
        ; only ever ADD bits - they never clear ones already on. The OS
        ; has SPREN enabled before we start (Intuition's mouse pointer
        ; needs it), so without this it stays on for our program's whole
        ; run, and the OS's last-set sprite pointer keeps rendering every
        ; frame - using COLOR16+ sprite-color registers our Copper list
        ; never touches, so it shows up in whatever colors Workbench had
        ; left there. This is almost certainly the persistent unexplained
        ; colored block seen in the HUD across multiple otherwise-
        ; unrelated renderer rewrites (same artifact, v5 through v7,
        ; despite completely different bitplane-drawing code each time).
        move.w  #$0020,DMACON       ; clear SPREN
        bsr     zx_audio_init
        bsr     sample_audio_init
        bsr     v78_input_init
        ; DIAGNOSTIC: force the keyboard.device path off (joystick/mouse are
        ; untouched) to prove or rule out keyboard I/O as the cause of the
        ; post-first-input freeze. Revert this line once that's settled.
        clr.b   keyboard_available

        bsr     game_to_title

main_loop:
        ; v7.8: there is deliberately NO global mouse-button quit path.
        ; EXIT is available only as an explicit title-menu action in every build.
        move.b  game_state,d0
        cmp.b   #STATE_TITLE,d0
        beq     v7_title_tick
        cmp.b   #STATE_OPTIONS,d0
        beq     v78_options_tick
        cmp.b   #STATE_HISCORE,d0
        beq     v78_hiscore_tick
        cmp.b   #STATE_EXIT,d0
        beq     v78_exit_tick
        cmp.b   #STATE_CREDITS,d0
        beq     v78_credits_tick
        cmp.b   #STATE_HISCORE_ENTRY,d0
        beq     v78_hiscore_entry_tick
        cmp.b   #STATE_TITLE_EXIT,d0
        beq     v7_title_exit_tick
        cmp.b   #STATE_ENTER,d0
        beq     v7_enter_tick
        cmp.b   #STATE_PLAY,d0
        beq     v7_play_tick
        cmp.b   #STATE_DEAD,d0
        beq     v7_dead_tick
        bra     v7_gameover_tick

; -----------------------------------------------------------------------------
; GAME INIT / STATE
; -----------------------------------------------------------------------------
game_new:
        clr.w   score
        move.b  #3,lives
        clr.b   player_y_index
        clr.b   eye_table_index
        move.w  #$1234,rng_state
        bsr     round_reset
        bsr     entry_reset
        move.b  #STATE_ENTER,game_state
        rts

round_reset:
        move.w  #140,player_x
        clr.b   player_vx
        move.w  #$88,player_y
        clr.b   player_anim

        move.w  #128,teeth_x
        move.w  #190,teeth_y
        move.b  #1,teeth_vx
        clr.b   teeth_frame
        move.b  #COL_RED,teeth_color

        move.w  #190,eye_y
        clr.b   eye_frame
        bsr     respawn_eye

        move.w  #203,fan_y
        move.b  #0,fan_side
        clr.b   fan_frame

        move.w  #118,sideobj_y
        move.b  #0,sideobj_side
        clr.b   sideobj_frame

        clr.w   world_scroll
        clr.w   death_timer
        rts

entry_reset:
        ; Reference video: player comes out of the left-side opening first,
        ; then transitions to the normal two-frame falling state. Y matches
        ; WINDOW_Y (the fixed window's position, ~60% down the shaft per
        ; the video) rather than the previous guess of 66, which sat too
        ; high up compared to the footage.
        move.w  #24,player_x
        move.w  #118,player_y
        clr.b   player_vx
        clr.b   player_anim
        clr.w   entry_timer
        rts

enter_tick:
        addq.w  #1,entry_timer
        addq.w  #2,player_x
        addq.b  #1,player_anim
        bsr     update_side_objects
        bsr     render_game
        bsr     present_frame
        cmp.w   #132,player_x
        blt     main_loop
        move.w  #140,player_x
        clr.b   player_y_index
        clr.b   player_vx
        ; Grace period before collisions start counting. The reconstructed
        ; teeth spawn trajectory (128,190 heading toward the player's fixed
        ; x=140 spawn column) crosses the player within ~7-9 frames of PLAY
        ; starting, regardless of how long the entry sequence ran first -
        ; verified by simulation, this isn't a timing quirk that entry
        ; delay alone fixes. Without this, PLAY is unwinnable by construction.
        move.w  #26,collision_grace
        move.b  #STATE_PLAY,game_state
        bra     main_loop

; -----------------------------------------------------------------------------
; ACTIVE GAME - one logic update per PAL frame, matching Spectrum HALT cadence.
; -----------------------------------------------------------------------------
play_tick:
        bsr     read_player_input
        bsr     update_player
        bsr     update_teeth
        bsr     update_eye
        bsr     update_side_objects
        tst.w   collision_grace
        beq   .do_collide
        subq.w  #1,collision_grace
        bra   .skip_collide
.do_collide:
        bsr     collisions
.skip_collide:
        bsr     render_game
        bsr     present_frame
        bra     main_loop

read_player_input:
        ; Accept either physical Amiga controller port. Horizontal direction
        ; bits are direct on JOYxDAT (bit 9 left, bit 1 right).
        move.w  JOY1DAT,d0
        move.w  JOY0DAT,d2
        moveq   #0,d1
        btst    #9,d0
        bne   .left
        btst    #9,d2
        beq   .chk_right
.left:
        moveq   #-4,d1
.chk_right:
        btst    #1,d0
        bne   .right_seen
        btst    #1,d2
        beq   .apply
.right_seen:
        tst.b   d1
        bne   .both
        moveq   #4,d1
        bra   .apply
.both:
        moveq   #0,d1
.apply:
        tst.b   d1
        beq   .decay
        move.b  d1,player_vx
        rts
.decay:
        move.b  player_vx,d0
        beq   .done
        cmp.b   #1,d0
        beq   .done
        cmp.b   #-1,d0
        beq   .done
        ext.w   d0
        asr.w   #1,d0
        move.b  d0,player_vx
.done:
        rts

update_player:
        moveq   #0,d0
        move.b  player_vx,d0
        ext.w   d0
        add.w   d0,player_x

        ; Exact original 256-byte vertical fall/bob table at ZX $F300.
        moveq   #0,d0
        move.b  player_y_index,d0
        lea     original_player_y_table_F300,a0
        move.b  (a0,d0.w),d1
        and.w   #$00ff,d1
        move.w  d1,player_y
        addq.b  #1,player_y_index

        addq.b  #1,player_anim
        and.b   #7,player_anim
        rts

update_teeth:
        moveq   #0,d0
        move.b  teeth_vx,d0
        ext.w   d0
        add.w   d0,teeth_x
        cmp.w   #17,teeth_x
        bge   .right_bound
        move.w  #17,teeth_x
        neg.b   teeth_vx
.right_bound:
        cmp.w   #207,teeth_x
        ble   .vertical
        move.w  #207,teeth_x
        neg.b   teeth_vx
.vertical:
        subq.w  #3,teeth_y
        cmp.w   #3,teeth_y
        bge   .anim
        bsr     respawn_teeth
.anim:
        addq.b  #1,teeth_frame
        and.b   #7,teeth_frame
        rts

respawn_teeth:
        bsr     random16
        move.w  d0,d2
        and.w   #$007f,d0
        add.w   #48,d0
        move.w  d0,teeth_x
        move.w  #190,teeth_y
        ; Reference video shows hazard colors changing. Pick one of the
        ; bright danger colors on each respawn.
        move.w  d2,d0
        lsr.w   #8,d0
        and.w   #3,d0
        lea     hazard_colors,a0
        move.b  (a0,d0.w),teeth_color
        bsr     random16
        btst    #0,d0
        beq   .left
        move.b  #1,teeth_vx
        rts
.left:
        move.b  #-1,teeth_vx
        rts

; Real MSX algorithm (controller_eyeball_moving / controller_eyeball_create):
; NOT a lookup table - the eye bounces +/-1px/tick within a 32px-wide
; corridor whose position is randomized fresh each spawn. Confirmed
; against the actual nohzdyve-master MSX source per the user's request
; to prioritize it for animation/placement over the earlier ZX-video-
; derived table approximation (which was structurally wrong, not just
; imprecise - flagged as an open question in earlier implementation
; notes and now resolved).
update_eye:
        moveq   #0,d0
        move.b  eye_hdir,d0
        ext.w   d0
        move.w  eye_x,d1
        add.w   d0,d1
        tst.b   eye_hdir
        bmi   .going_left
.going_right:
        cmp.w   eye_max_column,d1
        blt   .save
        move.b  #-1,eye_hdir
        bra   .save
.going_left:
        cmp.w   eye_min_column,d1
        bge   .save
        move.b  #1,eye_hdir
.save:
        move.w  d1,eye_x

        subq.w  #2,eye_y            ; exact original -EYE_SPEED(2) rate
        bgt   .anim
        bsr     respawn_eye
.anim:
        addq.b  #1,eye_frame
        and.b   #$0f,eye_frame
        rts

; Real MSX corridor randomization (controller_eyeball_create):
; base = random(0..159); min_column = base+24; mid = min+16; max = min+32.
respawn_eye:
        bsr     random16
        and.w   #$00ff,d0
        cmp.w   #160,d0
        blt   .baseok
        sub.w   #160,d0
.baseok:
        add.w   #24,d0
        move.w  d0,eye_min_column
        move.w  d0,d1
        add.w   #16,d1
        move.w  d1,eye_x
        add.w   #16,d1
        move.w  d1,eye_max_column

        bsr     random16
        move.w  d0,d1
        lsr.w   #8,d1
        and.w   #3,d1
        lea     eye_colors,a0
        move.b  (a0,d1.w),eye_color

        bsr     random16
        cmp.b   #128,d0
        blo   .left
        move.b  #1,eye_hdir
        bra   .ydone
.left:
        move.b  #-1,eye_hdir
.ydone:
        move.w  #191,eye_y          ; exact EYE_LINE
        rts

update_side_objects:
        ; Reference video + original $9Cxx side-state behavior: wall-mounted
        ; objects move upward with the shaft. Both objects advance by one pixel
        ; per PAL logic tick. The previous v5 fixed the yellow window/object on
        ; screen, which is visibly wrong in the reference footage.
        addq.w  #1,world_scroll

        subq.w  #1,fan_y
        bgt   .fan_anim
        move.w  #203,fan_y
        bsr     random16
        and.b   #1,d0
        move.b  d0,fan_side
.fan_anim:
        addq.b  #1,fan_frame
        and.b   #$0f,fan_frame

        subq.w  #1,sideobj_y
        bgt   .side_anim
        move.w  #203,sideobj_y
        bsr     random16
        and.b   #1,d0
        move.b  d0,sideobj_side
.side_anim:
        addq.b  #1,sideobj_frame
        and.b   #$1f,sideobj_frame
        rts

; -----------------------------------------------------------------------------
; COLLISION. Uses original world-space spans recovered from $85F9..$86AC.
; -----------------------------------------------------------------------------
collisions:
        move.w  player_x,d0
        cmp.w   #PLAYER_LEFT_DEAD,d0
        blt     player_kill
        cmp.w   #PLAYER_RIGHT_DEAD,d0
        bge     player_kill

        ; player vs teeth: player X+1..+17, Y+1..+26
        move.w  teeth_x,d2
        move.w  teeth_y,d3
        move.w  #31,d4
        move.w  #20,d5
        bsr     collide_player_rect
        tst.b   d0
        bne     player_kill

        ; collectible eyeball: approximate original width from $867D (+0x0e)
        move.w  eye_x,d2
        move.w  eye_y,d3
        move.w  #15,d4
        move.w  #22,d5
        bsr     collide_player_rect
        tst.b   d0
        beq   .sidehaz
        addq.w  #1,score            ; internal counter; HUD displays score*10
        bsr     respawn_eye

.sidehaz:
        ; left/right fan is lethal only when it protrudes into the shaft.
        move.w  fan_y,d3
        move.w  #22,d5
        moveq   #0,d2
        tst.b   fan_side
        beq   .fan_left
        move.w  #224,d2
        bra   .fan_test
.fan_left:
        move.w  #0,d2
.fan_test:
        move.w  #32,d4
        bsr     collide_player_rect
        tst.b   d0
        bne     player_kill

        ; Yellow wall window/object: second original side/scenery collision path.
        move.w  sideobj_y,d3
        move.w  #22,d5
        moveq   #0,d2
        tst.b   sideobj_side
        beq   .so_left
        move.w  #232,d2
.so_left:
        move.w  #24,d4
        bsr     collide_player_rect
        tst.b   d0
        bne     player_kill
        rts

; d2=x, d3=y, d4=width, d5=height -> d0.b=1 collision
collide_player_rect:
        move.w  player_x,d0
        addq.w  #1,d0
        move.w  d0,d6
        add.w   #16,d6
        move.w  d2,d7
        add.w   d4,d7
        cmp.w   d7,d0
        bge   .no
        cmp.w   d6,d2
        bge   .no

        move.w  player_y,d0
        addq.w  #1,d0
        move.w  d0,d6
        add.w   #25,d6
        move.w  d3,d7
        add.w   d5,d7
        cmp.w   d7,d0
        bge   .no
        cmp.w   d6,d3
        bge   .no
        moveq   #1,d0
        rts
.no:
        moveq   #0,d0
        rts

player_kill:
        cmp.b   #STATE_DEAD,game_state
        beq   .pk_done
        move.b  #STATE_DEAD,game_state
        move.w  #22,death_timer
.pk_done:
        rts

; -----------------------------------------------------------------------------
; DEATH / GAME OVER
; -----------------------------------------------------------------------------
dead_tick:
        bsr     render_game
        bsr     draw_death_explosion
        bsr     present_frame
        subq.w  #1,death_timer
        bgt     main_loop
        subq.b  #1,lives
        bne   .again
        bsr     update_highscore
        tst.b   high_score_new
        beq.s   .no_new_hs
        bsr     v78_hiscore_entry_begin
        move.b  #STATE_HISCORE_ENTRY,game_state
        bra     main_loop
.no_new_hs:
        move.b  #STATE_GAMEOVER,game_state
        bra     main_loop
.again:
        bsr     round_reset
        bsr     entry_reset
        move.b  #STATE_ENTER,game_state
        bra     main_loop

gameover_tick:
        bsr     render_gameover
        bsr     present_frame
        bsr     fire_pressed
        tst.b   d0
        beq     main_loop
        bsr     game_to_title
        bra     main_loop

game_to_title:
        ; The title is not a separate background.  It is the same shaft scene
        ; that gameplay starts from, with logo/instructions overlaid.  This
        ; matches the reference transition where the background does not jump.
        bsr     zx_audio_disable
        bsr     sample_audio_stop_all
        bsr     sample_attract_reset
        bsr     v7_scene_reset
        clr.b   v7_title_exit_phase
        clr.b   v7_intro_active
        clr.b   title_menu_item
        clr.b   active_control
        bsr     v78_mouse_sync
        bsr     v78_ui_reset_edges
        move.b  #STATE_TITLE,game_state
        rts

; -----------------------------------------------------------------------------
; RENDERING
; Colors below were sampled directly from the user's reference screenshots
; of the real game (walls, player, eyeball) rather than guessed:
;   - left wall: red, right wall: magenta (matches the reference exactly)
;   - player: white (matches the reference exactly)
;   - eyeball (collectible): magenta (matches the reference exactly)
;   - fan/aircon: cyan in the supplied gameplay video
;   - side/window object: yellow in the supplied gameplay video
;   - teeth/central hazard: color continues to vary on respawn
; -----------------------------------------------------------------------------
render_game:
        bsr     clear_backbuffer
        bsr     draw_background

        ; side fan / aircon - cyan in the supplied gameplay reference
        move.b  #COL_CYAN,cur_color
        moveq   #0,d0
        move.b  fan_frame,d0
        lsr.b   #2,d0
        and.w   #3,d0
        lea     fan_ptrs,a2
        lsl.w   #2,d0
        move.l  (a2,d0.w),a0
        move.w  fan_y,d1
        add.w   #VIEW_Y,d1
        tst.b   fan_side
        bne   .fan_right
        move.w  #VIEW_X,d0
        bra   .fan_draw
.fan_right:
        move.w  #VIEW_X+224,d0
.fan_draw:
        move.w  #4,d2
        move.w  #22,d3
        ; The fan sits partly on a colored wall. draw_bitmap_color is OR based,
        ; so clear plane 1 (the wall's red component) under the exact fan mask
        ; before drawing cyan, otherwise red/magenta + cyan becomes white.
        move.l  backbuf1,a1
        bsr     clear_bitmap_mask_aligned
        bsr     draw_bitmap_color

        ; Yellow wall window/object. It is world-attached scenery and scrolls
        ; upward; it must not stay fixed on screen. The two original extracted
        ; frames alternate slowly via bit 4 of sideobj_frame.
        move.b  #COL_YELLOW,cur_color
        lea     sideobj0_bitmap,a0
        btst    #4,sideobj_frame
        beq   .side_img
        lea     sideobj1_bitmap,a0
.side_img:
        move.w  sideobj_y,d1
        add.w   #VIEW_Y,d1
        tst.b   sideobj_side
        bne   .side_right
        move.w  #VIEW_X,d0
        bra   .side_draw
.side_right:
        move.w  #VIEW_X+232,d0
.side_draw:
        move.w  #3,d2
        move.w  #22,d3
        ; Yellow is planes 1+2. Clear plane 0 under the exact mask first so a
        ; right-wall magenta pixel (planes 0+1) cannot turn the object white.
        move.l  backbuf0,a1
        bsr     clear_bitmap_mask_aligned
        bsr     draw_bitmap_color

        ; teeth - two exact original frames from $BE80/$C280 - reasoned
        ; color (red for danger), not extracted from a reference
        move.b  teeth_color,cur_color
        lea     teeth0_bitmap,a0
        btst    #2,teeth_frame
        beq   .teeth_img
        lea     teeth1_bitmap,a0
.teeth_img:
        move.w  teeth_x,d0
        add.w   #VIEW_X,d0
        move.w  teeth_y,d1
        add.w   #VIEW_Y,d1
        move.w  #4,d2
        move.w  #20,d3
        bsr     draw_bitmap_color

        ; eyeball - original three frames, 24x31 - magenta matches the
        ; reference screenshot exactly
        move.b  eye_color,cur_color
        moveq   #0,d0
        move.b  eye_frame,d0
        lsr.b   #2,d0
        cmp.w   #2,d0
        ble   .eye_idx_ok
        moveq   #1,d0
.eye_idx_ok:
        lea     eye_ptrs,a2
        lsl.w   #2,d0
        move.l  (a2,d0.w),a0
        move.w  eye_x,d0
        add.w   #VIEW_X,d0
        move.w  eye_y,d1
        add.w   #VIEW_Y,d1
        move.w  #3,d2
        move.w  #31,d3
        bsr     draw_bitmap_color

        ; Player entry uses the horizontal jump frame only until X=128.  The
        ; reference video then switches immediately to the falling pose; that
        ; same transition is also when the shaft begins to scroll.
        cmp.b   #STATE_DEAD,game_state
        beq   .no_player
        cmp.b   #STATE_GAMEOVER,game_state
        beq   .no_player
        move.b  #COL_WHITE,cur_color
        cmp.b   #STATE_ENTER,game_state
        bne   .fall_player
        cmp.b   #3,v7_entry_phase
        bhs   .fall_player
        lea     player_jump_bitmap,a0
        move.w  #4,d2
        move.w  #28,d3
        bra   .player_img
.fall_player:
        lea     player_fall0_bitmap,a0
        btst    #2,player_anim
        beq   .fall_img_ok
        lea     player_fall1_bitmap,a0
.fall_img_ok:
        move.w  #3,d2
        move.w  #28,d3
.player_img:
        move.w  player_x,d0
        add.w   #VIEW_X,d0
        move.w  player_y,d1
        add.w   #VIEW_Y,d1
        bsr     draw_bitmap_color
        cmp.b   #STATE_ENTER,game_state
        bne   .no_speed_lines
        ; Speed lines belong only to the horizontal window-exit phase.  Once
        ; phase 3 selects the falling pose they disappear, as in the original.
        cmp.b   #3,v7_entry_phase
        bhs   .no_speed_lines
        bsr     draw_entry_speedlines
.no_speed_lines:
.no_player:

        bsr     draw_hud
        rts

render_gameover:
        bsr     render_game
        move.b  #COL_RED,cur_color
        lea     game_over_bitmap,a0
        move.w  #134,d0
        move.w  #116,d1
        move.w  #7,d2
        move.w  #7,d3
        bsr     draw_bitmap_color
        rts

; Simple shaft/background. The exact A1xx decorative state machine remains
; isolated from gameplay; core collision/motion/assets above are taken
; directly from the TAP. Left/right edges colored red/magenta to match the
; real brick-wall colors seen in the reference screenshot, even though the
; actual brick texture bitmap isn't extracted yet (README-flagged item).
draw_background:
        ; v5.2 performance path. The former version rendered brick courses,
        ; diagonal clotheslines and garments one pixel at a time through
        ; set_pixel_color (including a MULU and large MOVEM save for each pixel).
        ; On a 7.09 MHz 68000 that collapsed to only a few frames/second.
        ; This version uses one compact wall bitmap and only byte-aligned fast
        ; rectangles for moving details. Gameplay/collision coordinates are unchanged.

        move.b  #COL_RED,cur_color
        lea     wall_brick_bitmap,a0
        move.w  #VIEW_X,d0
        move.w  #VIEW_Y,d1
        move.w  #3,d2
        move.w  #WORLD_H,d3
        bsr     draw_bitmap_color

        move.b  #COL_MAGENTA,cur_color
        lea     wall_brick_bitmap,a0
        move.w  #VIEW_X+232,d0
        move.w  #VIEW_Y,d1
        move.w  #3,d2
        move.w  #WORLD_H,d3
        bsr     draw_bitmap_color

        ; Yellow ledges travel upward through both walls. All geometry is
        ; byte-aligned, so fill_rect_fast never enters the pixel renderer.
        move.w  world_scroll,d6
        and.w   #$003f,d6
        move.w  #VIEW_Y+44,d5
        sub.w   d6,d5
        moveq   #3,d7
.ledge_loop:
        cmp.w   #VIEW_Y-4,d5
        blt   .ledge_next
        cmp.w   #VIEW_Y+WORLD_H,d5
        bge   .ledge_next
        move.b  #COL_YELLOW,cur_color
        move.w  #VIEW_X,d0
        move.w  d5,d1
        move.w  #32,d2
        move.w  #4,d3
        bsr     fill_rect_fast
        move.w  #VIEW_X+224,d0
        move.w  d5,d1
        move.w  #32,d2
        move.w  #4,d3
        ; The right wall is magenta (planes 0+1), while yellow is planes 1+2.
        ; Remove plane 0 first or an OR-only yellow fill becomes white.
        bsr     clear_rect_plane0_fast
        bsr     fill_rect_fast
.ledge_next:
        add.w   #64,d5
        dbra    d7,.ledge_loop

        ; One recurring sagging clothesline. The reference video usually shows
        ; at most one across the shaft. The old diagonal pixel loops were the
        ; other major frame-rate killer; use five one-pixel stepped segments
        ; plus byte-aligned garment silhouettes instead.
        move.w  world_scroll,d6
        and.w   #$00ff,d6
        move.w  #VIEW_Y+190,d5
        sub.w   d6,d5
        cmp.w   #VIEW_Y-24,d5
        bge   .cl_y_ok
        add.w   #256,d5
.cl_y_ok:
        cmp.w   #VIEW_Y+WORLD_H,d5
        bge     .bg_done

        move.b  #COL_CYAN,cur_color
        move.w  #VIEW_X+24,d0
        move.w  d5,d1
        move.w  #40,d2
        move.w  #1,d3
        bsr     fill_rect_fast
        move.w  #VIEW_X+64,d0
        move.w  d5,d1
        addq.w  #2,d1
        move.w  #40,d2
        move.w  #1,d3
        bsr     fill_rect_fast
        move.w  #VIEW_X+104,d0
        move.w  d5,d1
        addq.w  #4,d1
        move.w  #40,d2
        move.w  #1,d3
        bsr     fill_rect_fast
        move.w  #VIEW_X+144,d0
        move.w  d5,d1
        addq.w  #2,d1
        move.w  #40,d2
        move.w  #1,d3
        bsr     fill_rect_fast
        move.w  #VIEW_X+184,d0
        move.w  d5,d1
        move.w  #48,d2
        move.w  #1,d3
        bsr     fill_rect_fast

        move.b  #COL_MAGENTA,cur_color
        move.w  #VIEW_X+40,d0
        move.w  d5,d1
        addq.w  #4,d1
        move.w  #24,d2
        move.w  #18,d3
        bsr     fill_rect_fast
        move.w  #VIEW_X+80,d0
        move.w  d5,d1
        addq.w  #7,d1
        move.w  #8,d2
        move.w  #12,d3
        bsr     fill_rect_fast

        move.b  #COL_WHITE,cur_color
        move.w  #VIEW_X+120,d0
        move.w  d5,d1
        addq.w  #7,d1
        move.w  #8,d2
        move.w  #9,d3
        bsr     fill_rect_fast

        move.b  #COL_GREEN,cur_color
        move.w  #VIEW_X+160,d0
        move.w  d5,d1
        addq.w  #4,d1
        move.w  #16,d2
        move.w  #16,d3
        bsr     fill_rect_fast
.bg_done:
        rts

; Reference-video clothesline approximation: two sagging lines recur with the
; scroll, with small multi-color garments hanging from fixed positions.
draw_clotheslines:
        movem.l d0-d7,-(sp)
        move.w  world_scroll,d6
        and.w   #$007f,d6
        move.w  #VIEW_Y+72,d7
        sub.w   d6,d7
        moveq   #2,d5
.cl_loop:
        cmp.w   #VIEW_Y-16,d7
        blt     .cl_next
        cmp.w   #VIEW_Y+WORLD_H+16,d7
        bgt     .cl_next
        move.b  #COL_CYAN,cur_color
        move.w  #VIEW_X+24,d0
        move.w  d7,d1
        move.w  #82,d2
        move.w  #8,d3
        bsr     diag_down
        move.w  #VIEW_X+106,d0
        move.w  d7,d1
        addq.w  #8,d1
        move.w  #84,d2
        move.w  #8,d3
        bsr     diag_up
        ; garments
        move.b  #COL_YELLOW,cur_color
        move.w  #VIEW_X+58,d0
        move.w  d7,d1
        addq.w  #4,d1
        move.w  #8,d2
        move.w  #12,d3
        bsr     fill_rect
        move.b  #COL_GREEN,cur_color
        move.w  #VIEW_X+118,d0
        move.w  d7,d1
        addq.w  #8,d1
        move.w  #12,d2
        move.w  #9,d3
        bsr     fill_rect
        move.b  #COL_WHITE,cur_color
        move.w  #VIEW_X+164,d0
        move.w  d7,d1
        addq.w  #4,d1
        move.w  #7,d2
        move.w  #14,d3
        bsr     fill_rect
.cl_next:
        add.w   #128,d7
        dbra    d5,.cl_loop
        movem.l (sp)+,d0-d7
        rts

draw_hud:
        ; Original layout: hearts first, then SCORE, then HI SCORE.
        ; Coordinates are mapped from the 256px reference into the centered
        ; 320px Amiga screen.
        moveq   #0,d6
        move.b  lives,d6
        beq   .labels
        subq.w  #1,d6
        move.w  #48,d7
.heart_loop:
        move.b  #COL_RED,cur_color
        lea     heart_bitmap,a0
        move.w  d7,d0
        move.w  #8,d1
        move.w  #1,d2
        move.w  #7,d3
        bsr     draw_bitmap_color
        add.w   #10,d7
        dbra    d6,.heart_loop

.labels:
        move.b  #COL_GREEN,cur_color
        lea     score_label_bitmap,a0
        move.w  #84,d0
        move.w  #8,d1
        move.w  #4,d2
        move.w  #7,d3
        bsr     draw_bitmap_color
        move.w  score,d0
        mulu    #10,d0
        move.w  #128,d1
        move.b  #COL_GREEN,cur_color
        bsr     draw_u16_5digits

        move.b  #COL_MAGENTA,cur_color
        lea     hiscore_label_bitmap,a0
        move.w  #176,d0
        move.w  #8,d1
        move.w  #8,d2
        move.w  #7,d3
        bsr     draw_bitmap_color
        move.w  high_score,d0
        mulu    #10,d0
        move.w  #240,d1
        move.b  #COL_MAGENTA,cur_color
        bsr     draw_u16_5digits
        rts

; d0.w value, d1.w x position. y fixed 8. Uses caller-selected cur_color.
draw_u16_5digits:
        movem.l d2-d7,-(sp)
        move.w  d0,d6
        move.w  d1,d7
        lea     divisors(pc),a2
        moveq   #4,d5
.du:
        move.w  (a2)+,d4
        moveq   #0,d3
.divloop:
        cmp.w   d4,d6
        blt   .dig
        sub.w   d4,d6
        addq.w  #1,d3
        bra   .divloop
.dig:
        move.w  d3,d0
        move.w  d7,d1
        bsr     draw_digit_at
        addq.w  #8,d7
        dbra    d5,.du
        movem.l (sp)+,d2-d7
        rts

divisors: dc.w 10000,1000,100,10,1

; v7.8 menu helper: d0.w value, d1.w x, d2.w y. Uses cur_color.
draw_u16_5digits_xy:
        movem.l d2-d7/a2,-(sp)
        move.w  d0,d6
        move.w  d1,d7
        move.w  d2,d5
        lea     divisors(pc),a2
        moveq   #4,d4
.duxy:
        move.w  (a2)+,d3
        moveq   #0,d2
.divxy:
        cmp.w   d3,d6
        blt.s   .digxy
        sub.w   d3,d6
        addq.w  #1,d2
        bra.s   .divxy
.digxy:
        move.w  d2,d0
        move.w  d7,d1
        move.w  d5,d2
        bsr     draw_digit_at_xy
        addq.w  #8,d7
        dbra    d4,.duxy
        movem.l (sp)+,d2-d7/a2
        rts

draw_digit_at_xy:
        movem.l d1-d4/a0-a1,-(sp)
        mulu    #7,d0
        lea     digits_bitmap,a0
        adda.w  d0,a0
        move.w  d1,d0
        move.w  d2,d1
        move.w  #1,d2
        move.w  #7,d3
        bsr     draw_bitmap_color
        movem.l (sp)+,d1-d4/a0-a1
        rts

; d0 letter-index 0..25 (0=A), d1 x, d2 y. Uses cur_color. Same indexed-strip
; technique as draw_digit_at_xy, against letters_bitmap (gfx/menu/letters.1bpp,
; generated by tools/generate_menu_gfx.py).
draw_letter_at_xy:
        movem.l d1-d4/a0-a1,-(sp)
        mulu    #7,d0
        lea     letters_bitmap,a0
        adda.w  d0,a0
        move.w  d1,d0
        move.w  d2,d1
        move.w  #1,d2
        move.w  #7,d3
        bsr     draw_bitmap_color
        movem.l (sp)+,d1-d4/a0-a1
        rts

; d0 digit 0..9, d1 x, y=8. Uses cur_color.
draw_digit_at:
        movem.l d1-d4/a0-a1,-(sp)
        mulu    #7,d0
        lea     digits_bitmap,a0
        adda.w  d0,a0
        move.w  d1,d0
        move.w  #8,d1
        move.w  #1,d2
        move.w  #7,d3
        bsr     draw_bitmap_color
        movem.l (sp)+,d1-d4/a0-a1
        rts

; Update high score from internal counter.  Sets high_score_new (checked by
; both game-over call sites below) when this death produced a new high score,
; so the player can be taken to the initials-entry screen before GAME OVER.
update_highscore:
        clr.b   high_score_new
        move.w  score,d0
        cmp.w   high_score,d0
        bls   .hs_done
        move.w  d0,high_score
        move.b  #1,high_score_new
.hs_done:
        rts

v78_hiscore_entry_begin:
        clr.b   hiscore_name
        clr.b   hiscore_name+1
        clr.b   hiscore_name+2
        clr.b   hiscore_entry_pos
        bsr     v78_ui_reset_edges
        rts

; Death explosion: expanding four-sided ring centered on player's last position.
draw_death_explosion:
        movem.l d0-d7,-(sp)
        move.w  #22,d6
        sub.w   death_timer,d6
        lsr.w   #1,d6
        addq.w  #3,d6
        move.b  death_timer,d0
        and.b   #3,d0
        lea     explosion_colors,a0
        moveq   #0,d1
        move.b  (a0,d0.w),d1
        move.b  d1,cur_color
        move.w  player_x,d0
        add.w   #VIEW_X+12,d0
        sub.w   d6,d0
        move.w  player_y,d1
        add.w   #VIEW_Y+14,d1
        sub.w   d6,d1
        move.w  d6,d2
        add.w   d6,d2
        bsr     hline
        move.w  player_y,d1
        add.w   #VIEW_Y+14,d1
        add.w   d6,d1
        move.w  d6,d2
        add.w   d6,d2
        bsr     hline
        move.w  player_x,d0
        add.w   #VIEW_X+12,d0
        sub.w   d6,d0
        move.w  player_y,d1
        add.w   #VIEW_Y+14,d1
        sub.w   d6,d1
        move.w  d6,d2
        add.w   d6,d2
        bsr     vline
        move.w  player_x,d0
        add.w   #VIEW_X+12,d0
        add.w   d6,d0
        move.w  player_y,d1
        add.w   #VIEW_Y+14,d1
        sub.w   d6,d1
        move.w  d6,d2
        add.w   d6,d2
        bsr     vline
        movem.l (sp)+,d0-d7
        rts

draw_entry_speedlines:
        movem.l d0-d4,-(sp)
        move.b  #COL_WHITE,cur_color
        move.w  player_x,d0
        add.w   #VIEW_X-26,d0
        move.w  player_y,d1
        add.w   #VIEW_Y+8,d1
        move.w  #20,d2
        bsr     hline
        addq.w  #6,d1
        subq.w  #8,d0
        move.w  #28,d2
        bsr     hline
        movem.l (sp)+,d0-d4
        rts

; d0=x,d1=y,d2=width,d3=height, cur_color
fill_rect:
        movem.l d0-d6,-(sp)
        move.w  d0,d4
        move.w  d1,d5
        move.w  d3,d6
        subq.w  #1,d6
.fr_row:
        move.w  d4,d0
        move.w  d5,d1
        bsr     hline
        addq.w  #1,d5
        dbra    d6,.fr_row
        movem.l (sp)+,d0-d6
        rts

; Fast byte-level fill for large solid rectangles (e.g. walls). Rounds the
; left edge down and the width up to whole bytes - a few px of harmless
; overshoot, not a pixel-accurate primitive. Reads cur_color.
; d0=x, d1=y, d2=width(px), d3=height(px)
fill_rect_fast:
        movem.l d0-d7/a0-a1,-(sp)
        moveq   #0,d6
        move.b  cur_color,d6

        move.w  d0,d5
        lsr.w   #3,d5               ; d5 = start byte X within a row
        move.w  d2,d4
        addq.w  #7,d4
        lsr.w   #3,d4
        subq.w  #1,d4               ; d4 = bytes wide - 1

        btst    #0,d6
        beq   .frf_skip0
        move.l  backbuf0,a0
        bsr     .frf_plane
.frf_skip0:
        btst    #1,d6
        beq   .frf_skip1
        move.l  backbuf1,a0
        bsr     .frf_plane
.frf_skip1:
        btst    #2,d6
        beq   .frf_skip2
        move.l  backbuf2,a0
        bsr     .frf_plane
.frf_skip2:
        movem.l (sp)+,d0-d7/a0-a1
        rts

.frf_plane:
        ; a0=plane base, d1=y, d5=start byte X, d4=bytes wide-1, d3=height
        movem.l d1-d5/a0-a1,-(sp)
        move.w  d1,d7
        mulu    #ROWBYTES,d7
        add.w   d5,d7
        adda.w  d7,a0                ; a0 = plane + row offset + start byte
        move.w  d3,d2
        subq.w  #1,d2
.frf_row:
        move.l  a0,a1
        move.w  d4,d1
.frf_byte:
        move.b  #$ff,(a1)+
        dbra    d1,.frf_byte
        adda.w  #ROWBYTES,a0
        dbra    d2,.frf_row
        movem.l (sp)+,d1-d5/a0-a1
        rts

; Clear the exact 1-bpp source mask in one selected destination plane.
; This is the color-compositing companion to draw_bitmap_color for sprites that
; overlap colored walls. X must be byte-aligned.
; a0=src, a1=dest plane, d0=x,d1=y,d2=source bytes/row,d3=height.
clear_bitmap_mask_aligned:
        movem.l d0-d7/a0-a4,-(sp)
        move.w  d0,d4
        lsr.w   #3,d4
        move.w  d1,d6
        mulu    #ROWBYTES,d6
        add.w   d4,d6
        adda.l  d6,a1
        move.l  a1,a2
        move.w  d3,d7
        subq.w  #1,d7
.cbm_row:
        move.l  a2,a3
        move.w  d2,d6
        subq.w  #1,d6
.cbm_byte:
        moveq   #0,d5
        move.b  (a0)+,d5
        not.b   d5
        and.b   d5,(a3)+
        dbra    d6,.cbm_byte
        lea     ROWBYTES(a2),a2
        dbra    d7,.cbm_row
        movem.l (sp)+,d0-d7/a0-a4
        rts

; Clear plane 0 below a byte-aligned rectangle. Used before yellow details on
; the magenta right wall, because the main fast rectangle renderer is OR-only.
; d0=x,d1=y,d2=width(px),d3=height(px)
clear_rect_plane0_fast:
        movem.l d0-d7/a0-a1,-(sp)
        move.l  backbuf0,a0
        move.w  d0,d5
        lsr.w   #3,d5
        move.w  d2,d4
        addq.w  #7,d4
        lsr.w   #3,d4
        subq.w  #1,d4
        move.w  d1,d7
        mulu    #ROWBYTES,d7
        add.w   d5,d7
        adda.w  d7,a0
        move.w  d3,d2
        subq.w  #1,d2
.crp_row:
        move.l  a0,a1
        move.w  d4,d1
.crp_byte:
        clr.b   (a1)+
        dbra    d1,.crp_byte
        lea     ROWBYTES(a0),a0
        dbra    d2,.crp_row
        movem.l (sp)+,d0-d7/a0-a1
        rts

; Cheap sag-line helpers. d0=x,d1=y,d2=length,d3=total vertical delta.
diag_down:
        movem.l d0-d7,-(sp)
        move.w  d2,d6
        move.w  d3,d7
        moveq   #0,d5
.dd_loop:
        bsr     set_pixel_color
        addq.w  #1,d0
        add.w   d7,d5
        cmp.w   d6,d5
        blt   .dd_no_y
        sub.w   d6,d5
        addq.w  #1,d1
.dd_no_y:
        subq.w  #1,d2
        bne   .dd_loop
        movem.l (sp)+,d0-d7
        rts

diag_up:
        movem.l d0-d7,-(sp)
        move.w  d2,d6
        move.w  d3,d7
        moveq   #0,d5
.du_loop2:
        bsr     set_pixel_color
        addq.w  #1,d0
        add.w   d7,d5
        cmp.w   d6,d5
        blt   .du_no_y
        sub.w   d6,d5
        subq.w  #1,d1
.du_no_y:
        subq.w  #1,d2
        bne   .du_loop2
        movem.l (sp)+,d0-d7
        rts

; -----------------------------------------------------------------------------
; Color wrapper: draws the same shape into 1-3 bitplanes depending on which
; bits of cur_color (0-7) are set, so the same proven-correct single-plane
; blit primitive (draw_bitmap_or, unchanged below) can produce any of the
; 8 palette colors without touching its pixel-level logic.
; a0=src, d0=x,d1=y,d2=source bytes/row,d3=height. Reads cur_color.
; -----------------------------------------------------------------------------
draw_bitmap_color:
        movem.l d0-d7/a0-a4,-(sp)
        move.l  a0,a3                  ; save source pointer for reuse
        moveq   #0,d6
        move.b  cur_color,d6

        btst    #0,d6
        beq   .skip0
        move.l  a3,a0
        move.l  backbuf0,a1
        bsr     draw_bitmap_or
.skip0:
        btst    #1,d6
        beq   .skip1
        move.l  a3,a0
        move.l  backbuf1,a1
        bsr     draw_bitmap_or
.skip1:
        btst    #2,d6
        beq   .skip2
        move.l  a3,a0
        move.l  backbuf2,a1
        bsr     draw_bitmap_or
.skip2:
        movem.l (sp)+,d0-d7/a0-a4
        rts

; -----------------------------------------------------------------------------
; Bitmap primitive: OR packed MSB-first 1-bpp source into 320x256 destination.
; a0=src, a1=dest bitplane, d0=x, d1=y, d2=source bytes/row, d3=height
; Supports arbitrary pixel x by spreading each source byte across two dest bytes.
; UNCHANGED from the monochrome version - draw_bitmap_color calls this once
; per bitplane instead of the old single call directly into "backbuf".
; -----------------------------------------------------------------------------
draw_bitmap_or:
        movem.l d0-d7/a2-a4,-(sp)
        move.w  d0,d4
        and.w   #7,d4              ; bit shift
        move.w  d0,d5
        lsr.w   #3,d5              ; byte X

        move.w  d1,d6
        mulu    #ROWBYTES,d6
        adda.l  d6,a1
        adda.w  d5,a1
        move.l  a1,a2

        move.w  d3,d7
        subq.w  #1,d7
.row:
        move.l  a2,a3
        move.w  d2,d6
        subq.w  #1,d6
        tst.w   d4
        bne   .shifted
.plain:
        moveq   #0,d5
        move.b  (a0)+,d5
        or.b    d5,(a3)+
        dbra    d6,.plain
        bra   .rowdone
.shifted:
        moveq   #0,d5
        move.b  (a0)+,d5
        move.w  d5,d3
        lsr.w   d4,d3
        or.b    d3,(a3)
        moveq   #8,d3
        sub.w   d4,d3
        lsl.w   d3,d5
        or.b    d5,1(a3)
        addq.l  #1,a3
        dbra    d6,.shifted
.rowdone:
        adda.w  #ROWBYTES,a2
        dbra    d7,.row
        movem.l (sp)+,d0-d7/a2-a4
        rts

; Clears all 3 back-buffer bitplanes.
clear_backbuffer:
        movem.l d0-d1/a0,-(sp)
        moveq   #0,d0

        move.l  backbuf0,a0
        move.w  #159,d1
.cb0:
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        dbra    d1,.cb0

        move.l  backbuf1,a0
        move.w  #159,d1
.cb1:
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        dbra    d1,.cb1

        move.l  backbuf2,a0
        move.w  #159,d1
.cb2:
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        dbra    d1,.cb2

        movem.l (sp)+,d0-d1/a0
        rts

clear_frontbuffer:
        movem.l d0-d1/a0,-(sp)
        move.l  frontbuf0,a0
        moveq   #0,d0
        move.w  #(PLANESIZE/4)-1,d1
.cf0:
        move.l  d0,(a0)+
        dbra    d1,.cf0
        move.l  frontbuf1,a0
        move.w  #(PLANESIZE/4)-1,d1
.cf1:
        move.l  d0,(a0)+
        dbra    d1,.cf1
        move.l  frontbuf2,a0
        move.w  #(PLANESIZE/4)-1,d1
.cf2:
        move.l  d0,(a0)+
        dbra    d1,.cf2
        movem.l (sp)+,d0-d1/a0
        rts

; hline d0=x d1=y d2=len pixels. Reads cur_color.
hline:
        movem.l d0-d5,-(sp)
.hl:
        bsr     set_pixel_color
        addq.w  #1,d0
        subq.w  #1,d2
        bne   .hl
        movem.l (sp)+,d0-d5
        rts

; vline d0=x d1=y d2=len pixels. Reads cur_color.
vline:
        movem.l d0-d5,-(sp)
.vl:
        bsr     set_pixel_color
        addq.w  #1,d1
        subq.w  #1,d2
        bne   .vl
        movem.l (sp)+,d0-d5
        rts

; Color wrapper around set_pixel, same technique as draw_bitmap_color.
; d0=x,d1=y. Reads cur_color.
set_pixel_color:
        movem.l d0-d7/a0,-(sp)
        moveq   #0,d6
        move.b  cur_color,d6
        btst    #0,d6
        beq   .sp0
        move.l  backbuf0,a0
        bsr     set_pixel
.sp0:
        btst    #1,d6
        beq   .sp1
        move.l  backbuf1,a0
        bsr     set_pixel
.sp1:
        btst    #2,d6
        beq   .sp2
        move.l  backbuf2,a0
        bsr     set_pixel
.sp2:
        movem.l (sp)+,d0-d7/a0
        rts

; a0=buffer d0=x d1=y. UNCHANGED from the monochrome version.
set_pixel:
        move.w  d1,d3
        mulu    #ROWBYTES,d3
        move.w  d0,d4
        lsr.w   #3,d4
        add.w   d4,d3
        moveq   #7,d4
        move.w  d0,d5
        and.w   #7,d5
        sub.w   d5,d4
        moveq   #1,d5
        lsl.b   d4,d5
        or.b    d5,(a0,d3.w)
        rts

; Patch Copper with the initial front buffer before DMA is enabled.
; copperlistA is always the one boot activates first (copper_active is
; cleared immediately before this is called), so this primes list A.
prime_copper_front:
        move.l  frontbuf0,d0
        move.l  d0,d1
        swap    d1
        move.w  d1,cop_a_bpl1pth+2
        move.w  d0,cop_a_bpl1ptl+2
        move.l  frontbuf1,d0
        move.l  d0,d1
        swap    d1
        move.w  d1,cop_a_bpl2pth+2
        move.w  d0,cop_a_bpl2ptl+2
        move.l  frontbuf2,d0
        move.l  d0,d1
        swap    d1
        move.w  d1,cop_a_bpl3pth+2
        move.w  d0,cop_a_bpl3ptl+2
        rts

; Presents the frame just drawn into the back buffer.
;
; v7.8b rewrite - root cause of the torn / "snow" frames seen on hardware and
; in the emulator: the old code waited for WaitTOF and then restarted the
; Copper by hand (COP1LCH + COPJMP1 strobe).  WaitTOF only says a vertical
; blank has happened; our task can be scheduled much later than that
; (input.device, Intuition, trackdisk and timer work all run first).  When the
; strobe landed after display had started, the Copper re-ran the list from
; the top in the middle of the picture: the bitplane pointers were reset
; mid-frame (picture restarts lower down / shifted right, planes misaligned
; = coloured fringes) or, near the bottom of the frame, the rest of the field
; fetched garbage.  Disable()/Enable() cannot help because the late part is the
; task wake-up, not an interrupt inside the sequence.
;
; Now the hardware does the switch: the new pointers go into the list the
; Copper is NOT running, COP1LCL is pointed at it, and the Copper reloads it by
; itself at the next vertical blank - always at the top of a field, whatever
; the CPU is doing.  WaitTOF then waits for exactly that vertical blank, so the
; old front buffer is no longer on screen when it becomes the next back buffer.
; If we are late (render took longer than a field) the switch simply happens
; one field later; it can never happen mid-picture.
present_frame:
        tst.b   copper_active
        bne.s   .use_a
        ; copperlistA is live; prepare B and queue it.
        move.l  backbuf0,d0
        move.w  d0,cop_b_bpl1ptl+2
        swap    d0
        move.w  d0,cop_b_bpl1pth+2
        move.l  backbuf1,d0
        move.w  d0,cop_b_bpl2ptl+2
        swap    d0
        move.w  d0,cop_b_bpl2pth+2
        move.l  backbuf2,d0
        move.w  d0,cop_b_bpl3ptl+2
        swap    d0
        move.w  d0,cop_b_bpl3pth+2
        move.w  #copperlistB&$ffff,COP1LCL
        move.b  #1,copper_active
        bra.s   .queued
.use_a:
        ; copperlistB is live; prepare A and queue it.
        move.l  backbuf0,d0
        move.w  d0,cop_a_bpl1ptl+2
        swap    d0
        move.w  d0,cop_a_bpl1pth+2
        move.l  backbuf1,d0
        move.w  d0,cop_a_bpl2ptl+2
        swap    d0
        move.w  d0,cop_a_bpl2pth+2
        move.l  backbuf2,d0
        move.w  d0,cop_a_bpl3ptl+2
        swap    d0
        move.w  d0,cop_a_bpl3pth+2
        move.w  #copperlistA&$ffff,COP1LCL
        clr.b   copper_active
.queued:
        move.l  gfxbase,a6
        jsr     LVOWaitTOF(a6)          ; Copper has now loaded the new list

        move.l  frontbuf0,d0
        move.l  backbuf0,frontbuf0
        move.l  d0,backbuf0

        move.l  frontbuf1,d0
        move.l  backbuf1,frontbuf1
        move.l  d0,backbuf1

        move.l  frontbuf2,d0
        move.l  backbuf2,frontbuf2
        move.l  d0,backbuf2

        ; Intuition may re-enable sprite DMA when the mouse moves; the Copper
        ; lists also point every sprite at an empty sprite, so nothing can show.
        move.w  #$0020,DMACON       ; clear SPREN
        bra     audio_service

; -----------------------------------------------------------------------------
; v7.8b 50 Hz audio/timing service.
; Runs every per-field tick once for each PAL field that has elapsed since the
; previous service (counted by the VERTB server), so speech hand-offs, the
; start-of-game choreography and the ZX sequencer keep real time even when a
; frame takes two or three fields to draw.  Called after every WaitTOF.
; Preserves all registers.
; -----------------------------------------------------------------------------
audio_service:
        movem.l d0-d7/a0-a5,-(sp)
        move.l  vbl_counter,d0
        move.l  audio_vbl_seen,d1
        move.l  d0,audio_vbl_seen
        sub.l   d1,d0
        beq.s   .done                   ; same field as last service
        cmp.l   #8,d0
        bls.s   .count_ok
        moveq   #8,d0                   ; long stall (disk/OS) - don't burst
.count_ok:
        move.w  d0,audio_service_left
.loop:
        bsr     audio_field_tick
        subq.w  #1,audio_service_left
        bne.s   .loop
.done:
        movem.l (sp)+,d0-d7/a0-a5
        rts

audio_field_tick:
        tst.b   zx_audio_enabled
        beq.s   .no_zx
        bsr     zx_audio_tick
.no_zx:
        bsr     sample_audio_tick
        bsr     sample_opening_tick
        tst.b   v7_intro_active
        beq.s   .no_intro
        addq.w  #1,v7_intro_clock
.no_intro:
        ; ZX beeper music belongs to gameplay only.  It is armed when the
        ; player starts falling (v7_enter_tick) and starts once Colin's opening
        ; line has finished, so it never plays on the title, during the
        ; opening dialogue, or on GAME OVER / menus.
        tst.b   zx_start_pending
        beq.s   .done
        tst.b   sample_opening_stage
        bne.s   .done
        cmp.b   #STATE_PLAY,game_state
        bne.s   .done
        clr.b   zx_start_pending
        bsr     zx_audio_game_start
.done:
        rts

; VERTB interrupt server: A1 = is_Data = &vbl_counter.  Returns Z set so the
; rest of the server chain (graphics.library etc.) still runs.
vbl_server:
        addq.l  #1,(a1)
        moveq   #0,d0
        rts

fire_pressed:
        moveq   #0,d0
        btst    #7,CIAAPRA          ; joystick port 2 fire, active low
        bne   .fpdone
        moveq   #1,d0
.fpdone:
        rts

random16:
        move.w  rng_state,d0
        move.w  d0,d1
        lsl.w   #5,d1
        eor.w   d1,d0
        move.w  d0,d1
        lsr.w   #7,d1
        eor.w   d1,d0
        move.w  d0,d1
        lsl.w   #3,d1
        eor.w   d1,d0
        add.w   VHPOSR,d0
        move.w  d0,rng_state
        rts

; -----------------------------------------------------------------------------
; EXIT -> YES used to try to hand a precisely-restored display/library state
; back to whatever AmigaDOS process launched us (LoadView the old view,
; WaitTOF x2, CloseLibrary, then rts/halt) - that handoff is exactly what
; was freezing. A soft reset sidesteps all of it: it never returns to our
; own code, so there is no state to restore or library call to get right.
; For the Shell ADF this is also simpler than it sounds - AmigaDOS reboots
; from the floppy and its Startup-Sequence launches NOHZDYVE again on its
; own, so EXIT -> YES just lands back on the title menu either way.
shutdown:
        bsr     soft_reset
        ; not reached

soft_reset:
        move.l  4.w,a6
        lea     soft_reset_super(pc),a5
        jsr     LVOSupervisor(a6)
        rts                         ; not reached - Supervisor() never returns here

soft_reset_super:
        ; Entered in supervisor mode via Supervisor(). Mirrors a real
        ; Ctrl-Amiga-Amiga / power-cycle: mask everything, then jump
        ; straight into Kickstart's own cold-start code.
        ;
        ; Never touches the CIA-A OVL bit: our own code is loaded and
        ; executing at $40000, which sits inside the low-memory window OVL
        ; remaps to ROM, so setting it would corrupt the CPU's own ongoing
        ; instruction fetch. Kickstart ROM is also always directly readable
        ; at its normal high address, $F80000 - mirrored there even on a
        ; 256KB-ROM KS1.3 machine where the real base is $FC0000, and the
        ; true native base on a 512KB-ROM KS2.0+ machine like the A500+.
        ; Reading the cold-start entry point from there needs no remapping,
        ; so our own code at $40000 is never affected by it. Confirmed
        ; working on real A500/A500+ hardware under both Kickstarts.
        ;
        ; Tried adding a RESET instruction here (to pulse /RESET to CIAs
        ; and the expansion bus, for CDTV's extra onboard hardware) but it
        ; made CDTV worse under emulation - solid black, not even a jump -
        ; so it's left out again. CDTV's CD-ROM subsystem apparently needs
        ; more than this soft path can give it; a real EXIT->YES reboot on
        ; CDTV may need to stay a known limitation rather than chase it
        ; further at the cost of regressing the confirmed-working A500/A500+
        ; path.
        ;
        ; Confirmed on real A500/A500+ hardware: EXIT -> YES now reboots
        ; cleanly all the way back to the title menu. Diagnostic checkpoint
        ; colors removed now that it's reliable.
        move.w  #$7fff,DMACON       ; stop all DMA
        move.w  #$7fff,INTENA       ; disable all interrupts
        move.w  #$7fff,INTREQ       ; clear all pending interrupts
        movea.l $f80004,a0          ; Kickstart's cold-start entry point, read directly
        jmp     (a0)                ; re-enter Kickstart's own cold-start code

nogfx:
        tst.b   shell_mode
        bne.w   shell_return
haltloop2:
        bra     haltloop2

shell_return:
        rts


; =============================================================================
; V7 SOURCE-FIRST GAME ENGINE
; =============================================================================
; No binary patch addresses are used anywhere in this section. The main loop
; branches to these labels directly.  Behavior is based on the attached
; nohzdyve-master source, with the original Spectrum/video kept as authority
; where the recreation differs.
;
; PAL timing:
;   title:    50 Hz presentation
;   gameplay: 25 Hz (two PAL VBlanks / 40 ms per logic tick)
;

v7_title_tick:
        ; Main title is now a four-item menu.  Attract dialogue keeps running
        ; here, but is stopped while OPTIONS / HI SCORE / EXIT are displayed.
        bsr     v7_render_title
        bsr     present_frame
        bsr     sample_attract_tick
        bsr     v78_read_ui
        move.b  d0,d1
        btst    #0,d1
        beq.w   .check_down
        tst.b   title_menu_item
        bne.w   .menu_up
        move.b  #MENU_EXIT,title_menu_item
        bra.w   .input_done
.menu_up:
        subq.b  #1,title_menu_item
        bra.w   .input_done
.check_down:
        btst    #1,d1
        beq.w   .check_select
        cmp.b   #MENU_EXIT,title_menu_item
        blo.w   .menu_down
        clr.b   title_menu_item
        bra.w   .input_done
.menu_down:
        addq.b  #1,title_menu_item
        bra.w   .input_done
.check_select:
        btst    #2,d1
        beq.w   .input_done
        moveq   #0,d0
        move.b  title_menu_item,d0
        beq.w   .start_game
        cmp.b   #MENU_OPTIONS,d0
        beq.w   .open_options
        cmp.b   #MENU_HISCORE,d0
        beq.w   .open_hiscore
        cmp.b   #MENU_CREDITS,d0
        beq.w   .open_credits
        move.b  #1,exit_menu_item      ; default to NO
        bsr     v78_ui_reset_edges
        move.b  #STATE_EXIT,game_state
        bra.w   main_loop
.open_credits:
        bsr     v78_ui_reset_edges
        move.b  #STATE_CREDITS,game_state
        bra.w   main_loop
.open_options:
        clr.b   options_menu_item
        bsr     v78_ui_reset_edges
        move.b  #STATE_OPTIONS,game_state
        bra.w   main_loop
.open_hiscore:
        bsr     v78_ui_reset_edges
        move.b  #STATE_HISCORE,game_state
        bra.w   main_loop
.start_game:
        ; Every other menu action (.open_credits/.open_options/.open_hiscore/
        ; EXIT) resets the UI edge-tracking state before leaving the title
        ; menu; this one didn't, leaving ui_prev_buttons/ui_prev_dirs holding
        ; whatever was true at the moment of selection. Match the others so
        ; gameplay/intro input starts from a clean edge state too.
        bsr     v78_ui_reset_edges
        bsr     v7_game_new
        bra.w   main_loop
.input_done:
        bra.w   main_loop

v78_options_tick:
        bsr     v78_render_options
        bsr     present_frame
        bsr     sample_attract_tick
        bsr     v78_read_ui
        move.b  d0,d1
        btst    #3,d1
        bne.w   v78_return_to_title
        btst    #0,d1
        beq.w   .check_down
        tst.b   options_menu_item
        bne.w   .up
        move.b  #OPT_BACK,options_menu_item
        bra.w   main_loop
.up:
        subq.b  #1,options_menu_item
        bra.w   main_loop
.check_down:
        btst    #1,d1
        beq.w   .check_change
        cmp.b   #OPT_BACK,options_menu_item
        blo.w   .down
        clr.b   options_menu_item
        bra.w   main_loop
.down:
        addq.b  #1,options_menu_item
        bra.w   main_loop
.check_change:
        btst    #2,d1
        beq.w   main_loop
        moveq   #0,d0
        move.b  options_menu_item,d0
        beq.w   .control
        cmp.b   #OPT_DIGI,d0
        beq.w   .digi
        cmp.b   #OPT_SOUNDFX,d0
        beq.w   .soundfx
        bra.w   v78_return_to_title
.control:
        ; MOUSE is skipped: moving the mouse corrupts the display (Intuition
        ; re-asserting its own background mouse-pointer sprite handling), so
        ; it is no longer a selectable CONTROL option. AUTO/JOYSTICK/CURSOR
        ; remain fully functional.
        addq.b  #1,control_mode
        cmp.b   #4,control_mode
        blo.w   .control_skip_mouse
        clr.b   control_mode
.control_skip_mouse:
        cmp.b   #CONTROL_MOUSE,control_mode
        bne.s   .control_done
        move.b  #CONTROL_CURSOR,control_mode
.control_done:
        clr.b   active_control
        bsr     v78_mouse_sync
        bra.w   main_loop
.digi:
        eori.b  #1,digi_sounds_enabled
        tst.b   digi_sounds_enabled
        bne.w   main_loop
        bsr     sample_audio_stop_all
        bra.w   main_loop
.soundfx:
        eori.b  #1,soundfx_enabled
        tst.b   soundfx_enabled
        bne.w   main_loop
        bsr     zx_audio_disable
        bra.w   main_loop

v78_credits_tick:
        bsr     v78_render_credits
        bsr     present_frame
        bsr     sample_attract_tick
        bsr     v78_read_ui
        and.b   #(UI_SELECT+UI_BACK),d0
        beq.w   main_loop
        bra.w   v78_return_to_title

; Classic 3-letter arcade-style initials entry, shown once, right after a
; death that just beat the session high score (see update_highscore /
; v78_hiscore_entry_begin).  UP/DOWN cycle the currently-edited letter
; A..Z, SELECT confirms it and moves to the next one; after the third
; letter is confirmed this hands off to the normal GAME OVER screen.
; Session-only, same as the high score itself: nothing here is written
; to disk.
v78_hiscore_entry_tick:
        bsr     v78_render_hiscore_entry
        bsr     present_frame
        bsr     v78_read_ui
        move.b  d0,d1
        btst    #0,d1                  ; UP: next letter
        beq.w   .check_down
        moveq   #0,d0
        move.b  hiscore_entry_pos,d0
        lea     hiscore_name,a0
        adda.w  d0,a0
        addq.b  #1,(a0)
        cmp.b   #26,(a0)
        blo.w   main_loop
        clr.b   (a0)
        bra.w   main_loop
.check_down:
        btst    #1,d1                  ; DOWN: previous letter
        beq.w   .check_select
        moveq   #0,d0
        move.b  hiscore_entry_pos,d0
        lea     hiscore_name,a0
        adda.w  d0,a0
        tst.b   (a0)
        bne.s   .dec
        move.b  #25,(a0)
        bra.w   main_loop
.dec:
        subq.b  #1,(a0)
        bra.w   main_loop
.check_select:
        btst    #2,d1                  ; SELECT: confirm letter / finish
        beq.w   main_loop
        cmp.b   #2,hiscore_entry_pos
        bhs.s   .finish
        addq.b  #1,hiscore_entry_pos
        bra.w   main_loop
.finish:
        bsr     v78_ui_reset_edges
        move.b  #STATE_GAMEOVER,game_state
        bra.w   main_loop

v78_hiscore_tick:
        bsr     v78_render_hiscore
        bsr     present_frame
        bsr     sample_attract_tick
        bsr     v78_read_ui
        and.b   #(UI_SELECT+UI_BACK),d0
        beq.w   main_loop
        bra.w   v78_return_to_title

v78_exit_tick:
        bsr     v78_render_exit
        bsr     present_frame
        bsr     sample_attract_tick
        bsr     v78_read_ui
        move.b  d0,d1
        btst    #3,d1
        bne.w   v78_return_to_title
        btst    #0,d1
        bne.w   .toggle
        btst    #1,d1
        beq.w   .select
.toggle:
        eori.b  #1,exit_menu_item
        bra.w   main_loop
.select:
        btst    #2,d1
        beq.w   main_loop
        tst.b   exit_menu_item
        bne.w   v78_return_to_title
        bra.w   shutdown

v78_return_to_title:
        bsr     sample_attract_reset
        bsr     v78_ui_reset_edges
        move.b  #STATE_TITLE,game_state
        bra.w   main_loop

; Short title-to-game transition.  The shaft/fan background is identical on
; both sides of the transition; controls disappear immediately and the logo
; disappears before the entry/HUD layer is enabled.
;
; Every earlier version of this routine gated the switch to STATE_ENTER on
; some combination of "logo scroll finished" and "dialogue finished", which
; is exactly the sequential feel that kept coming back no matter how fast
; each individual piece was made: Stefan, THEN logo, THEN Colin, THEN the
; window opens - each step politely waiting for the last one, rather than
; things actually happening together. The only part of this that genuinely
; cannot overlap is audio-on-audio: Colin's speech (AUD2/AUD3) must not play
; under the ZX intro beeper mix (AUD0/AUD1) or it gets drowned out (confirmed
; on real hardware). Nothing else needs to wait for anything else.
;
; So this routine now only owns the brief logo-scroll flourish, and hands
; off to STATE_ENTER as soon as THAT'S done - full stop, regardless of
; whether Stefan or Colin are still talking. The dialogue state machine
; (sample_opening_tick) keeps running from v7_enter_tick once we leave here
; (see its top), so Stefan's line, the hand-off gap, and Colin's line all
; continue playing out WHILE the character is already exiting the window and
; falling - genuinely concurrent, not sequential. zx_audio_game_start is the
; one thing v7_enter_tick still defers, until sample_opening_stage confirms
; the whole exchange is actually over.
v7_title_exit_tick:
        ; Letting the window-exit begin independently of dialogue (while the
        ; logo was still scrolling, or while Colin was still mid-line) made
        ; the two feel disconnected - Colin's answer landing after the
        ; character had already left the window, instead of being the thing
        ; that resolves the exchange and OPENS it. Back to: the window does
        ; not open until Colin has fully finished answering.
        ;
        ; That still doesn't mean a dead, static wait: the logo keeps
        ; scrolling (fast, -8px/tick) for as long as the dialogue runs,
        ; clamped once it reaches the fully-scrolled-away position so it
        ; never travels further than needed, and the background fan
        ; animation (v7_render_title_scene, called via v7_render_title_exit
        ; below) runs every call regardless of logo position - so the screen
        ; keeps visible motion the whole time even on the rare case the logo
        ; finishes scrolling before dialogue does.
        cmp.w   #-36,v7_title_logo_y
        ble.s   .scroll_done
        tst.b   sample_opening_stage
        beq.s   .scroll_done
        subq.w  #8,v7_title_logo_y
.scroll_done:
        bsr     v7_render_title_exit
        ; present_frame itself services sample_opening_tick (and, once it
        ; completes, zx_audio_game_start) every call - see its own comment -
        ; so there is no separate call needed here.
        bsr     present_frame

        ; The player does not leave the window until Colin has answered.
        tst.b   sample_opening_stage
        bne     main_loop

        move.b  #STATE_ENTER,game_state
        bra     main_loop

v7_game_new:
        clr.w   score
        clr.b   active_control
        bsr     v78_mouse_sync
        move.b  #3,lives
        move.w  #$1234,rng_state

        ; Reset the auxiliary layer first, then immediately begin one of the two
        ; randomized opening exchanges:
        ;   Stefan "I do it"  -> Colin "I like your style"
        ;   Stefan "You do it" -> Colin "Fair enough"
        ; The character waits in the window until the exchange has completed.
        bsr     sample_audio_new_game
        bsr     sample_opening_start

        ; Do NOT reset scenery here: title and game are one continuous scene.
        bsr     v7_round_reset_entities
        bsr     v7_entry_reset
        clr.b   v7_title_exit_phase

        ; v7.8b: one choreographed opening instead of three sequential steps.
        ; From the moment START is selected the menu is gone, the logo scrolls
        ; away, the closed window and HUD are already in the shaft and Stefan
        ; speaks.  The window opens when Colin starts answering and the jump is
        ; timed to land on the end of his line (see v7_intro_wanted_phase).
        ; STATE_TITLE_EXIT (logo first, then window) is no longer used.
        clr.w   v7_intro_clock
        clr.b   v7_intro_voiced
        tst.b   sample_opening_stage
        beq.s   .silent_intro
        move.b  #1,v7_intro_voiced
.silent_intro:
        move.w  #28,v7_title_logo_y
        move.b  #1,v7_intro_active
        move.b  #STATE_ENTER,game_state
        rts

; v7.8b start-of-game choreography.  Returns d0.b = the window phase the intro
; wants now: 0 = window closed, 1 = window open, 2 = jump.
;   voiced:  open when Colin starts, jump INTRO_JUMP_LEAD fields before his
;            line ends so the character leaves the window as he finishes.
;   silent (DIGI SOUNDS off / no sample bank): the same rhythm on the clock.
INTRO_JUMP_LEAD     equ 26          ; 13 jump steps x 2 PAL fields
INTRO_SILENT_OPEN   equ 23          ; ~ Stefan line + hand-off gap
INTRO_SILENT_JUMP   equ 29
INTRO_LOGO_TRAVEL   equ 68          ; y 28 -> -40: logo + TUCKERSOFT fully gone
INTRO_LOGO_FIELDS   equ 36          ; scroll spans Stefan's line into Colin's
v7_intro_wanted_phase:
        tst.b   v7_intro_voiced
        beq.s   .silent
        move.b  sample_opening_stage,d0
        beq.s   .jump                   ; exchange over (or digi switched off)
        cmp.b   #SAMPLE_OPEN_COLIN,d0
        bne.s   .closed
        cmp.w   #INTRO_JUMP_LEAD,sample_opening_delay
        bls.s   .jump
        moveq   #1,d0
        rts
.silent:
        cmp.w   #INTRO_SILENT_JUMP,v7_intro_clock
        bhs.s   .jump
        cmp.w   #INTRO_SILENT_OPEN,v7_intro_clock
        blo.s   .closed
        moveq   #1,d0
        rts
.closed:
        moveq   #0,d0
        rts
.jump:
        moveq   #2,d0
        rts

; Logo position during the opening, derived from the 50 Hz intro clock so it
; scrolls smoothly at the same speed however long a frame takes to draw.
; Leaves v7_title_logo_y set; returns Z=1 when the logo has fully gone.
v7_intro_update_logo:
        moveq   #0,d0
        move.w  v7_intro_clock,d0
        cmp.w   #INTRO_LOGO_FIELDS,d0
        bhs.s   .gone
        mulu    #INTRO_LOGO_TRAVEL,d0
        divu    #INTRO_LOGO_FIELDS,d0
        cmp.w   #INTRO_LOGO_TRAVEL,d0
        blo.s   .on
.gone:
        move.w  #28-INTRO_LOGO_TRAVEL,v7_title_logo_y
        moveq   #0,d0
        rts
.on:
        neg.w   d0
        add.w   #28,d0
        move.w  d0,v7_title_logo_y
        moveq   #1,d0
        rts

; Player/hazard/collectible state, separated from scenery so a new game can
; begin without the title background jumping to a different wall phase.
v7_round_reset_entities:
        move.w  #132,player_x
        move.w  #72,player_y
        clr.b   player_vx               ; slow drift: -1/0/+1
        move.b  #1,v7_player_falling
        move.b  #96,v7_player_maxfall
        clr.b   player_anim

        bsr     v7_respawn_teeth

        move.w  #190,eye_y
        clr.b   eye_frame
        clr.b   v7_eye_dead
        clr.b   v7_eye_exp_frame
        bsr     respawn_eye
        move.w  eye_x,v7_eye_prevx
        rts

; Shared initial shaft scene for title and each life.  world_scroll=$60 puts
; the aircon mounting bay near the lower-right of the screen, matching the
; reference title/start frame.  The vase waits for its next complete mounting
; bay to enter from below; clothes start well below the viewport.
v7_scene_reset:
        move.w  #96,world_scroll
        move.w  #168,fan_y              ; (64-96) mod 200
        move.b  #1,fan_side
        clr.b   fan_frame
        move.w  #208,sideobj_y          ; hidden until a full bay enters below
        move.b  #1,sideobj_side
        clr.b   v7_vase_active
        move.b  #1,v7_vase_waitwrap
        ; The clothesline attaches to the LARGE yellow block-cap which forms
        ; the top/bottom pillar of each 200-row wall section (source rows 1..4),
        ; not to the tiny yellow side tabs at rows 88/176.  Rope row 0 is
        ; centred on cap row 2.  At world_scroll=96 this cap is at y=106.
        move.w  #106,v7_clothes_y
        clr.b   v7_clothes_visible
        move.b  #2,v7_clothes_waitwrap  ; keep the delayed first clothes pass
        clr.b   v7_clothes_layout
        move.w  #28,v7_title_logo_y
        rts

v7_round_reset:
        bsr     v7_round_reset_entities
        bsr     v7_scene_reset
        clr.w   death_timer
        rts

v7_entry_reset:
        move.w  #24,player_x
        ; The Spectrum reference begins the exit much lower in the shaft than
        ; the MSX reconstruction's Y=63.  The earlier Amiga reference-derived
        ; value (118) matches the captured window/player entry height.
        move.w  #118,player_y
        move.w  #118,v7_window_y
        clr.b   player_vx
        clr.b   player_anim
        clr.w   entry_timer             ; phase counter 0..5
        clr.b   v7_entry_phase
        rts

; Source sequence from engine/man.asm:
;   phase 0 window0
;   phase 1 window1
;   phase 2 jump; x=24,32,...,128; speed lines from x>=64
;   phase 3 window0
;   phase 4 window2
;   phase 5 hide speed lines -> gameplay
v7_enter_tick:
        ; STATE_ENTER now begins as soon as the brief logo-scroll finishes,
        ; without waiting for Stefan/Colin's dialogue - so that dialogue is
        ; still in progress here more often than not. It keeps playing out
        ; correctly (Stefan's line, the hand-off gap, Colin's line) because
        ; sample_opening_tick is serviced every present_frame/v7_present_
        ; game_frame VBlank call now (see present_frame's own comment),
        ; regardless of game_state, at the true 50Hz cadence its TICKS
        ; constants assume - not from here, which would only call it once
        ; per 25Hz game frame and stretch the timing.
        ;
        ; v7.8b: the next paragraph is history.  ZX music is now armed in
        ; .finish below and started by audio_field_tick once Colin is done.
        ; zx_audio_game_start used to be triggered from inside present_frame
        ; rather than from here - this routine's
        ; own jump+fall sequence is only a handful of frames and can finish
        ; (handing off to STATE_PLAY) before Colin's line does whenever his
        ; is the longer response, and v7_play_tick never re-checked this, so
        ; zx_audio_game_start could end up never firing for that playthrough
        ; (silence for the whole game, not just the intro). Checking it from
        ; present_frame instead means it keeps getting serviced no matter
        ; which state the game is in by the time dialogue finishes.
        cmp.b   #2,v7_entry_phase
        beq   .jump
        cmp.b   #5,v7_entry_phase
        beq   .finish

        ; v7.8b: during the first exit of a new game, phases 0 (closed) and
        ; 1 (open) are held until the dialogue reaches the right point, and are
        ; presented at the full 50 Hz so the logo scroll stays smooth.
        tst.b   v7_intro_active
        beq.s   .normal_phase
        cmp.b   #2,v7_entry_phase
        bhs.s   .normal_phase
        bsr     v7_intro_wanted_phase
        cmp.b   v7_entry_phase,d0
        bls.s   .intro_hold
        addq.b  #1,v7_entry_phase
        cmp.b   #2,v7_entry_phase
        bne.s   .intro_hold
        move.w  v7_intro_clock,v7_intro_jump_t0
        bra     .jump
.intro_hold:
        move.w  v7_intro_clock,d0       ; title-style fan blade animation
        lsr.w   #3,d0
        and.b   #1,d0
        move.b  d0,fan_frame
        bsr     v7_render_game
        bsr     present_frame
        bra     main_loop

.normal_phase:
        eor.b   #1,fan_frame
        ; Phases 0/1 are still part of the stationary window exit.  For phases
        ; 3/4 advance the shaft BEFORE drawing, so the very first visible
        ; falling-pose frame is also the first visibly scrolled background
        ; frame, matching the supplied original video.
        cmp.b   #3,v7_entry_phase
        blo.s   .render_phase
        bsr     v7_advance_entry_fall_world
.render_phase:
        bsr     v7_render_game
        bsr     v7_present_game_frame
        addq.b  #1,v7_entry_phase
        bra     main_loop

.jump:
        ; Horizontal exit only: player moves from the window to X=128 while
        ; every wall/background object remains at exactly the same Y.
        eor.b   #1,fan_frame
        tst.b   v7_intro_active
        beq.s   .jump_draw
        ; v7.8b opening: the original 8 px per 25 Hz frame, but taken from the
        ; 50 Hz clock so the jump lands on the end of Colin's line even when a
        ; frame takes several fields to draw.
        move.w  v7_intro_clock,d0
        sub.w   v7_intro_jump_t0,d0
        lsr.w   #1,d0
        lsl.w   #3,d0
        add.w   #24,d0
        cmp.w   #128,d0
        bls.s   .jump_x
        move.w  #128,d0
.jump_x:
        move.w  d0,player_x
.jump_draw:
        bsr     v7_render_game
        bsr     v7_present_game_frame
        cmp.w   #128,player_x
        bge   .jump_done
        tst.b   v7_intro_active
        bne     main_loop
        addq.w  #8,player_x
        bra     main_loop
.jump_done:
        move.b  #3,v7_entry_phase
        bra     main_loop

.finish:
        ; At the middle of the shaft the sprite has already changed to the
        ; falling pose and scrolling has begun.  Do not snap Y upward here;
        ; keeping the exit height avoids the artificial diagonal movement of
        ; earlier Amiga builds.  Allow the first fall to reach Y=128 before
        ; the normal bob reverses direction.
        move.w  #128,player_x
        clr.b   player_vx
        move.b  #1,v7_player_falling
        move.b  #128,v7_player_maxfall
        clr.b   player_anim
        move.b  #STATE_PLAY,game_state
        ; v7.8b: the opening is over; ZX music starts with gameplay (and only
        ; after Colin has finished - see audio_field_tick).  On a respawn the
        ; music is already running and simply continues.
        clr.b   v7_intro_active
        tst.b   zx_audio_enabled
        bne.s   .zx_running
        move.b  #1,zx_start_pending
.zx_running:
        ; Falling ambience is a quiet Paula loop. If a voice sample is still
        ; active, sample_audio_start_wind merely marks it wanted and starts it
        ; automatically when the voice finishes.
        bsr     sample_audio_start_wind
        bra     main_loop

; Once the jump has reached X=128 and the falling pose appears, the shaft,
; window and wall-mounted scenery begin their normal 8-pixel upward movement.
; The player itself is no longer pulled upward by the entry code.
v7_advance_entry_fall_world:
        bsr     v7_advance_wall
        bsr     v7_update_world
        sub.w   #8,v7_window_y
        rts

v7_play_tick:
        bsr     v7_update_player
        bsr     v7_update_teeth
        bsr     v7_update_eye
        bsr     v7_update_world
        bsr     v7_collisions

        ; A collision can change STATE_PLAY -> STATE_DEAD.  Once that happens
        ; the impact frame must be presented without advancing/toggling the
        ; world afterwards.  Otherwise a hidden clothesline can become visible
        ; between the last PLAY frame and the first DEAD/GAMEOVER frame.
        cmp.b   #STATE_PLAY,game_state
        bne.s   .impact_frame

        bsr     v7_render_game
        bsr     v7_present_game_frame
        bsr     v7_advance_wall          ; normal live gameplay only
        bra     main_loop

.impact_frame:
        bsr     v7_render_game
        bsr     v7_present_game_frame
        bra     main_loop

; -----------------------------------------------------------------------------
; PLAYER — direct translation of controller/man.asm
; -----------------------------------------------------------------------------
v7_update_player:
        ; Persistent slow horizontal drift occurs before reading this tick's
        ; joystick, matching controller_man_falling -> controller_man_moving.
        moveq   #0,d0
        move.b  player_vx,d0
        ext.w   d0
        add.w   d0,player_x

        ; Vertical bob by +/-1.
        moveq   #0,d0
        move.b  v7_player_falling,d0
        ext.w   d0
        add.w   d0,player_y

        ; At max fall, turn upward. At y==48, restore normal max=96 and fall down.
        moveq   #0,d1
        move.b  v7_player_maxfall,d1
        move.w  player_y,d0
        cmp.w   d1,d0
        bge   .turn_up
        cmp.w   #48,player_y
        bne   .read
        move.b  #96,v7_player_maxfall
        move.b  #1,v7_player_falling
        bra   .read
.turn_up:
        move.b  #-1,v7_player_falling

.read:
        bsr     v78_read_game_control
        tst.b   d0
        beq   .anim
        bmi   .left
.right:
        addq.w  #4,player_x
        move.b  #1,player_vx
        move.b  #128,v7_player_maxfall
        bra   .anim
.left:
        subq.w  #4,player_x
        move.b  #-1,player_vx
        move.b  #128,v7_player_maxfall
.anim:
        addq.b  #1,player_anim
        and.b   #3,player_anim          ; 0,1 = A / 2,3 = B
        rts

; -----------------------------------------------------------------------------
; V7.8 INPUT LAYER
; -----------------------------------------------------------------------------
; Menus always accept every supported controller, irrespective of CONTROL:
;   - joystick / CDTV remote in JOY mode on port 2
;   - mouse / CDTV remote in MOUSE mode on port 1
;   - cursor keys + Return/Space through keyboard.device
;
; CONTROL only selects the gameplay steering backend.  AUTO starts with the
; controller last used in the title menu and otherwise locks to the first
; meaningful horizontal input.  No mouse button is ever a global quit action.

v78_input_init:
        movem.l d0-d3/a0-a2/a6,-(sp)
        move.w  JOY0DAT,mouse_prev_joy
        clr.w   mouse_y_accum
        clr.b   ui_prev_dirs
        clr.b   ui_prev_buttons
        clr.b   ui_mouse_cooldown
        clr.b   active_control
        clr.b   last_ui_control
        clr.b   auto_joy_dir
        clr.b   keyboard_available
        clr.b   kbd_io_pending
        move.b  #$ff,kbd_sigbit

        ; keyboard.device is resident on classic systems.  Build a small static
        ; reply port/IOStdReq so this remains Kickstart 1.3 compatible; V34
        ; KBD_READMATRIX requires io_Length=13 exactly.
        move.l  4.w,a6
        moveq   #-1,d0
        jsr     LVOAllocSignal(a6)
        cmp.l   #-1,d0
        beq.w   .done
        move.b  d0,kbd_sigbit
        move.l  d0,d3

        lea     kbd_port,a0
        move.b  #NT_MSGPORT,8(a0)
        clr.b   9(a0)
        clr.l   10(a0)
        move.b  #PA_SIGNAL,14(a0)
        move.b  d3,15(a0)
        suba.l  a1,a1
        jsr     LVOFindTask(a6)
        ; Exec library calls may freely clobber D0/D1/A0/A1.  In particular,
        ; A0 is NOT guaranteed to still point at kbd_port after FindTask().
        ; Re-load it before completing the MsgPort and again before storing
        ; mn_ReplyPort.  Without this, KS2 can stall in DoIO and KS1.3 can
        ; fault because the keyboard reply port is built through a stale A0.
        lea     kbd_port,a0
        move.l  d0,16(a0)
        lea     24(a0),a1
        move.l  a1,20(a0)          ; lh_Head -> lh_Tail
        clr.l   24(a0)             ; lh_Tail = NULL
        lea     20(a0),a1
        move.l  a1,28(a0)          ; lh_TailPred -> lh_Head
        clr.w   32(a0)

        lea     kbd_io,a1
        move.b  #NT_MESSAGE,8(a1)  ; io_Message.mn_Node.ln_Type
        lea     kbd_port,a0
        move.l  a0,14(a1)          ; mn_ReplyPort
        move.w  #48,18(a1)         ; mn_Length = sizeof(IOStdReq)
        lea     keyboard_name,a0
        moveq   #0,d0
        moveq   #0,d1
        jsr     LVOOpenDevice(a6)
        tst.b   d0
        bne.s   .open_fail
        move.b  #1,keyboard_available
        bra.s   .done
.open_fail:
        moveq   #0,d0
        move.b  kbd_sigbit,d0
        jsr     LVOFreeSignal(a6)
        move.b  #$ff,kbd_sigbit
.done:
        movem.l (sp)+,d0-d3/a0-a2/a6
        rts

v78_input_shutdown:
        movem.l d0/a1/a6,-(sp)
        move.l  4.w,a6
        tst.b   keyboard_available
        beq.s   .no_device
        ; A read may still be in flight. CloseDevice() with an outstanding
        ; request is illegal, so it must be reaped first. AbortIO() is only
        ; a request the device may ignore, so this is the one place in the
        ; input code that can still legitimately wait on the device - but
        ; only once, at shutdown, never every frame.
        tst.b   kbd_io_pending
        beq.s   .close
        lea     kbd_io,a1
        jsr     LVOAbortIO(a6)
        lea     kbd_io,a1
        jsr     LVOWaitIO(a6)
        clr.b   kbd_io_pending
.close:
        lea     kbd_io,a1
        jsr     LVOCloseDevice(a6)
        clr.b   keyboard_available
.no_device:
        moveq   #0,d0
        move.b  kbd_sigbit,d0
        cmp.b   #$ff,d0
        beq.s   .done
        jsr     LVOFreeSignal(a6)
        move.b  #$ff,kbd_sigbit
.done:
        movem.l (sp)+,d0/a1/a6
        rts

; Refresh 13-byte keyboard matrix.  On failure/not-yet-ready, bytes 8/9 are
; cleared so stale cursor/Return state can never trap the menu or player.
;
; This keeps exactly one KBD_READMATRIX in flight at a time, persisting
; across ticks, instead of issuing-and-blocking-for one every single tick.
; A prior version here used DoIO() directly, which blocks the whole task
; until the device replies - if that reply was ever delayed, the entire
; game hung (the original KS2.0 title-screen freeze). A later attempt
; polled with CheckIO() and fell back to AbortIO()+WaitIO() on a timeout -
; but AbortIO() is only a request the device is free to ignore ("This may
; or may not be done" - exec.library/AbortIO), so that fallback's WaitIO()
; could still hang exactly as badly as the original DoIO() whenever the
; device genuinely never replies. This version never calls WaitIO() except
; immediately after CheckIO() has already confirmed - non-blockingly - that
; the request is complete, so nothing in this routine can ever block,
; regardless of whether keyboard.device replies quickly, slowly, or not at
; all. Confirmed against the exec.library reference implementation: SendIO()
; always clears io_Flags/ln_Type before calling the device, CheckIO() only
; inspects ln_Type (never waits), and WaitIO()'s wait loop runs only while
; CheckIO() would have reported "still busy" - so back-to-back
; CheckIO-then-WaitIO cannot block.
v78_keyboard_read:
        movem.l d1/a0-a1/a6,-(sp)
        tst.b   keyboard_available
        beq.w   .clear
        move.l  4.w,a6

        tst.b   kbd_io_pending
        bne.s   .have_pending

        ; Nothing in flight yet (first call since init/shutdown): kick one
        ; off and leave this tick's matrix cleared.  The result shows up on
        ; a later tick once the device has actually replied.
        bsr     v78_keyboard_kick
        bra.s   .clear

.have_pending:
        lea     kbd_io,a1
        jsr     LVOCheckIO(a6)
        tst.l   d0
        beq.s   .done           ; still pending - leave kbd_matrix untouched,
                                 ; i.e. keep the last successfully read state

        ; Complete: WaitIO() right after a non-zero CheckIO() cannot block.
        lea     kbd_io,a1
        jsr     LVOWaitIO(a6)
        clr.b   kbd_io_pending
        tst.b   d0
        bne.s   .clear
        bsr     v78_keyboard_kick
        bra.s   .done

.clear:
        clr.b   kbd_matrix+8
        clr.b   kbd_matrix+9
.done:
        movem.l (sp)+,d1/a0-a1/a6
        rts

; Issues one asynchronous KBD_READMATRIX and marks it in flight. Never
; blocks - SendIO() only queues the request via the device's BeginIO() and
; returns. Assumes a6 = ExecBase (the caller's convention throughout this
; file).
v78_keyboard_kick:
        lea     kbd_io,a1
        move.w  #KBD_READMATRIX,28(a1)
        clr.b   30(a1)
        move.l  #KBD_MATRIX_LEN,36(a1)
        lea     kbd_matrix,a0
        move.l  a0,40(a1)
        jsr     LVOSendIO(a6)
        move.b  #1,kbd_io_pending
        rts

; Synchronize mouse quadrature counters without generating movement.
v78_mouse_sync:
        move.w  JOY0DAT,mouse_prev_joy
        clr.w   mouse_y_accum
        rts

; Return signed mouse delta: d0.w = X, d1.w = Y.  Byte subtraction naturally
; handles the 8-bit hardware counter wraparound.
v78_mouse_delta:
        move.w  JOY0DAT,d2
        move.w  mouse_prev_joy,d3
        move.w  d2,mouse_prev_joy
        moveq   #0,d0
        move.b  d2,d0
        sub.b   d3,d0
        ext.w   d0
        lsr.w   #8,d2
        lsr.w   #8,d3
        moveq   #0,d1
        move.b  d2,d1
        sub.b   d3,d1
        ext.w   d1
        rts

; Reset edge detectors when switching screens so a held button cannot
; immediately activate the next screen.
v78_ui_reset_edges:
        move.b  #(UI_UP+UI_DOWN),ui_prev_dirs
        move.b  #(UI_SELECT+UI_BACK),ui_prev_buttons
        clr.b   ui_mouse_cooldown
        clr.w   mouse_y_accum
        bsr     v78_mouse_sync
        rts

; d0.b result = UI_* newly-triggered actions.
v78_read_ui:
        movem.l d1-d7/a0-a1,-(sp)
        moveq   #0,d6              ; event bits
        moveq   #0,d4              ; held up/down bits
        moveq   #0,d5              ; held select/back bits

        ; Port-2 joystick / CDTV remote JOY mode.
        move.w  JOY1DAT,d1
        move.w  d1,d2
        lsr.w   #1,d2
        eor.w   d2,d1
        btst    #8,d1              ; forward/up = bit9 xor bit8
        beq.s   .joy_down
        or.b    #UI_UP,d4
        move.b  #CONTROL_JOYSTICK,last_ui_control
.joy_down:
        btst    #0,d1              ; back/down = bit1 xor bit0
        beq.s   .joy_fire
        or.b    #UI_DOWN,d4
        move.b  #CONTROL_JOYSTICK,last_ui_control
.joy_fire:
        btst    #7,CIAAPRA
        bne.s   .keyboard
        or.b    #UI_SELECT,d5
        move.b  #CONTROL_JOYSTICK,last_ui_control

.keyboard:
        bsr     v78_keyboard_read
        move.b  kbd_matrix+9,d1
        btst    #4,d1              ; raw $4C cursor up
        beq.s   .kbd_down
        or.b    #UI_UP,d4
        move.b  #CONTROL_CURSOR,last_ui_control
.kbd_down:
        btst    #5,d1              ; raw $4D cursor down
        beq.s   .kbd_buttons
        or.b    #UI_DOWN,d4
        move.b  #CONTROL_CURSOR,last_ui_control
.kbd_buttons:
        move.b  kbd_matrix+8,d1
        btst    #0,d1              ; raw $40 space
        bne.s   .kbd_select
        btst    #4,d1              ; raw $44 return
        beq.s   .kbd_escape
.kbd_select:
        or.b    #UI_SELECT,d5
        move.b  #CONTROL_CURSOR,last_ui_control
.kbd_escape:
        btst    #5,d1              ; raw $45 escape
        beq.s   .mouse
        or.b    #UI_BACK,d5
        move.b  #CONTROL_CURSOR,last_ui_control

.mouse:
        ; Mouse support removed: moving the mouse was triggering Intuition's
        ; own background mouse-pointer sprite handling, corrupting the
        ; display - the same class of artifact the one-time SPREN clear at
        ; boot was meant to prevent, which doesn't survive the OS
        ; re-asserting it on its own mouse interrupt. Joystick, keyboard
        ; cursor keys, and keyboard select/escape remain fully functional.

.edges:
        ; Up/down from joystick+keyboard are edge-triggered. Mouse movement was
        ; already converted to one-shot d6 events above.
        move.b  d4,d1
        move.b  ui_prev_dirs,d2
        not.b   d2
        and.b   d2,d1
        or.b    d1,d6
        move.b  d4,ui_prev_dirs

        move.b  d5,d1
        move.b  ui_prev_buttons,d2
        not.b   d2
        and.b   d2,d1
        or.b    d1,d6
        move.b  d5,ui_prev_buttons

        moveq   #0,d0
        move.b  d6,d0
        movem.l (sp)+,d1-d7/a0-a1
        rts

; Cursor gameplay backend. d0.b = -1/0/+1.
v78_read_cursor:
        bsr     v78_keyboard_read
        moveq   #0,d0
        move.b  kbd_matrix+9,d1
        btst    #7,d1              ; raw $4F left
        beq.s   .right
        moveq   #-1,d0
.right:
        btst    #6,d1              ; raw $4E right
        beq.s   .done
        tst.b   d0
        bne.s   .both
        moveq   #1,d0
        bra.s   .done
.both:
        moveq   #0,d0
.done:
        rts

; Mouse gameplay backend.  Horizontal motion is translated into the same
; one-step left/right intent as the original joystick controls.
; Mouse support removed (see v78_read_ui's .mouse: comment) - always neutral,
; so a stray CONTROL_MOUSE value (not reachable from the OPTIONS cycle
; anymore, but kept as a dispatch target for safety) does nothing, and
; AUTO's mouse-discovery step below always falls through to CURSOR.
v78_read_mouse_game:
        moveq   #0,d0
        rts

; d0.b = -1/0/+1 according to CONTROL. AUTO prefers the controller used to
; operate the title menu; if none was established it discovers one safely.
v78_read_game_control:
        moveq   #0,d1
        move.b  control_mode,d1
        cmp.b   #CONTROL_JOYSTICK,d1
        beq.w   v7_read_joystick
        cmp.b   #CONTROL_MOUSE,d1
        beq.w   v78_read_mouse_game
        cmp.b   #CONTROL_CURSOR,d1
        beq.w   v78_read_cursor

        ; AUTO.  If title navigation already identified a controller, use it.
        tst.b   active_control
        bne.s   .dispatch_active
        move.b  last_ui_control,d1
        beq.s   .discover
        move.b  d1,active_control
.dispatch_active:
        moveq   #0,d1
        move.b  active_control,d1
        cmp.b   #CONTROL_JOYSTICK,d1
        beq.w   v7_read_joystick
        cmp.b   #CONTROL_MOUSE,d1
        beq.w   v78_read_mouse_game
        cmp.b   #CONTROL_CURSOR,d1
        beq.w   v78_read_cursor
.discover:
        ; Port 2 digital joystick: require the same non-zero direction twice so
        ; floating inputs on an unconnected port cannot steal AUTO immediately.
        bsr     v7_read_joystick
        tst.b   d0
        beq.s   .try_mouse
        cmp.b   auto_joy_dir,d0
        beq.s   .lock_joy
        move.b  d0,auto_joy_dir
        moveq   #0,d0
        rts
.lock_joy:
        move.b  #CONTROL_JOYSTICK,active_control
        clr.b   auto_joy_dir
        rts
.try_mouse:
        clr.b   auto_joy_dir
        bsr     v78_read_mouse_game
        tst.b   d0
        beq.s   .try_cursor
        move.b  #CONTROL_MOUSE,active_control
        rts
.try_cursor:
        bsr     v78_read_cursor
        tst.b   d0
        beq.s   .none
        move.b  #CONTROL_CURSOR,active_control
.none:
        rts

; d0.b = -1 left, 0 neutral/both, +1 right.
; Port 2 only. Dual-port support (also checking JOY0DAT) was removed:
; an unconnected port's digital inputs can float and read as spurious
; noise on real hardware, and OR'ing that with a genuinely-connected
; port 2 could intermittently cancel out real input via the "both
; directions pressed = neutral" logic below - a plausible explanation
; for reported intermittent missed joystick movements. The game has
; always officially expected the joystick in port 2 (also used
; throughout earlier versions of this project), so there's no
; functional loss in dropping port 1 as an alternate.
v7_read_joystick:
        move.w  JOY1DAT,d1
        moveq   #0,d0
        btst    #9,d1
        beq   .right_test
        moveq   #-1,d0
.right_test:
        btst    #1,d1
        beq   .done
        tst.b   d0
        bne   .both
        moveq   #1,d0
        bra   .done
.both:
        moveq   #0,d0
.done:
        rts

; -----------------------------------------------------------------------------
; TEETH — direct controller/teeth.asm timing
; -----------------------------------------------------------------------------
v7_update_teeth:
        subq.w  #4,teeth_y
        cmp.w   #-24,teeth_y
        bgt   .horizontal
        bsr     v7_respawn_teeth
        bra   .anim
.horizontal:
        moveq   #0,d0
        move.b  teeth_vx,d0
        ext.w   d0
        add.w   d0,teeth_x
        cmp.w   #24,teeth_x
        bge   .right_bound
        move.b  #4,teeth_vx
        bra   .anim
.right_bound:
        cmp.w   #200,teeth_x
        blt   .anim
        move.b  #-4,teeth_vx
.anim:
        addq.b  #1,teeth_frame
        and.b   #3,teeth_frame
        rts

v7_respawn_teeth:
        bsr     random16
        and.w   #$00ff,d0
        cmp.w   #200,d0
        blt   .xok
        sub.w   #200,d0
.xok:
        move.w  d0,teeth_x
        move.w  #191,teeth_y
        bsr     random16
        cmp.b   #128,d0
        blo   .left
        move.b  #4,teeth_vx
        bra   .color
.left:
        move.b  #-4,teeth_vx
.color:
        bsr     random16
        lsr.w   #8,d0
        and.w   #3,d0
        lea     hazard_colors,a0
        move.b  (a0,d0.w),teeth_color
        rts

; -----------------------------------------------------------------------------
; EYE — movement retained from previous Spectrum reverse engineering; rendering
; uses the exact source directional/phase graphics and exact 4-frame explosion.
; -----------------------------------------------------------------------------
v7_update_eye:
        tst.b   v7_eye_dead
        bne   .explode
        move.w  eye_x,v7_eye_prevx
        bsr     update_eye
        move.w  eye_x,d0
        cmp.w   v7_eye_prevx,d0
        beq   .anim
        blt   .left
        move.b  #1,v7_eye_dir
        bra   .anim
.left:
        clr.b   v7_eye_dir
.anim:
        ; old update_eye increments eye_frame; clamp timing to four-state cadence
        and.b   #3,eye_frame
        rts
.explode:
        addq.b  #1,v7_eye_exp_frame
        cmp.b   #4,v7_eye_exp_frame
        ble   .done
        clr.b   v7_eye_dead
        clr.b   v7_eye_exp_frame
        bsr     respawn_eye
.done:
        rts

; -----------------------------------------------------------------------------
; WORLD OBJECTS
; -----------------------------------------------------------------------------
; The aircon and vase are WALL-MOUNTED objects.  They do not have an arbitrary
; vertical cycle: each belongs to a specific plain-brick mounting bay in the
; 200-row wall texture.  The reference annotation fixes those bays at roughly
; source row 64 (aircon) and source row 152 (vase).  Deriving their screen Y
; from world_scroll guarantees that neither object can drift onto either of the
; yellow protruding pillar/cap rows.  Only the clothesline uses those pillars.
;
; fan_y/sideobj_y are retained as cached screen-relative Y values because the
; existing renderers use them; they are recomputed every tick from wall phase.
; -----------------------------------------------------------------------------
v7_update_world:
        ; fan_y = (64 - world_scroll) mod 200.  Bottom-edge clipping in the
        ; renderer makes the wrapped object scroll in instead of popping in.
        move.w  #64,d0
        sub.w   world_scroll,d0
        bpl   .fan_y_ok
        add.w   #200,d0
.fan_y_ok:
        move.w  d0,fan_y
        eor.b   #1,fan_frame

        ; The vase is hidden for one complete pass after a life starts.  It is
        ; armed only when its row-152 bay wraps to y=192, so its first visible
        ; pixels enter through the wall bottom rather than appearing mid-wall.
        tst.b   v7_vase_active
        bne   .vase_active
        cmp.w   #160,world_scroll
        bne   .vase_hidden
        tst.b   v7_vase_waitwrap
        beq   .vase_activate
        clr.b   v7_vase_waitwrap
        bra   .vase_hidden
.vase_activate:
        move.b  #1,v7_vase_active
.vase_active:
        move.w  #152,d0
        sub.w   world_scroll,d0
        bpl   .vase_y_ok
        add.w   #200,d0
.vase_y_ok:
        move.w  d0,sideobj_y
        bra   .clothes
.vase_hidden:
        move.w  #208,sideobj_y

.clothes:
        ; Clothesline attaches to the major yellow block-cap at the boundary
        ; of the 200-row wall section.  The marked reference crop identifies
        ; this large cap, not the small yellow side tabs previously used.
        ; Rope endpoints are on sprite row 0; cap row 2 gives a centred join.
        move.w  #2,d0
        sub.w   world_scroll,d0
        bpl   .clothes_attach_ok
        add.w   #200,d0
.clothes_attach_ok:
        move.w  d0,v7_clothes_y
.done:
        rts

v7_advance_wall:
        add.w   #8,world_scroll
        cmp.w   #200,world_scroll
        blt   .side_changes
        clr.w   world_scroll

.side_changes:
        ; Change side only when the corresponding wall-mounted object wraps
        ; from the top back to the bottom.  This preserves the mounting bay
        ; while still reproducing left/right variation from pass to pass.
        cmp.w   #72,world_scroll         ; aircon: row 64 -> next 8px step wraps
        bne   .vase_side
        bsr     random16
        and.b   #1,d0
        move.b  d0,fan_side
.vase_side:
        cmp.w   #160,world_scroll        ; vase bay begins entering at bottom
        bne   .clothes_cycle
        ; Pick the side for the next appearance while it is still at the seam.
        bsr     random16
        and.b   #1,d0
        move.b  d0,sideobj_side
.clothes_cycle:
        ; The major cap (source rows 1..4) re-enters through the bottom when
        ; world_scroll reaches 8.  Toggle clothes only at that cap seam.
        ; Keeping two initial cap passes hidden preserves the delayed arrival.
        cmp.w   #8,world_scroll
        bne   .done
        tst.b   v7_clothes_waitwrap
        beq   .clothes_toggle
        subq.b  #1,v7_clothes_waitwrap
        bne   .done
        move.b  #1,v7_clothes_visible
        bsr     random16
        and.b   #1,d0
        move.b  d0,v7_clothes_layout
        bra   .done
.clothes_toggle:
        bsr     random16
        and.b   #1,d0
        move.b  d0,v7_clothes_layout
        eor.b   #1,v7_clothes_visible
.done:
        rts

; -----------------------------------------------------------------------------
; COLLISION — explicit source-sized boxes, no artificial grace period.
; -----------------------------------------------------------------------------
v7_collisions:
        move.w  player_x,d0
        cmp.w   #20,d0
        blt     v7_player_kill
        cmp.w   #220,d0
        bge     v7_player_kill

        move.w  teeth_x,d2
        move.w  teeth_y,d3
        move.w  #32,d4
        move.w  #24,d5
        bsr     collide_player_rect
        tst.b   d0
        bne     v7_player_kill

        tst.b   v7_eye_dead
        bne   .fan
        move.w  eye_x,d2
        move.w  eye_y,d3
        move.w  #16,d4
        move.w  #32,d5
        bsr     collide_player_rect
        tst.b   d0
        beq   .fan
        addq.w  #1,score
        move.b  #1,v7_eye_dead
        clr.b   v7_eye_exp_frame
        move.w  eye_x,v7_eye_ex_x
        move.w  eye_y,v7_eye_ex_y
        ; Every eyeball pickup keeps the recovered ZX rising chirp.  At each
        ; 50-point boundary, QUEUE one Colin line rather than starting it here:
        ;   50,150,250,...  -> I Like Your Style
        ;   100,200,300,... -> Fair Enough
        ; sample_audio_tick waits for zx_eye_count to reach zero, then starts
        ; Colin on AUD2/AUD3.  This prevents the 220 ms ZX chirp from masking
        ; the beginning of the speech while preserving the original ZX sound.
        ; sample_score_milestone_play returns d0.b=1 on any such boundary.
        bsr     zx_audio_trigger_eye
        bsr     sample_score_milestone_play
        tst.b   d0
        beq     .fan
        ; Preserve the proven one-frame milestone isolation so an unrelated
        ; fan/vase hit cannot kill the player in the same collision pass.
        rts

.fan:
        move.w  #16,d2
        tst.b   fan_side
        beq   .fanpos
        move.w  #216,d2
.fanpos:
        move.w  fan_y,d3
        move.w  #24,d4
        move.w  #24,d5
        bsr     collide_player_rect
        tst.b   d0
        bne     v7_player_kill

        move.w  #24,d2
        tst.b   sideobj_side
        beq   .potpos
        move.w  #224,d2
.potpos:
        move.w  sideobj_y,d3
        move.w  #8,d4
        move.w  #8,d5
        bsr     collide_player_rect
        tst.b   d0
        bne     v7_player_kill
        rts

v7_player_kill:
        cmp.b   #STATE_DEAD,game_state
        beq   .done
        move.b  #STATE_DEAD,game_state
        clr.w   death_timer
        bsr     sample_audio_on_death
        bsr     zx_audio_trigger_death
.done:
        rts

v7_dead_tick:
        bsr     v7_render_game
        move.w  death_timer,d6
        cmp.w   #4,d6
        bge   .wait_zx_sweep
        bsr     v7_draw_explosion_player
        bsr     v7_present_game_frame
        addq.w  #1,death_timer
        bra     main_loop

.wait_zx_sweep:
        ; The ZX code blocks in B57D until the descending beeper sweep has
        ; completed (state 1 -> 30, one step per 50 Hz HALT).  Keep the shaft
        ; frozen/player absent after the four visible explosion frames while
        ; Paula finishes the same 28-step sweep, then respawn/show GAME OVER.
        ;
        ; SOUNDFX=OFF must mute audio only, not alter game timing.  In that mode
        ; the ZX audio state machine is intentionally inactive, so age the same
        ; 560 ms death interval with the existing 25 Hz death_timer instead.
        tst.b   soundfx_enabled
        bne.s   .wait_audible_death
        cmp.w   #14,death_timer          ; 14 * 40 ms = 560 ms total
        bge.s   .finish
        bsr     v7_present_game_frame
        addq.w  #1,death_timer
        bra     main_loop
.wait_audible_death:
        tst.b   zx_death_state
        beq.s   .finish
        bsr     v7_present_game_frame
        bra     main_loop

.finish:
        subq.b  #1,lives
        beq.s   .gameover
        ; Non-final life loss has no Colin speech in v7.7e.  Fair Enough is now
        ; reserved for the "You do it" opening response and 100/200/... milestones.
        bra.s   .again
.gameover:
        ; No hearts remain once GAME OVER is shown.
        clr.b   lives
        bsr     update_highscore
        bsr     zx_audio_disable
        ; Restore the exact v7.6b ordering that was confirmed working by test:
        ; start the combined HitFloor -> See You Around Paula stream first,
        ; then enter GAME OVER.  This path is still dedicated and cannot be
        ; selected by normal gameplay speech.
        bsr     sample_gameover_play
        tst.b   high_score_new
        beq.s   .no_new_hs2
        bsr     v78_hiscore_entry_begin
        move.b  #STATE_HISCORE_ENTRY,game_state
        bra     main_loop
.no_new_hs2:
        move.b  #STATE_GAMEOVER,game_state
        bra     main_loop
.again:
        clr.b   zx_eye_count
        bsr     v7_round_reset
        bsr     v7_entry_reset
        move.b  #STATE_ENTER,game_state
        bra     main_loop

v7_gameover_tick:
        bsr     v7_render_gameover
        bsr     present_frame
        bsr     v78_read_ui
        and.b   #(UI_SELECT+UI_BACK),d0
        beq.w   main_loop
        bsr     game_to_title
        bra.w   main_loop

v7_render_gameover:
        bsr     v7_render_game
        ; Original presentation is a widely spaced white "GAME   OVER".
        move.b  #COL_WHITE,cur_color
        lea     v7_game_over_spaced,a0
        move.w  #108,d0                ; 104px bitmap centered in 320px
        move.w  #116,d1
        move.w  #13,d2
        move.w  #7,d3
        bsr     draw_bitmap_color
        rts

; -----------------------------------------------------------------------------
; 25-Hz presenter. Existing present_frame performs one WaitTOF; this adds the
; second VBlank without duplicating the Copper/buffer-swap code.
; -----------------------------------------------------------------------------
v7_present_game_frame:
        ; First PAL field of the 25 Hz game frame.  audio_service runs the
        ; per-field ticks for every field that has really elapsed.
        move.l  gfxbase,a6
        jsr     LVOWaitTOF(a6)
        bsr     audio_service
        ; present_frame queues the new Copper list, waits for the second field
        ; (where the Copper switches) and services audio again.
        bra     present_frame

; -----------------------------------------------------------------------------
; ZX SPECTRUM 1-BIT BEEPER SOUND ENGINE -> PAULA
;
; -----------------------------------------------------------------------------
; LOW-FI PAULA SAMPLE LAYER (AUD2+AUD3)
; -----------------------------------------------------------------------------
; The low-fi bank is deliberately external to the flat executable.  Boot ADFs
; preload it at $60000, while a future AmigaDOS/Shell build can load the
; exact same nohzdyve_samples.bin into any Chip-RAM block and call
; sample_audio_bind_bank with A0 = that block.  No playback routine below
; contains a hard-coded bank address.
;
; Amiga stereo mapping: AUD2=right, AUD3=left, so duplicating one mono sample
; to both channels centers it. AUD0+AUD1 remain exclusively the ZX beeper.
;
; v7.7e uses the same AUD2/AUD3 layer for title dialogue, the randomized
; Stefan/Colin opening exchange, and alternating 50-point milestone lines.
; GAME OVER retains its dedicated HitFloor -> See You Around path, which remains
; unreachable from all ordinary dialogue dispatchers.
; -----------------------------------------------------------------------------
sample_audio_init:
        move.l  #SAMPLE_BANK_DEFAULT_ADDR,a0
        bsr     sample_audio_bind_bank
        clr.b   sample_wind_wanted
        clr.b   sample_wind_playing
        clr.b   sample_voice_active
        move.b  #SAMPLE_VOICE_NONE,sample_voice_current
        move.b  #SAMPLE_VOICE_NONE,sample_voice_next
        clr.w   sample_voice_ticks
        clr.b   sample_opening_stage
        clr.b   sample_opening_response
        clr.w   sample_opening_delay
        bsr     sample_attract_reset
        bsr     sample_aux_hw_stop
        rts

; A0 = bank base in Chip RAM.  Public entry point for the later Shell loader.
sample_audio_bind_bank:
        move.l  a0,sample_bank_ptr
        cmp.l   #SAMPLE_BANK_MAGIC,(a0)
        bne.s   .bad
        move.b  #1,sample_audio_enabled
        rts
.bad:
        clr.b   sample_audio_enabled
        clr.l   sample_bank_ptr
        rts

sample_audio_new_game:
        clr.b   sample_opening_stage
        clr.b   sample_opening_response
        clr.w   sample_opening_delay
        clr.b   sample_wind_wanted
        clr.b   sample_wind_playing
        clr.b   sample_voice_active
        move.b  #SAMPLE_VOICE_NONE,sample_voice_current
        move.b  #SAMPLE_VOICE_NONE,sample_voice_next
        clr.w   sample_voice_ticks
        bsr     sample_aux_hw_stop
        rts

sample_audio_stop_all:
        clr.b   sample_opening_stage
        clr.b   sample_opening_response
        clr.w   sample_opening_delay
        clr.b   sample_wind_wanted
        clr.b   sample_wind_playing
        clr.b   sample_voice_active
        move.b  #SAMPLE_VOICE_NONE,sample_voice_current
        move.b  #SAMPLE_VOICE_NONE,sample_voice_next
        clr.w   sample_voice_ticks
        bsr     sample_aux_hw_stop
        rts

; Death cuts wind/optional milestone speech immediately. Final-death speech is
; scheduled later, after the original ZX descending chirp has completed.
sample_audio_on_death:
        clr.b   sample_wind_wanted
        clr.b   sample_wind_playing
        clr.b   sample_voice_active
        move.b  #SAMPLE_VOICE_NONE,sample_voice_current
        move.b  #SAMPLE_VOICE_NONE,sample_voice_next
        clr.w   sample_voice_ticks
        bsr     sample_aux_hw_stop
        rts

sample_aux_hw_stop:
        move.w  #$000c,DMACON       ; clear AUD2 + AUD3 DMA
        clr.w   AUD2VOL
        clr.w   AUD3VOL
        rts

; When speech replaces the quiet wind, do not cut the looping waveform at a
; random non-zero sample value.  That discontinuity can produce an intermittent
; click/thump that sounds deceptively like the HitFloor impact.  v7.7f stretches
; the fade to ~1.3 ms (20 PAL raster lines) before DMA is disabled.
sample_aux_hw_stop_smooth:
        tst.b   sample_wind_playing
        beq.s   .hard
        move.w  #7,AUD2VOL
        move.w  #7,AUD3VOL
        bsr     sample_wait_four_lines
        move.w  #5,AUD2VOL
        move.w  #5,AUD3VOL
        bsr     sample_wait_four_lines
        move.w  #3,AUD2VOL
        move.w  #3,AUD3VOL
        bsr     sample_wait_four_lines
        move.w  #1,AUD2VOL
        move.w  #1,AUD3VOL
        bsr     sample_wait_four_lines
        clr.w   AUD2VOL
        clr.w   AUD3VOL
        bsr     sample_wait_four_lines
.hard:
        move.w  #$000c,DMACON
        clr.w   AUD2VOL
        clr.w   AUD3VOL
        rts

; Approximately 4*64 us on PAL. Used only for the low-volume wind fade.
sample_wait_four_lines:
        movem.l d0-d2,-(sp)
        moveq   #3,d2
.sw4_next:
        move.w  VHPOSR,d0
        and.w   #$ff00,d0
.sw4_wait:
        move.w  VHPOSR,d1
        and.w   #$ff00,d1
        cmp.w   d0,d1
        beq.s   .sw4_wait
        dbra    d2,.sw4_next
        movem.l (sp)+,d0-d2
        rts

; Paula DMA does not necessarily become idle on the exact CPU cycle that
; DMACON is cleared.  Wait two raster-line transitions before replacing LC/LEN
; when switching from the looping wind to a voice.
sample_wait_two_lines:
        movem.l d0-d1,-(sp)
        move.w  VHPOSR,d0
        and.w   #$ff00,d0
.wait1:
        move.w  VHPOSR,d1
        and.w   #$ff00,d1
        cmp.w   d0,d1
        beq.s   .wait1
        move.w  d1,d0
.wait2:
        move.w  VHPOSR,d1
        and.w   #$ff00,d1
        cmp.w   d0,d1
        beq.s   .wait2
        movem.l (sp)+,d0-d1
        rts

; Make AUD2+AUD3 true one-shot channels without requiring an audio IRQ.
; After DMA is enabled, wait for two raster-line transitions so Paula has
; latched the initial LC/LEN into its internal current pointer/counter.  Then
; program the public reload registers to a one-word zero buffer.  At the end
; of the audible sample Paula therefore reloads silence instead of the sample.
sample_arm_silent_reload:
        movem.l d0-d1/a0,-(sp)
        move.w  VHPOSR,d0
        and.w   #$ff00,d0
.wait_line1:
        move.w  VHPOSR,d1
        and.w   #$ff00,d1
        cmp.w   d0,d1
        beq.s   .wait_line1
        move.w  d1,d0
.wait_line2:
        move.w  VHPOSR,d1
        and.w   #$ff00,d1
        cmp.w   d0,d1
        beq.s   .wait_line2
        lea     sample_silence_word,a0
        move.l  a0,AUD2LCH
        move.l  a0,AUD3LCH
        move.w  #1,AUD2LEN
        move.w  #1,AUD3LEN
        movem.l (sp)+,d0-d1/a0
        rts

; Start/mark wind wanted. If a voice owns AUD2+3, defer until it ends.
sample_audio_start_wind:
        tst.b   digi_sounds_enabled
        beq.s   .done
        tst.b   sample_audio_enabled
        beq.s   .done
        move.b  #1,sample_wind_wanted
        tst.b   sample_voice_active
        bne.s   .done
        bsr     sample_wind_start_hw
.done:
        rts

sample_wind_start_hw:
        tst.b   digi_sounds_enabled
        beq.s   .done
        tst.b   sample_audio_enabled
        beq.s   .done
        move.l  sample_bank_ptr,a0
        beq.s   .done
        adda.l  #SMP_WIND_OFF,a0
        move.w  #$000c,DMACON
        move.l  a0,AUD2LCH
        move.l  a0,AUD3LCH
        move.w  #SMP_WIND_LEN,AUD2LEN
        move.w  #SMP_WIND_LEN,AUD3LEN
        move.w  #SMP_WIND_PER,AUD2PER
        move.w  #SMP_WIND_PER,AUD3PER
        move.w  #SMP_WIND_VOL,AUD2VOL
        move.w  #SMP_WIND_VOL,AUD3VOL
        move.w  #$800c,DMACON
        move.b  #1,sample_wind_playing
.done:
        rts

; -----------------------------------------------------------------------------
; TITLE ATTRACT DIALOGUE (v7.7e)
; -----------------------------------------------------------------------------
; All waits use CIA-A TOD PAL fields rather than rendered-frame counts.  The
; countdown is a WORD because the requested 10-second pause is 500 PAL fields
; and therefore cannot fit in the old 8-bit timer.
;
; Repeating title sequence:
;   3.0 s after entering title -> Colin "One of us is jumping"
;   phrase end + 1.0 s         -> Colin "Who's it gonna be?"
;   phrase end + 10.0 s        -> Colin "Come on"
;   phrase end + 2.0 s         -> Colin "Which one of us is jumping?"
;   phrase end + 10.0 s        -> repeat from "One of us is jumping"
;
; Every phrase remains a true Paula one-shot.  The scheduler deliberately does
; not wait for sample_voice_ticks, because that counter is serviced by rendered
; frames on the title screen and would stretch on a slow A500.

sample_attract_reset:
        move.b  vbl_counter+3,d0        ; v7.8b: VERTB counter, not CIA TOD
        move.b  d0,sample_attract_tod
        move.w  #150,sample_attract_delay     ; initial 3.0 seconds
        clr.b   sample_attract_index
        rts

sample_attract_tick:
        tst.b   digi_sounds_enabled
        beq.w   .done
        ; Attract dialogue is allowed to keep triggering on any of the idle
        ; menu screens (TITLE/OPTIONS/HISCORE/CREDITS/EXIT), not just TITLE,
        ; and switching between them no longer cuts it off (see the menu
        ; transitions above, which no longer call sample_audio_stop_all).
        cmp.b   #STATE_TITLE,game_state
        beq.s   .menu_ok
        cmp.b   #STATE_OPTIONS,game_state
        beq.s   .menu_ok
        cmp.b   #STATE_HISCORE,game_state
        beq.s   .menu_ok
        cmp.b   #STATE_CREDITS,game_state
        beq.s   .menu_ok
        cmp.b   #STATE_EXIT,game_state
        beq.s   .menu_ok
        bra.w   .done
.menu_ok:
        tst.b   sample_audio_enabled
        beq.w   .done

        ; Convert the modulo-256 CIA TOD low-byte movement into elapsed PAL fields
        ; since the previous title tick, then consume that amount from the WORD
        ; countdown.  This permits 10-second/500-field waits without relying on
        ; render rate.
        moveq   #0,d0
        move.b  vbl_counter+3,d0        ; v7.8b: VERTB counter, not CIA TOD
        moveq   #0,d1
        move.b  sample_attract_tod,d1
        move.b  d0,sample_attract_tod
        sub.w   d1,d0
        bpl.s   .elapsed_ok
        add.w   #256,d0
.elapsed_ok:
        tst.w   d0
        beq.w   .done
        cmp.w   sample_attract_delay,d0
        bhs.s   .fire
        sub.w   d0,sample_attract_delay
        bra.w   .done

.fire:
        moveq   #0,d0
        move.b  sample_attract_index,d0
        beq.s   .one_of_us
        cmp.b   #1,d0
        beq.s   .whos
        cmp.b   #2,d0
        beq.s   .come_on

        ; Fourth line: Which one of us is jumping?  Then wait 10 seconds and
        ; return to sequence index 0.
        moveq   #SMP_ID_WHICH_JUMPING,d0
        move.w  #(SMP_WHICH_JUMPING_TICKS+500),d1
        moveq   #0,d2
        bra.s   .play

.one_of_us:
        moveq   #SMP_ID_ONE_OF_US,d0
        move.w  #(SMP_ONE_OF_US_TICKS+50),d1     ; +1.0 s pause
        moveq   #1,d2
        bra.s   .play
.whos:
        moveq   #SMP_ID_WHOS_GONNA_BE,d0
        move.w  #(SMP_WHOS_GONNA_BE_TICKS+500),d1 ; +10.0 s pause
        moveq   #2,d2
        bra.s   .play
.come_on:
        moveq   #SMP_ID_COME_ON,d0
        move.w  #(SMP_COME_ON_TICKS+100),d1       ; +2.0 s pause
        moveq   #3,d2
.play:
        ; sample_attract_play preserves d1/d2.
        bsr     sample_attract_play
        move.b  d2,sample_attract_index
        move.w  d1,sample_attract_delay
.done:
        rts

; Shared one-shot dialogue player for title Colin lines and the two Stefan
; opening lines.  The whitelist intentionally excludes HitFloor / See You Around,
; so the dedicated GAME OVER stream cannot be selected here by accident.
sample_attract_play:
        movem.l d1-d6/a0,-(sp)
        moveq   #0,d6
        move.b  d0,d6
        tst.b   digi_sounds_enabled
        beq.w   .done
        tst.b   sample_audio_enabled
        beq.w   .done
        move.l  sample_bank_ptr,a0
        beq.w   .done
        cmp.b   #SMP_ID_COME_ON,d6
        beq     .come_on
        cmp.b   #SMP_ID_ONE_OF_US,d6
        beq.s   .one
        cmp.b   #SMP_ID_WHOS_GONNA_BE,d6
        beq.s   .whos
        cmp.b   #SMP_ID_WHICH_JUMPING,d6
        beq.s   .which
        cmp.b   #SMP_ID_STEFAN_I_DO_IT,d6
        beq.s   .ido
        cmp.b   #SMP_ID_STEFAN_YOU_DO_IT,d6
        beq.s   .youdo
        bra     .done
.come_on:
        adda.l  #SMP_COME_ON_OFF,a0
        move.w  #SMP_COME_ON_LEN,d2
        move.w  #SMP_COME_ON_TICKS,d3
        move.w  #SMP_COME_ON_VOL,d4
        move.w  #SMP_COME_ON_PER,d5
        bra     .start
.one:
        adda.l  #SMP_ONE_OF_US_OFF,a0
        move.w  #SMP_ONE_OF_US_LEN,d2
        move.w  #SMP_ONE_OF_US_TICKS,d3
        move.w  #SMP_ONE_OF_US_VOL,d4
        move.w  #SMP_ONE_OF_US_PER,d5
        bra.s   .start
.whos:
        adda.l  #SMP_WHOS_GONNA_BE_OFF,a0
        move.w  #SMP_WHOS_GONNA_BE_LEN,d2
        move.w  #SMP_WHOS_GONNA_BE_TICKS,d3
        move.w  #SMP_WHOS_GONNA_BE_VOL,d4
        move.w  #SMP_WHOS_GONNA_BE_PER,d5
        bra.s   .start
.which:
        adda.l  #SMP_WHICH_JUMPING_OFF,a0
        move.w  #SMP_WHICH_JUMPING_LEN,d2
        move.w  #SMP_WHICH_JUMPING_TICKS,d3
        move.w  #SMP_WHICH_JUMPING_VOL,d4
        move.w  #SMP_WHICH_JUMPING_PER,d5
        bra.s   .start
.ido:
        adda.l  #SMP_STEFAN_I_DO_IT_OFF,a0
        move.w  #SMP_STEFAN_I_DO_IT_LEN,d2
        move.w  #SMP_STEFAN_I_DO_IT_TICKS,d3
        move.w  #SMP_STEFAN_I_DO_IT_VOL,d4
        move.w  #SMP_STEFAN_I_DO_IT_PER,d5
        bra.s   .start
.youdo:
        adda.l  #SMP_STEFAN_YOU_DO_IT_OFF,a0
        move.w  #SMP_STEFAN_YOU_DO_IT_LEN,d2
        move.w  #SMP_STEFAN_YOU_DO_IT_TICKS,d3
        move.w  #SMP_STEFAN_YOU_DO_IT_VOL,d4
        move.w  #SMP_STEFAN_YOU_DO_IT_PER,d5
.start:
        bsr     sample_aux_hw_stop
        bsr     sample_wait_two_lines
        move.l  a0,AUD2LCH
        move.l  a0,AUD3LCH
        move.w  d2,AUD2LEN
        move.w  d2,AUD3LEN
        move.w  d5,AUD2PER
        move.w  d5,AUD3PER
        move.w  d4,AUD2VOL
        move.w  d4,AUD3VOL
        move.w  #$800c,DMACON

        ; Make this a true one-shot.
        ; After the phrase finishes Paula reloads silence, not the phrase.
        bsr     sample_arm_silent_reload

        move.w  d3,sample_voice_ticks
        move.b  #1,sample_voice_active
        move.b  d6,sample_voice_current
        clr.b   sample_wind_playing
.done:
        movem.l (sp)+,d1-d6/a0
        rts

; -----------------------------------------------------------------------------
; NEW-GAME SPOKEN EXCHANGE (v7.7e)
; -----------------------------------------------------------------------------
; The branch is chosen once when FIRE starts a new game.  CIA TOD schedules the
; hand-off from Stefan to Colin independently of title-render speed.
;
sample_opening_start:
        movem.l d0-d1,-(sp)
        clr.b   sample_opening_stage
        clr.b   sample_opening_response
        clr.w   sample_opening_delay
        tst.b   digi_sounds_enabled
        beq.s   .done
        tst.b   sample_audio_enabled
        beq.s   .done

        bsr     random16
        btst    #0,d0
        bne.s   .you_do_it

        ; Stefan: "I do it" -> Colin: "I like your style".
        move.b  #SAMPLE_OPEN_RESP_STYLE,sample_opening_response
        moveq   #SMP_ID_STEFAN_I_DO_IT,d0
        move.w  #SMP_STEFAN_I_DO_IT_TICKS,d1
        bra.s   .start_stefan

.you_do_it:
        ; Stefan: "You do it" -> Colin: "Fair enough".
        move.b  #SAMPLE_OPEN_RESP_FAIR,sample_opening_response
        moveq   #SMP_ID_STEFAN_YOU_DO_IT,d0
        move.w  #SMP_STEFAN_YOU_DO_IT_TICKS,d1

.start_stefan:
        bsr     sample_attract_play
        move.w  d1,sample_opening_delay
        move.b  #SAMPLE_OPEN_STEFAN,sample_opening_stage
.done:
        movem.l (sp)+,d0-d1
        rts

; Counts down sample_opening_delay by exactly one 50Hz tick per call, since
; this is called exactly once per v7_title_exit_tick iteration (one
; present_frame/VBlank wait each). The TICKS constants from sample_bank.inc
; are generated as 50Hz-tick counts specifically for this purpose.
;
; This used to measure elapsed time from CIAATODLO deltas instead. That has
; the same CIA-A TOD hardware latch hazard already documented elsewhere in
; this file (see the fan-animation counter comment in v7_render_title_scene):
; reading the TOD high byte latches all three TOD bytes until the low byte
; is read, and if anything else in the system (e.g. a timer.device request)
; reads the high byte without a matching low-byte read, every CIAATODLO read
; here keeps returning the same frozen value - elapsed delta computes to 0
; forever, and sample_opening_stage never advances. That stalled the opening
; exchange indefinitely on real hardware: the Stefan/Colin samples would
; start (triggered immediately, before any TOD-based waiting), then nothing
; would ever move it to the next stage, leaving the player stuck in the
; window until some unrelated input happened to touch CIA TOD elsewhere and
; break the latch. A plain per-call countdown can't get stuck this way.
sample_opening_tick:
        tst.b   digi_sounds_enabled
        bne.s   .enabled
        clr.b   sample_opening_stage
        clr.b   sample_opening_response
        clr.w   sample_opening_delay
        rts
.enabled:
        tst.b   sample_opening_stage
        beq.w   .done

        tst.w   sample_opening_delay
        beq.s   .stage_due
        subq.w  #1,sample_opening_delay
        bra.w   .done

.stage_due:
        cmp.b   #SAMPLE_OPEN_STEFAN,sample_opening_stage
        beq.s   .stefan_done
        cmp.b   #SAMPLE_OPEN_GAP,sample_opening_stage
        beq.s   .start_colin

        ; Colin has completed.  Release AUD2/AUD3 and allow the window-exit
        ; sequence to begin.  ZX audio is still disabled at this point.
        bsr     sample_aux_hw_stop
        clr.b   sample_voice_active
        move.b  #SAMPLE_VOICE_NONE,sample_voice_current
        move.b  #SAMPLE_VOICE_NONE,sample_voice_next
        clr.w   sample_voice_ticks
        clr.b   sample_opening_stage
        clr.b   sample_opening_response
        clr.w   sample_opening_delay
        bra.w   .done

.stefan_done:
        ; Do not reprogram AUD2/AUD3 in the same PAL field in which Stefan ends.
        ; Paula is currently reloading the one-word silence buffer.  Force DMA
        ; fully off, clear the software voice state, and leave one complete PAL
        ; field of quiet before starting Colin.  This avoids an intermittent
        ; real-hardware AUD2/AUD3 hand-off failure seen in v7.7d.
        bsr     sample_aux_hw_stop
        clr.b   sample_voice_active
        move.b  #SAMPLE_VOICE_NONE,sample_voice_current
        move.b  #SAMPLE_VOICE_NONE,sample_voice_next
        clr.w   sample_voice_ticks
        move.w  #1,sample_opening_delay
        move.b  #SAMPLE_OPEN_GAP,sample_opening_stage
        bra.w   .done

.start_colin:
        ; One PAL field has elapsed with AUD2/AUD3 disabled.  Start the response
        ; on the now-idle voice channels.  AUD0/AUD1 (ZX) are not enabled until
        ; the complete opening exchange has finished.
        cmp.b   #SAMPLE_OPEN_RESP_STYLE,sample_opening_response
        bne.s   .play_fair
        moveq   #SMP_ID_LIKE_STYLE,d0
        bsr     sample_voice_play
        move.w  #SMP_LIKE_STYLE_TICKS,sample_opening_delay
        bra.s   .response_started
.play_fair:
        bsr     sample_fair_enough_play
        move.w  #SMP_FAIR_ENOUGH_TICKS,sample_opening_delay
.response_started:
        move.b  #SAMPLE_OPEN_COLIN,sample_opening_stage
.done:
        rts

; Fair Enough voice used by the "You do it" opening response and the even
; 50-point milestones (100, 200, 300, ...).  It is a true one-shot.
sample_fair_enough_play:
        movem.l d0-d5/a0,-(sp)
        tst.b   digi_sounds_enabled
        beq.w   .done
        tst.b   sample_audio_enabled
        beq.w   .done
        move.l  sample_bank_ptr,a0
        beq.w   .done
        adda.l  #SMP_FAIR_ENOUGH_OFF,a0
        bsr     sample_aux_hw_stop_smooth
        bsr     sample_wait_two_lines
        move.l  a0,AUD2LCH
        move.l  a0,AUD3LCH
        move.w  #SMP_FAIR_ENOUGH_LEN,AUD2LEN
        move.w  #SMP_FAIR_ENOUGH_LEN,AUD3LEN
        move.w  #SMP_FAIR_ENOUGH_PER,AUD2PER
        move.w  #SMP_FAIR_ENOUGH_PER,AUD3PER
        move.w  #SMP_FAIR_ENOUGH_VOL,AUD2VOL
        move.w  #SMP_FAIR_ENOUGH_VOL,AUD3VOL
        move.w  #$800c,DMACON
        bsr     sample_arm_silent_reload
        move.w  #SMP_FAIR_ENOUGH_TICKS,sample_voice_ticks
        move.b  #1,sample_voice_active
        move.b  #SMP_ID_FAIR_ENOUGH,sample_voice_current
        move.b  #SAMPLE_VOICE_NONE,sample_voice_next
        clr.b   sample_wind_playing
.done:
        movem.l (sp)+,d0-d5/a0
        rts

; Score milestone speech.  Internal score units are 10 displayed points, so
; multiples of 5 are 50-point boundaries.  Modulo 10 distinguishes the two
; alternating phrases:
;   remainder 5 -> 50/150/250/...  -> I Like Your Style
;   remainder 0 -> 100/200/300/... -> Fair Enough
;
; v7.8 deliberately preserves the supplied v7.7f score routing: the milestone
; voice starts immediately after the ZX eye trigger.  The menu/audio-option work
; does not alter that known baseline behavior.
; Returns d0.b=1 when the current score is a milestone, else 0.
sample_score_milestone_play:
        movem.l d1-d2,-(sp)
        move.w  score,d1
        beq.s   .not_milestone
.mod10:
        cmp.w   #10,d1
        blt.s   .remainder
        sub.w   #10,d1
        bra.s   .mod10
.remainder:
        cmp.w   #5,d1
        beq.s   .style
        tst.w   d1
        beq.s   .fair
.not_milestone:
        moveq   #0,d0
        bra.s   .done
.style:
        moveq   #SMP_ID_LIKE_STYLE,d0
        bsr     sample_voice_play
        moveq   #1,d0
        bra.s   .done
.fair:
        bsr     sample_fair_enough_play
        moveq   #1,d0
.done:
        movem.l (sp)+,d1-d2
        rts

; D0.b = normal auxiliary voice ID.  This dispatcher accepts Come On (0)
; and I Like Your Style (1).  HitFloor / See You Around are not in this
; dispatcher at all; GAME OVER uses sample_gameover_play below.  This removes
; any possibility that a mid-game table-index error selects HitFloor.
sample_voice_play:
        movem.l d1-d6/a0,-(sp)
        moveq   #0,d6
        move.b  d0,d6
        tst.b   digi_sounds_enabled
        beq.w   .done
        tst.b   sample_audio_enabled
        beq     .done
        move.l  sample_bank_ptr,a0
        beq     .done
        cmp.b   #SMP_ID_COME_ON,d6
        beq.s   .come_on
        cmp.b   #SMP_ID_LIKE_STYLE,d6
        beq.s   .like_style
        bra     .done
.come_on:
        adda.l  #SMP_COME_ON_OFF,a0
        move.w  #SMP_COME_ON_LEN,d2
        move.w  #SMP_COME_ON_TICKS,d3
        move.w  #SMP_COME_ON_VOL,d4
        move.w  #SMP_COME_ON_PER,d5
        bra.s   .start
.like_style:
        adda.l  #SMP_LIKE_STYLE_OFF,a0
        move.w  #SMP_LIKE_STYLE_LEN,d2
        move.w  #SMP_LIKE_STYLE_TICKS,d3
        move.w  #SMP_LIKE_STYLE_VOL,d4
        move.w  #SMP_LIKE_STYLE_PER,d5
.start:
        ; Speech replaces only the auxiliary wind channels.  ZX AUD0/1 remain
        ; active exactly as requested.  Smoothly fade the low-volume wind first
        ; to avoid an arbitrary waveform cut producing an impact-like click.
        bsr     sample_aux_hw_stop_smooth
        bsr     sample_wait_two_lines
        move.l  a0,AUD2LCH
        move.l  a0,AUD3LCH
        move.w  d2,AUD2LEN
        move.w  d2,AUD3LEN
        move.w  d5,AUD2PER
        move.w  d5,AUD3PER
        move.w  d4,AUD2VOL
        move.w  d4,AUD3VOL
        move.w  #$800c,DMACON
        bsr     sample_arm_silent_reload
        move.w  d3,sample_voice_ticks
        move.b  #1,sample_voice_active
        move.b  d6,sample_voice_current
        clr.b   sample_wind_playing
.done:
        movem.l (sp)+,d1-d6/a0
        rts

; Dedicated GAME OVER stream.  This intentionally mirrors the proven v7.6b
; register sequence: no state gate and no pre-start settling delay.  HitFloor
; and See You Around are contiguous in the bank, so Paula plays them as one
; stream and then reloads a single silent word.
sample_gameover_play:
        movem.l d0-d5/a0,-(sp)
        tst.b   digi_sounds_enabled
        beq.w   .done
        tst.b   sample_audio_enabled
        beq     .done
        move.l  sample_bank_ptr,a0
        beq.s   .done
        adda.l  #SMP_HIT_FLOOR_OFF,a0
        move.w  #$000c,DMACON
        move.l  a0,AUD2LCH
        move.l  a0,AUD3LCH
        move.w  #SMP_HIT_FLOOR_LEN+SMP_SEE_YOU_LEN,AUD2LEN
        move.w  #SMP_HIT_FLOOR_LEN+SMP_SEE_YOU_LEN,AUD3LEN
        move.w  #SMP_HIT_FLOOR_PER,AUD2PER
        move.w  #SMP_HIT_FLOOR_PER,AUD3PER
        move.w  #50,AUD2VOL
        move.w  #50,AUD3VOL
        move.w  #$800c,DMACON
        bsr     sample_arm_silent_reload
        move.w  #SMP_HIT_FLOOR_TICKS+SMP_SEE_YOU_TICKS,sample_voice_ticks
        move.b  #1,sample_voice_active
        move.b  #SAMPLE_VOICE_NONE,sample_voice_current
        clr.b   sample_wind_playing
.done:
        movem.l (sp)+,d0-d5/a0
        rts

; Called at both PAL VBlanks, alongside the ZX engine. Paula clocks the audio;
; this only stops voices in their silent guard tail and starts queued/resumed
; material.  Score milestone playback follows the supplied v7.7f baseline.
sample_audio_tick:
        tst.b   digi_sounds_enabled
        beq.w   .done
        tst.b   sample_audio_enabled
        beq.w   .done
        tst.b   sample_voice_active
        beq.w   .wind_check
        tst.w   sample_voice_ticks
        beq.w   .voice_done
        subq.w  #1,sample_voice_ticks
        bne.w   .done
.voice_done:
        bsr     sample_aux_hw_stop
        clr.b   sample_voice_active
        move.b  #SAMPLE_VOICE_NONE,sample_voice_current
        move.b  sample_voice_next,d0
        cmp.b   #SAMPLE_VOICE_NONE,d0
        beq.w   .resume_wind
        move.b  #SAMPLE_VOICE_NONE,sample_voice_next
        bsr     sample_voice_play
        bra.w   .done
.resume_wind:
        tst.b   sample_wind_wanted
        beq.w   .done
        cmp.b   #STATE_PLAY,game_state
        bne.w   .done
        bsr     sample_wind_start_hw
        bra.w   .done
.wind_check:
        tst.b   sample_wind_wanted
        beq.w   .done
        tst.b   sample_wind_playing
        bne.w   .done
        cmp.b   #STATE_PLAY,game_state
        bne.w   .done
        bsr     sample_wind_start_hw
.done:
        rts

; Recovered from the user's original TAP:
;   B697       title/start burst (~881 Hz, ~7.4 ms)
;   B514-B5A2  50 Hz sequencer / self-modifying state machine
;   B5A3-B5E2  32-step normal-game note pointer table
;   B5E3-B6C9  six normal bursts + two intro bursts
;   B548-B561  eye rising sweep (11 short bursts)
;   B562-B57B  player-death descending sweep (28 short bursts)
;
; The original calls the sequencer once per Spectrum frame.  The Amiga game
; itself is intentionally 25 Hz, so audio is serviced twice per gameplay frame.
; Paula channels 0+1 carry the same mono sample to left+right.
; -----------------------------------------------------------------------------
zx_audio_init:
        clr.b   zx_audio_enabled
        clr.b   zx_start_pending
        clr.b   zx_start_count
        clr.b   zx_music_phase
        clr.b   zx_note_index
        clr.b   zx_eye_count
        clr.b   zx_death_state
        bsr     zx_audio_hw_stop
        rts

zx_audio_disable:
        clr.b   zx_audio_enabled
        clr.b   zx_start_pending
        clr.b   zx_start_count
        clr.b   zx_eye_count
        clr.b   zx_death_state
        bsr     zx_audio_hw_stop
        rts

zx_audio_game_start:
        tst.b   soundfx_enabled
        bne.s   .enabled
        bsr     zx_audio_disable
        rts
.enabled:
        ; v7.8b: ZX sound is gameplay-only.  The B697 title/start burst and the
        ; 16-slot hi/lo start countdown are no longer played; the in-game note
        ; sequence begins directly on the next 50 Hz tick.
        move.b  #1,zx_audio_enabled
        clr.b   zx_start_count
        move.b  #7,zx_music_phase       ; B589 init -> immediate at B51A
        move.b  #31,zx_note_index       ; source starts at $00FF then wraps to 0
        clr.b   zx_eye_count
        clr.b   zx_death_state
        rts

zx_audio_trigger_eye:
        tst.b   soundfx_enabled
        beq.s   .off
        move.b  #12,zx_eye_count        ; collision stores $0C at ZX B52B
        rts
.off:
        clr.b   zx_eye_count
        rts

zx_audio_trigger_death:
        tst.b   soundfx_enabled
        beq.s   .off
        move.b  #1,zx_death_state       ; collision stores 1 at ZX B563
        rts
.off:
        clr.b   zx_death_state
        rts

zx_audio_hw_stop:
        ; DMACON without bit15 clears selected DMA enables.
        move.w  #$0003,DMACON
        clr.w   AUD0VOL
        clr.w   AUD1VOL
        rts

; a0 = one 500-byte short PCM asset: exact 20 ms ZX slot followed by
; 20 ms guard silence.  In the normal case the next 50 Hz service stops DMA
; after the first slot; if rendering misses one VBlank, the guard prevents an
; audible replay/"slowdown" of the previous beep.
zx_audio_play_a0:
        move.w  #$0003,DMACON
        move.l  a0,AUD0LCH
        move.l  a0,AUD1LCH
        move.w  #ZX_AUDIO_SHORT_LEN,AUD0LEN
        move.w  #ZX_AUDIO_SHORT_LEN,AUD1LEN
        move.w  #ZX_AUDIO_PERIOD,AUD0PER
        move.w  #ZX_AUDIO_PERIOD,AUD1PER
        move.w  #ZX_AUDIO_VOL,AUD0VOL
        move.w  #ZX_AUDIO_VOL,AUD1VOL
        move.w  #$8003,DMACON
        rts

; a0 = one 2000-byte normal-game note asset.  The first ~6-9 ms is
; the exact ZX beeper burst and the remainder is silence up to the next 160 ms
; note boundary.  Letting Paula run this complete slot decouples audible tempo
; from occasional missed VBlanks in the CPU renderer.
zx_audio_play_note_a0:
        move.w  #$0003,DMACON
        move.l  a0,AUD0LCH
        move.l  a0,AUD1LCH
        move.w  #ZX_AUDIO_NOTE_LEN,AUD0LEN
        move.w  #ZX_AUDIO_NOTE_LEN,AUD1LEN
        move.w  #ZX_AUDIO_PERIOD,AUD0PER
        move.w  #ZX_AUDIO_PERIOD,AUD1PER
        move.w  #ZX_AUDIO_VOL,AUD0VOL
        move.w  #ZX_AUDIO_VOL,AUD1VOL
        move.w  #$8003,DMACON
        rts

; a0 = complete long effect, d0 = Paula length in words.  Eye/death sweeps
; play as one DMA stream so their 20 ms pitch steps are hardware-timed and
; cannot be stretched by a late graphics frame.
zx_audio_play_long_a0:
        move.w  #$0003,DMACON
        move.l  a0,AUD0LCH
        move.l  a0,AUD1LCH
        move.w  d0,AUD0LEN
        move.w  d0,AUD1LEN
        move.w  #ZX_AUDIO_PERIOD,AUD0PER
        move.w  #ZX_AUDIO_PERIOD,AUD1PER
        move.w  #ZX_AUDIO_VOL,AUD0VOL
        move.w  #ZX_AUDIO_VOL,AUD1VOL
        move.w  #$8003,DMACON
        rts

zx_audio_tick:
        movem.l d0-d2/a0-a1,-(sp)
        tst.b   soundfx_enabled
        bne.s   .enabled
        bsr     zx_audio_hw_stop
        clr.b   zx_audio_enabled
        clr.b   zx_eye_count
        clr.b   zx_death_state
        bra.w   .done
.enabled:

        ; B514 start countdown: these are short 20 ms source slots.  Stop the
        ; previous short sample first.  Each linked asset carries an extra
        ; silent slot as protection against a one-VBlank late service.
        moveq   #0,d0
        move.b  zx_start_count,d0
        beq   .sequence
        bsr     zx_audio_hw_stop
        subq.b  #1,d0
        move.b  d0,zx_start_count
        beq   .sequence_after_stop
        cmp.b   #8,d0
        blo   .intro_lo
        lea     zx_intro_hi_sample,a0
        bra   .play
.intro_lo:
        lea     zx_intro_lo_sample,a0
        bra   .play

.sequence:
        ; B519-B523: 3-bit frame phase.  Every eighth 50 Hz call advances the
        ; 32-step note index even while an effect overrides the audible note.
        moveq   #0,d0
        move.b  zx_music_phase,d0
        addq.b  #1,d0
        and.b   #7,d0
        move.b  d0,zx_music_phase
        bne   .effect_priority
        moveq   #0,d1
        move.b  zx_note_index,d1
        addq.b  #1,d1
        and.b   #31,d1
        move.b  d1,zx_note_index
        bra   .effect_priority

.sequence_after_stop:
        ; Start countdown has just reached zero and DMA is already stopped.
        moveq   #0,d0
        move.b  zx_music_phase,d0
        addq.b  #1,d0
        and.b   #7,d0
        move.b  d0,zx_music_phase
        bne   .effect_priority
        moveq   #0,d1
        move.b  zx_note_index,d1
        addq.b  #1,d1
        and.b   #31,d1
        move.b  d1,zx_note_index

.effect_priority:
        ; Death has highest priority.  Start the complete 560 ms sweep once,
        ; then only advance its ZX state counter; Paula clocks every pitch step.
        moveq   #0,d1
        move.b  zx_death_state,d1
        beq   .eye_test
        cmp.b   #1,d1
        bne   .death_advance
        move.b  #2,zx_death_state
        lea     zx_death_full,a0
        move.w  #ZX_AUDIO_DEATH_LEN,d0
        bsr     zx_audio_play_long_a0
        bra   .done
.death_advance:
        addq.b  #1,d1
        cmp.b   #30,d1
        beq   .death_done
        move.b  d1,zx_death_state
        bra   .done
.death_done:
        clr.b   zx_death_state
        bsr     zx_audio_hw_stop
        bra   .done

.eye_test:
        ; Eye chirp is likewise one continuous 220 ms DMA stream.  Counter 12
        ; means "not started yet"; the following ten calls age it to 1, and the
        ; terminal call clears it and may resume a normal note exactly as ZX.
        moveq   #0,d1
        move.b  zx_eye_count,d1
        beq   .normal_short
        cmp.b   #12,d1
        bne   .eye_advance
        move.b  #11,zx_eye_count
        lea     zx_eye_full,a0
        move.w  #ZX_AUDIO_EYE_LEN,d0
        bsr     zx_audio_play_long_a0
        bra   .done
.eye_advance:
        subq.b  #1,d1
        move.b  d1,zx_eye_count
        bne   .done
        bsr     zx_audio_hw_stop
        bra   .normal_note_no_stop

.normal_short:
        ; Normal gameplay audio is hardware-timed in complete 160 ms note
        ; slots.  Do not stop DMA on the seven silent 20 ms substeps: if the
        ; renderer misses a VBlank, Paula still reaches the next audible beat
        ; at the original ZX cadence instead of stretching the music.
.normal_note_no_stop:
        tst.b   zx_music_phase
        bne   .done
        moveq   #0,d1
        move.b  zx_note_index,d1
        lsl.w   #2,d1
        lea     zx_note_ptrs,a1
        move.l  (a1,d1.w),a0
        bsr     zx_audio_play_note_a0
        bra     .done
.play:
        bsr     zx_audio_play_a0
.done:
        movem.l (sp)+,d0-d2/a0-a1
        rts

; -----------------------------------------------------------------------------
; TITLE — existing logo/text plus exact source wall cycles and right aircon.
; -----------------------------------------------------------------------------
v7_title_tick_counter:
        dc.b 0
        even

v7_render_title:
        bsr     v7_render_title_scene
        bsr     v7_draw_title_logo_overlay
        bsr     v78_draw_main_menu
        rts

; Four-item title menu.  The item text keeps the ZX-style palette colors; a
; white chevron marks the current choice without recoloring the words.
v78_draw_main_menu:
        move.b  #MENU_START_COLOR,cur_color
        lea     menu_start_bitmap,a0
        move.w  #144,d0
        move.w  #112,d1
        move.w  #MENU_START_BPR,d2
        move.w  #7,d3
        bsr     draw_bitmap_color

        move.b  #MENU_OPTIONS_COLOR,cur_color
        lea     menu_options_bitmap,a0
        move.w  #136,d0
        move.w  #128,d1
        move.w  #MENU_OPTIONS_BPR,d2
        move.w  #7,d3
        bsr     draw_bitmap_color

        move.b  #MENU_HISCORE_COLOR,cur_color
        lea     menu_hi_score_bitmap,a0
        move.w  #136,d0
        move.w  #144,d1
        move.w  #MENU_HI_SCORE_BPR,d2
        move.w  #7,d3
        bsr     draw_bitmap_color

        move.b  #MENU_CREDITS_COLOR,cur_color
        lea     menu_credits_bitmap,a0
        move.w  #136,d0
        move.w  #160,d1
        move.w  #MENU_CREDITS_BPR,d2
        move.w  #7,d3
        bsr     draw_bitmap_color

        move.b  #MENU_EXIT_COLOR,cur_color
        lea     menu_exit_bitmap,a0
        move.w  #148,d0
        move.w  #176,d1
        move.w  #MENU_EXIT_BPR,d2
        move.w  #7,d3
        bsr     draw_bitmap_color

        moveq   #0,d1
        move.b  title_menu_item,d1
        lsl.w   #4,d1
        add.w   #112,d1
        move.b  #COL_WHITE,cur_color
        lea     menu_marker_bitmap,a0
        move.w  #120,d0
        move.w  #MENU_MARKER_BPR,d2
        move.w  #7,d3
        bsr     draw_bitmap_color
        rts

v78_render_options:
        bsr     v7_render_title_scene
        bsr     v7_draw_title_logo_overlay

        ; Header.
        move.b  #MENU_OPTIONS_COLOR,cur_color
        lea     menu_options_bitmap,a0
        move.w  #136,d0
        move.w  #104,d1
        move.w  #MENU_OPTIONS_BPR,d2
        move.w  #7,d3
        bsr     draw_bitmap_color

        move.b  #COL_CYAN,cur_color
        lea     menu_control_bitmap,a0
        move.w  #100,d0
        move.w  #124,d1
        move.w  #MENU_CONTROL_BPR,d2
        move.w  #7,d3
        bsr     draw_bitmap_color

        ; CONTROL value.
        moveq   #0,d4
        move.b  control_mode,d4
        lea     menu_auto_bitmap,a0
        move.w  #MENU_AUTO_BPR,d2
        cmp.b   #CONTROL_JOYSTICK,d4
        bne.s   .not_joy
        lea     menu_joystick_bitmap,a0
        move.w  #MENU_JOYSTICK_BPR,d2
        bra.s   .draw_control_value
.not_joy:
        cmp.b   #CONTROL_MOUSE,d4
        bne.s   .not_mouse
        lea     menu_mouse_bitmap,a0
        move.w  #MENU_MOUSE_BPR,d2
        bra.s   .draw_control_value
.not_mouse:
        cmp.b   #CONTROL_CURSOR,d4
        bne.s   .draw_control_value
        lea     menu_cursor_bitmap,a0
        move.w  #MENU_CURSOR_BPR,d2
.draw_control_value:
        move.b  #COL_WHITE,cur_color
        move.w  #202,d0
        move.w  #124,d1
        move.w  #7,d3
        bsr     draw_bitmap_color

        move.b  #COL_GREEN,cur_color
        lea     menu_digi_sounds_bitmap,a0
        move.w  #100,d0
        move.w  #140,d1
        move.w  #MENU_DIGI_SOUNDS_BPR,d2
        move.w  #7,d3
        bsr     draw_bitmap_color
        tst.b   digi_sounds_enabled
        beq.s   .digi_off
        lea     menu_on_bitmap,a0
        move.w  #MENU_ON_BPR,d2
        bra.s   .digi_value
.digi_off:
        lea     menu_off_bitmap,a0
        move.w  #MENU_OFF_BPR,d2
.digi_value:
        move.b  #COL_WHITE,cur_color
        move.w  #218,d0
        move.w  #140,d1
        move.w  #7,d3
        bsr     draw_bitmap_color

        move.b  #COL_MAGENTA,cur_color
        lea     menu_soundfx_bitmap,a0
        move.w  #100,d0
        move.w  #156,d1
        move.w  #MENU_SOUNDFX_BPR,d2
        move.w  #7,d3
        bsr     draw_bitmap_color
        tst.b   soundfx_enabled
        beq.s   .sfx_off
        lea     menu_on_bitmap,a0
        move.w  #MENU_ON_BPR,d2
        bra.s   .sfx_value
.sfx_off:
        lea     menu_off_bitmap,a0
        move.w  #MENU_OFF_BPR,d2
.sfx_value:
        move.b  #COL_WHITE,cur_color
        move.w  #218,d0
        move.w  #156,d1
        move.w  #7,d3
        bsr     draw_bitmap_color

        move.b  #COL_YELLOW,cur_color
        lea     menu_back_bitmap,a0
        move.w  #100,d0
        move.w  #172,d1
        move.w  #MENU_BACK_BPR,d2
        move.w  #7,d3
        bsr     draw_bitmap_color

        moveq   #0,d1
        move.b  options_menu_item,d1
        lsl.w   #4,d1
        add.w   #124,d1
        move.b  #COL_WHITE,cur_color
        lea     menu_marker_bitmap,a0
        move.w  #84,d0
        move.w  #MENU_MARKER_BPR,d2
        move.w  #7,d3
        bsr     draw_bitmap_color
        rts

v78_render_credits:
        bsr     v7_render_title_scene
        bsr     v7_draw_title_logo_overlay

        move.b  #COL_YELLOW,cur_color
        lea     menu_credits_bitmap,a0
        move.w  #(160-(MENU_CREDITS_W/2)),d0
        move.w  #104,d1
        move.w  #MENU_CREDITS_BPR,d2
        move.w  #7,d3
        bsr     draw_bitmap_color

        move.b  #COL_WHITE,cur_color
        lea     menu_cr_nohzdyve_bitmap,a0
        move.w  #(160-(MENU_CR_NOHZDYVE_W/2)),d0
        move.w  #119,d1
        move.w  #MENU_CR_NOHZDYVE_BPR,d2
        move.w  #7,d3
        bsr     draw_bitmap_color

        move.b  #COL_CYAN,cur_color
        lea     menu_cr_tuckersoft_game_bitmap,a0
        move.w  #(160-(MENU_CR_TUCKERSOFT_GAME_W/2)),d0
        move.w  #134,d1
        move.w  #MENU_CR_TUCKERSOFT_GAME_BPR,d2
        move.w  #7,d3
        bsr     draw_bitmap_color

        move.b  #COL_WHITE,cur_color
        lea     menu_cr_programmed_by_bitmap,a0
        move.w  #(160-(MENU_CR_PROGRAMMED_BY_W/2)),d0
        move.w  #149,d1
        move.w  #MENU_CR_PROGRAMMED_BY_BPR,d2
        move.w  #7,d3
        bsr     draw_bitmap_color

        move.b  #COL_GREEN,cur_color
        lea     menu_cr_colin_ritman_bitmap,a0
        move.w  #(160-(MENU_CR_COLIN_RITMAN_W/2)),d0
        move.w  #164,d1
        move.w  #MENU_CR_COLIN_RITMAN_BPR,d2
        move.w  #7,d3
        bsr     draw_bitmap_color

        move.b  #COL_WHITE,cur_color
        lea     menu_cr_additional_code_bitmap,a0
        move.w  #(160-(MENU_CR_ADDITIONAL_CODE_W/2)),d0
        move.w  #179,d1
        move.w  #MENU_CR_ADDITIONAL_CODE_BPR,d2
        move.w  #7,d3
        bsr     draw_bitmap_color

        move.b  #COL_GREEN,cur_color
        lea     menu_cr_stefan_butler_bitmap,a0
        move.w  #(160-(MENU_CR_STEFAN_BUTLER_W/2)),d0
        move.w  #194,d1
        move.w  #MENU_CR_STEFAN_BUTLER_BPR,d2
        move.w  #7,d3
        bsr     draw_bitmap_color

        move.b  #COL_YELLOW,cur_color
        lea     menu_cr_copyright_bitmap,a0
        move.w  #(160-(MENU_CR_COPYRIGHT_W/2)),d0
        move.w  #209,d1
        move.w  #MENU_CR_COPYRIGHT_BPR,d2
        move.w  #7,d3
        bsr     draw_bitmap_color

        move.b  #COL_WHITE,cur_color
        lea     menu_cr_port_bitmap,a0
        move.w  #(160-(MENU_CR_PORT_W/2)),d0
        move.w  #224,d1
        move.w  #MENU_CR_PORT_BPR,d2
        move.w  #7,d3
        bsr     draw_bitmap_color

        move.b  #COL_MAGENTA,cur_color
        lea     menu_cr_wintermute_bitmap,a0
        move.w  #(160-(MENU_CR_WINTERMUTE_W/2)),d0
        move.w  #239,d1
        move.w  #MENU_CR_WINTERMUTE_BPR,d2
        move.w  #7,d3
        bsr     draw_bitmap_color
        rts

v78_render_hiscore:
        bsr     v7_render_title_scene
        bsr     v7_draw_title_logo_overlay
        move.b  #COL_MAGENTA,cur_color
        lea     menu_session_hi_score_bitmap,a0
        move.w  #112,d0
        move.w  #122,d1
        move.w  #MENU_SESSION_HI_SCORE_BPR,d2
        move.w  #7,d3
        bsr     draw_bitmap_color

        ; Three fixed hall-of-fame entries, always present and never
        ; overwritten by play. Same letter/digit glyphs and x-columns as
        ; the player's own entry below, just in a different color so the
        ; two groups read as distinct. Values are stored /10 like
        ; high_score, since draw_u16_5digits_xy multiplies by 10 to get
        ; the displayed score.
        moveq   #9,d0                  ; J
        move.w  #110,d1
        move.w  #136,d2
        move.b  #COL_CYAN,cur_color
        bsr     draw_letter_at_xy
        moveq   #0,d0                  ; A
        move.w  #122,d1
        move.w  #136,d2
        move.b  #COL_CYAN,cur_color
        bsr     draw_letter_at_xy
        moveq   #13,d0                 ; N
        move.w  #134,d1
        move.w  #136,d2
        move.b  #COL_CYAN,cur_color
        bsr     draw_letter_at_xy
        move.w  #20,d0                 ; JAN 200
        mulu    #10,d0
        move.w  #156,d1
        move.w  #136,d2
        move.b  #COL_CYAN,cur_color
        bsr     draw_u16_5digits_xy

        moveq   #18,d0                 ; S
        move.w  #110,d1
        move.w  #148,d2
        move.b  #COL_CYAN,cur_color
        bsr     draw_letter_at_xy
        moveq   #19,d0                 ; T
        move.w  #122,d1
        move.w  #148,d2
        move.b  #COL_CYAN,cur_color
        bsr     draw_letter_at_xy
        moveq   #4,d0                  ; E
        move.w  #134,d1
        move.w  #148,d2
        move.b  #COL_CYAN,cur_color
        bsr     draw_letter_at_xy
        move.w  #15,d0                 ; STE 150
        mulu    #10,d0
        move.w  #156,d1
        move.w  #148,d2
        move.b  #COL_CYAN,cur_color
        bsr     draw_u16_5digits_xy

        moveq   #2,d0                  ; C
        move.w  #110,d1
        move.w  #160,d2
        move.b  #COL_CYAN,cur_color
        bsr     draw_letter_at_xy
        moveq   #14,d0                 ; O
        move.w  #122,d1
        move.w  #160,d2
        move.b  #COL_CYAN,cur_color
        bsr     draw_letter_at_xy
        moveq   #11,d0                 ; L
        move.w  #134,d1
        move.w  #160,d2
        move.b  #COL_CYAN,cur_color
        bsr     draw_letter_at_xy
        move.w  #10,d0                 ; COL 100
        mulu    #10,d0
        move.w  #156,d1
        move.w  #160,d2
        move.b  #COL_CYAN,cur_color
        bsr     draw_u16_5digits_xy

        ; Player's own session high score, same column layout, one row
        ; further down so it reads as a fourth, distinctly-colored entry.
        moveq   #0,d0
        move.b  hiscore_name,d0
        move.w  #110,d1
        move.w  #176,d2
        move.b  #COL_YELLOW,cur_color
        bsr     draw_letter_at_xy
        moveq   #0,d0
        move.b  hiscore_name+1,d0
        move.w  #122,d1
        move.w  #176,d2
        move.b  #COL_YELLOW,cur_color
        bsr     draw_letter_at_xy
        moveq   #0,d0
        move.b  hiscore_name+2,d0
        move.w  #134,d1
        move.w  #176,d2
        move.b  #COL_YELLOW,cur_color
        bsr     draw_letter_at_xy

        move.w  high_score,d0
        mulu    #10,d0
        move.w  #156,d1
        move.w  #176,d2
        move.b  #COL_GREEN,cur_color
        bsr     draw_u16_5digits_xy

        move.b  #COL_WHITE,cur_color
        lea     menu_fire_to_return_bitmap,a0
        move.w  #116,d0
        move.w  #192,d1
        move.w  #MENU_FIRE_TO_RETURN_BPR,d2
        move.w  #7,d3
        bsr     draw_bitmap_color
        rts

; Initials entry screen.  Renders over the just-died game scene (same
; background as GAME OVER) rather than the title shaft, since this happens
; before GAME OVER is shown, not from the title menu.
v78_render_hiscore_entry:
        bsr     v7_render_game

        move.b  #COL_MAGENTA,cur_color
        lea     menu_new_high_score_bitmap,a0
        move.w  #(160-(MENU_NEW_HIGH_SCORE_W/2)),d0
        move.w  #96,d1
        move.w  #MENU_NEW_HIGH_SCORE_BPR,d2
        move.w  #7,d3
        bsr     draw_bitmap_color

        move.w  high_score,d0
        mulu    #10,d0
        move.w  #136,d1
        move.w  #116,d2
        move.b  #COL_GREEN,cur_color
        bsr     draw_u16_5digits_xy

        ; Three letters, 12px apart; the one currently being edited is
        ; yellow, the other two white, so no separate cursor graphic is
        ; needed.
        moveq   #0,d0
        move.b  hiscore_name,d0
        move.w  #136,d1
        move.w  #140,d2
        move.b  #COL_WHITE,cur_color
        tst.b   hiscore_entry_pos
        bne.s   .l0col
        move.b  #COL_YELLOW,cur_color
.l0col: bsr     draw_letter_at_xy

        moveq   #0,d0
        move.b  hiscore_name+1,d0
        move.w  #148,d1
        move.w  #140,d2
        move.b  #COL_WHITE,cur_color
        cmp.b   #1,hiscore_entry_pos
        bne.s   .l1col
        move.b  #COL_YELLOW,cur_color
.l1col: bsr     draw_letter_at_xy

        moveq   #0,d0
        move.b  hiscore_name+2,d0
        move.w  #160,d1
        move.w  #140,d2
        move.b  #COL_WHITE,cur_color
        cmp.b   #2,hiscore_entry_pos
        bne.s   .l2col
        move.b  #COL_YELLOW,cur_color
.l2col: bsr     draw_letter_at_xy
        rts

v78_render_exit:
        bsr     v7_render_title_scene
        bsr     v7_draw_title_logo_overlay
        move.b  #COL_WHITE,cur_color
        lea     menu_are_you_sure_bitmap,a0
        move.w  #120,d0
        move.w  #124,d1
        move.w  #MENU_ARE_YOU_SURE_BPR,d2
        move.w  #7,d3
        bsr     draw_bitmap_color

        move.b  #COL_GREEN,cur_color
        lea     menu_yes_bitmap,a0
        move.w  #148,d0
        move.w  #146,d1
        move.w  #MENU_YES_BPR,d2
        move.w  #7,d3
        bsr     draw_bitmap_color
        move.b  #COL_YELLOW,cur_color
        lea     menu_no_bitmap,a0
        move.w  #152,d0
        move.w  #162,d1
        move.w  #MENU_NO_BPR,d2
        move.w  #7,d3
        bsr     draw_bitmap_color

        moveq   #0,d1
        move.b  exit_menu_item,d1
        lsl.w   #4,d1
        add.w   #146,d1
        move.b  #COL_WHITE,cur_color
        lea     menu_marker_bitmap,a0
        move.w  #132,d0
        move.w  #MENU_MARKER_BPR,d2
        move.w  #7,d3
        bsr     draw_bitmap_color
        rts

; During the start transition the controls/prompt are gone immediately, but
; the logo itself scrolls upward together with the same shaft scene until it
; physically leaves the top edge.
v7_render_title_exit:
        bsr     v7_render_title_scene
        bsr     v7_draw_title_logo_overlay
        rts

v7_render_title_scene:
        bsr     clear_backbuffer
        ; Same wall cycle used by gameplay.
        bsr     v7_draw_walls
        ; Title has only the lower-right aircon from the initial game scene.
        ; Animate the blades without moving the scenery itself.  Driven by a
        ; counter that increments once per call (i.e. once per rendered
        ; frame on title/options/credits/hiscore/exit) rather than CIA-A TOD:
        ; TOD requires reading the high byte to clear its internal latch, and
        ; since nothing here ever does, another part of the OS reading TOD
        ; (e.g. a timer request) can leave it latched/frozen from this code's
        ; point of view, which froze the fan on every screen that shares this
        ; routine.
        addq.b  #1,v7_title_fan_ctr
        moveq   #0,d4
        move.b  v7_title_fan_ctr,d4
        lsr.b   #2,d4
        and.b   #1,d4
        move.b  d4,fan_frame
        bsr     v7_draw_aircon
        rts

; Exact colored overlay crops taken from the supplied original title reference.
; Keeping them as transparent (zero=black) bitplane crops lets the real game
; background remain underneath instead of copying a separate title screen.
v7_draw_title_logo_overlay:
        ; Crisp native pixel composition: 200x67, assembled directly from
        ; the original unscaled title component bitmaps.  No resampling.
        ; TUCKERSOFT is deliberately NOT baked into these planes anymore;
        ; it is drawn separately below as a guaranteed solid palette-blue
        ; 1-bpp band, matching the earlier title appearance.
        lea     v7_title_logo_native_p0,a0
        move.l  backbuf0,a1
        bsr     v7_draw_title_logo_plane
        lea     v7_title_logo_native_p1,a0
        move.l  backbuf1,a1
        bsr     v7_draw_title_logo_plane
        lea     v7_title_logo_native_p2,a0
        move.l  backbuf2,a1
        bsr     v7_draw_title_logo_plane
        ; The native planes contain the magenta arrow tip but no TUCKERSOFT
        ; pixels.  Draw the original solid-blue title text from a dedicated
        ; 1-bpp mask so no other logo plane can contaminate its color.
        bsr     v7_draw_title_tuckersoft_solid
        rts

; Draw one native 200x67 title-logo plane at v7_title_logo_y.
; Static title: no extra clip, preserving the approved position.
; Title-exit: clip against y=32, exactly the top edge of the wall strips,
; so the logo disappears behind the wall boundary and never travels into
; the area above it.  a0=source plane, a1=destination plane.
v7_draw_title_logo_plane:
        movem.l d0-d7/a0-a2,-(sp)
        move.w  #60,d0                 ; 200 px wide, centered in title shaft
        move.w  v7_title_logo_y,d1
        move.w  #67,d3

        moveq   #0,d6                  ; static title clip edge = screen top
        tst.b   v7_intro_active
        beq.s   .clip
        move.w  #28,d6                 ; v7.8b opening: clip at the logo's start row
.clip:
        cmp.w   d6,d1
        bge.s   .draw
        move.w  d6,d4
        sub.w   d1,d4                  ; number of hidden source rows
        cmp.w   #67,d4
        bge.s   .done
        move.w  d4,d5
        mulu    #25,d5                 ; 200 px = 25 source bytes/row
        adda.l  d5,a0
        sub.w   d4,d3
        move.w  d6,d1
.draw:
        move.w  #25,d2
        bsr     draw_bitmap_or
.done:
        movem.l (sp)+,d0-d7/a0-a2
        rts

; OBSOLETE compatibility helper (not called by v7.5b).  The corrected 200x9
; title band is baked directly into the native logo planes so the magenta arrow tip
; cannot be recolored blue.
; Draw the 200x9 TUCKERSOFT band in a guaranteed single color.  The baked
; native planes contain no pixels in rows 58..66, so this cannot acquire
; magenta/cyan/etc. through multi-plane OR composition.  It follows the logo
; vertically and uses the same wall-edge clipping during TITLE_EXIT.
v7_draw_title_tuckersoft_solid:
        movem.l d0-d7/a0-a2,-(sp)
        lea     title_tuckersoft_solid_exact,a0
        move.w  #72,d0                 ; exact original text crop, 112 px wide
        move.w  v7_title_logo_y,d1
        add.w   #58,d1                 ; follows the logo vertically
        move.w  #10,d3

        ; During TITLE_EXIT clip at the same y=32 wall-top boundary as logo.
        moveq   #0,d6
        tst.b   v7_intro_active
        beq.s   .ts_clip
        move.w  #28,d6
.ts_clip:
        cmp.w   d6,d1
        bge.s   .ts_draw
        move.w  d6,d4
        sub.w   d1,d4
        cmp.w   #10,d4
        bge.s   .ts_done
        move.w  d4,d5
        mulu    #14,d5                 ; 112 px = 14 source bytes/row
        adda.l  d5,a0
        sub.w   d4,d3
        move.w  d6,d1
.ts_draw:
        move.b  #COL_BLUE,cur_color
        move.w  #14,d2
        bsr     draw_bitmap_color
.ts_done:
        movem.l (sp)+,d0-d7/a0-a2
        rts


; Clear a byte-aligned rectangle in all three back-buffer planes.
; d0=x, d1=y, d2=width(px), d3=height(px).
v7_clear_rect_all_fast:
        movem.l d0-d7/a0-a1,-(sp)
        move.w  d0,d5
        lsr.w   #3,d5
        move.w  d2,d4
        addq.w  #7,d4
        lsr.w   #3,d4
        subq.w  #1,d4

        move.l  backbuf0,a0
        bsr     .plane
        move.l  backbuf1,a0
        bsr     .plane
        move.l  backbuf2,a0
        bsr     .plane
        movem.l (sp)+,d0-d7/a0-a1
        rts
.plane:
        movem.l d1-d5/a0-a1,-(sp)
        move.w  d1,d7
        mulu    #ROWBYTES,d7
        add.w   d5,d7
        adda.w  d7,a0
        move.w  d3,d2
        subq.w  #1,d2
.row:
        move.l  a0,a1
        move.w  d4,d1
.byte:
        clr.b   (a1)+
        dbra    d1,.byte
        lea     ROWBYTES(a0),a0
        dbra    d2,.row
        movem.l (sp)+,d1-d5/a0-a1
        rts

; a0 = 10,240-byte source plane, a1 = destination plane.
; 320x256 / 8 = 10,240 bytes = 2,560 longwords.
v7_copy_full_plane:
        move.w  #2559,d0
.copy:
        move.l  (a0)+,(a1)+
        dbra    d0,.copy
        rts

; -----------------------------------------------------------------------------
; GAME RENDERER
; -----------------------------------------------------------------------------
v7_render_game:
        bsr     clear_backbuffer
        bsr     v7_draw_walls
        ; v7.8b: the title logo scrolls away inside the live game scene.
        tst.b   v7_intro_active
        beq.s   .no_logo
        bsr     v7_intro_update_logo
        beq.s   .no_logo
        bsr     v7_draw_title_logo_overlay
.no_logo:
        ; When a clothesline is present, complete only the large yellow cap
        ; edge that it is physically mounted to, then draw the rope/garments.
        bsr     v7_draw_clothes_anchors
        bsr     v7_draw_clothes
        bsr     v7_draw_window
        bsr     v7_draw_aircon
        bsr     v7_draw_vase
        bsr     v7_draw_teeth
        bsr     v7_draw_eye
        bsr     v7_draw_player
        bsr     draw_hud
        rts

; Draw cyclic 24x200 wall strips with exact source artwork.
v7_draw_walls:
        ; left side, three planes
        lea     v7_wall_left_p0,a0
        move.l  backbuf0,a1
        move.w  #32,d0
        bsr     v7_draw_wall_plane
        lea     v7_wall_left_p1,a0
        move.l  backbuf1,a1
        move.w  #32,d0
        bsr     v7_draw_wall_plane
        lea     v7_wall_left_p2,a0
        move.l  backbuf2,a1
        move.w  #32,d0
        bsr     v7_draw_wall_plane
        ; right
        lea     v7_wall_right_p0,a0
        move.l  backbuf0,a1
        move.w  #VIEW_X+232,d0
        bsr     v7_draw_wall_plane
        lea     v7_wall_right_p1,a0
        move.l  backbuf1,a1
        move.w  #VIEW_X+232,d0
        bsr     v7_draw_wall_plane
        lea     v7_wall_right_p2,a0
        move.l  backbuf2,a1
        move.w  #VIEW_X+232,d0
        bsr     v7_draw_wall_plane
        rts

; a0=600-byte 24x200 plane source, a1=dest plane, d0=x.
v7_draw_wall_plane:
        movem.l d0-d7/a0-a3,-(sp)
        move.l  a1,a2                   ; preserve destination plane base
        move.l  a0,a3                   ; preserve wall source base
                                         ; draw_bitmap_or advances BOTH a0 and
                                         ; a1.  The previous v7.3 code restored
                                         ; only a1, then tried to recover a0 by
                                         ; subtracting phase*3.  But after the
                                         ; first draw a0 is already at the END
                                         ; of the 600-byte wall plane, so that
                                         ; made the wrap copy the last P rows a
                                         ; second time instead of rows 0..P-1.
                                         ; Result: the yellow top cap vanished
                                         ; at the top rather than wrapping back
                                         ; in at the bottom.
        move.w  world_scroll,d6         ; 0..192, multiple of 8
        move.w  d6,d7
        mulu    #3,d7
        adda.w  d7,a0
        move.w  #32,d1
        move.w  #3,d2
        move.w  #200,d3
        sub.w   d6,d3
        bsr     draw_bitmap_or
        tst.w   d6
        beq   .done
        ; wrap top part to bottom
        move.w  world_scroll,d3
        move.w  #232,d1
        sub.w   d3,d1                   ; y=232-phase? wait: first part height 200-phase, starts y32
        ; correct wrap y = 32 + (200-phase) = 232-phase
        ; wrap must restart at source row 0, not at the tail of the source.
        move.l  a3,a0                   ; exact wall source base
        move.l  a2,a1                   ; exact destination plane base
        bsr     draw_bitmap_or
.done:
        movem.l (sp)+,d0-d7/a0-a3
        rts

v7_draw_window:
        cmp.b   #STATE_ENTER,game_state
        bne     .done
        moveq   #0,d6
        move.b  v7_entry_phase,d6
        moveq   #1,d7                  ; default open frame1 during jump
        tst.b   d6
        bne   .not0
        moveq   #0,d7
        bra   .sel
.not0:  cmp.b   #1,d6
        beq   .sel
        cmp.b   #3,d6
        bne   .not3
        moveq   #0,d7
        bra   .sel
.not3:  cmp.b   #4,d6
        bne   .sel
        moveq   #2,d7
.sel:
        move.w  v7_window_y,d1
        bmi     .done
        cmp.w   #168,d1
        bgt     .done
        add.w   #VIEW_Y,d1
        move.w  #48,d0
        move.w  #3,d2
        move.w  #24,d3
        ; three precolored planes
        lea     v7_window0_p0,a0
        cmp.w   #1,d7
        bne   .w0p0c2
        lea     v7_window1_p0,a0
        bra   .w0p0
.w0p0c2:cmp.w   #2,d7
        bne   .w0p0
        lea     v7_window2_p0,a0
.w0p0:  move.l  backbuf0,a1
        bsr     draw_bitmap_or
        ; plane1
        lea     v7_window0_p1,a0
        cmp.w   #1,d7
        bne   .w1c2
        lea     v7_window1_p1,a0
        bra   .w1
.w1c2:  cmp.w   #2,d7
        bne   .w1
        lea     v7_window2_p1,a0
.w1:    move.l  backbuf1,a1
        bsr     draw_bitmap_or
        ; plane2
        lea     v7_window0_p2,a0
        cmp.w   #1,d7
        bne   .w2c2
        lea     v7_window1_p2,a0
        bra   .w2
.w2c2:  cmp.w   #2,d7
        bne   .w2
        lea     v7_window2_p2,a0
.w2:    move.l  backbuf2,a1
        bsr     draw_bitmap_or
.done:  rts

v7_draw_aircon:
        move.w  fan_y,d1
        bmi     .done
        cmp.w   #200,d1
        bge     .done
        ; Clip at the 200-row wall bottom.  At y=192 only the first 8 rows are
        ; visible, then 16 at y=184, then the full 24px sprite at y=176.
        move.w  #200,d4
        sub.w   d1,d4
        move.w  #24,d5
        cmp.w   #24,d4
        bge     .height_ok
        move.w  d4,d5
.height_ok:
        add.w   #VIEW_Y,d1
        move.w  #48,d0
        tst.b   fan_side
        beq     .xok
        move.w  #VIEW_X+216,d0
.xok:
        bsr     v7_draw_aircon_planes
.done:  rts

v7_draw_aircon_planes:
        ; d0=x,d1=y,d5=visible height (1..24); choose side/frame per plane.
        movem.l d0-d7/a0-a1,-(sp)
        move.w  d0,d6
        move.w  d1,d7
        lea     v7_aircon_left_0_p0,a0
        tst.b   fan_side
        beq     .ac0side
        lea     v7_aircon_right_0_p0,a0
.ac0side:
        tst.b   fan_frame
        beq     .ac0sel
        tst.b   fan_side
        bne     .ac0r1
        lea     v7_aircon_left_1_p0,a0
        bra     .ac0sel
.ac0r1: lea     v7_aircon_right_1_p0,a0
.ac0sel:move.l  backbuf0,a1
        move.w  d6,d0
        move.w  d7,d1
        move.w  #3,d2
        move.w  d5,d3
        bsr     draw_bitmap_or
        ; plane1
        lea     v7_aircon_left_0_p1,a0
        tst.b   fan_side
        beq     .ac1side
        lea     v7_aircon_right_0_p1,a0
.ac1side:
        tst.b   fan_frame
        beq     .ac1sel
        tst.b   fan_side
        bne     .ac1r1
        lea     v7_aircon_left_1_p1,a0
        bra     .ac1sel
.ac1r1: lea     v7_aircon_right_1_p1,a0
.ac1sel:move.l  backbuf1,a1
        move.w  d6,d0
        move.w  d7,d1
        move.w  #3,d2
        move.w  d5,d3
        bsr     draw_bitmap_or
        ; plane2
        lea     v7_aircon_left_0_p2,a0
        tst.b   fan_side
        beq     .ac2side
        lea     v7_aircon_right_0_p2,a0
.ac2side:
        tst.b   fan_frame
        beq     .ac2sel
        tst.b   fan_side
        bne     .ac2r1
        lea     v7_aircon_left_1_p2,a0
        bra     .ac2sel
.ac2r1: lea     v7_aircon_right_1_p2,a0
.ac2sel:move.l  backbuf2,a1
        move.w  d6,d0
        move.w  d7,d1
        move.w  #3,d2
        move.w  d5,d3
        bsr     draw_bitmap_or
        movem.l (sp)+,d0-d7/a0-a1
        rts

v7_draw_vase:
        tst.b   v7_vase_active
        beq     .done
        move.w  sideobj_y,d1
        bmi     .done
        cmp.w   #200,d1
        bge     .done
        move.w  #200,d5
        sub.w   d1,d5
        move.w  #24,d6
        cmp.w   #24,d5
        bge     .height_ok
        move.w  d5,d6
.height_ok:
        add.w   #VIEW_Y,d1
        move.w  #56,d0
        tst.b   sideobj_side
        beq     .pos
        move.w  #VIEW_X+224,d0
.pos:
        movem.l d0-d1,-(sp)
        lea     v7_vase_left_p0,a0
        tst.b   sideobj_side
        beq     .vp0
        lea     v7_vase_right_p0,a0
.vp0:   move.l  backbuf0,a1
        move.w  #1,d2
        move.w  d6,d3
        bsr     draw_bitmap_or
        movem.l (sp)+,d0-d1
        movem.l d0-d1,-(sp)
        lea     v7_vase_left_p1,a0
        tst.b   sideobj_side
        beq     .vp1
        lea     v7_vase_right_p1,a0
.vp1:   move.l  backbuf1,a1
        move.w  #1,d2
        move.w  d6,d3
        bsr     draw_bitmap_or
        movem.l (sp)+,d0-d1
        lea     v7_vase_left_p2,a0
        tst.b   sideobj_side
        beq     .vp2
        lea     v7_vase_right_p2,a0
.vp2:   move.l  backbuf2,a1
        move.w  #1,d2
        move.w  d6,d3
        bsr     draw_bitmap_or
.done:  rts

; Complete the inner edge of the LARGE yellow wall cap only while a
; clothesline is present.  The exact 24px wall crop stops three pixels short
; of the shaft on this cap; these 3px extensions reproduce the full pillar
; and make the rope meet yellow on both sides.  No anchors are ever drawn on
; ordinary brick or on the small side tabs.
v7_draw_clothes_anchors:
        tst.b   v7_clothes_visible
        beq.s   .done
        move.w  v7_clothes_y,d1
        bmi.s   .done
        cmp.w   #200,d1
        bge.s   .done
        add.w   #VIEW_Y-2,d1            ; cap rows 0..4 around rope centre row 2
        move.b  #COL_YELLOW,cur_color
        move.w  #53,d0                  ; extend left cap x=32..52 to rope x=56
        move.w  #3,d2
        move.w  #5,d3
        bsr     fill_rect
        move.w  #264,d0                 ; extend right cap x=267..287 back to rope
        move.w  #3,d2
        move.w  #5,d3
        bsr     fill_rect
.done:
        rts

v7_draw_clothes:
        tst.b   v7_clothes_visible
        beq     .done
        move.w  v7_clothes_y,d1
        bmi     .done
        cmp.w   #200,d1
        bge     .done
        ; Bottom clipping: y=192 draws 8 rows, y=184 draws 16, y=176 draws
        ; 24, and y<=168 draws the complete 32px clothes bitmap.
        move.w  #200,d5
        sub.w   d1,d5
        move.w  #32,d6
        cmp.w   #32,d5
        bge     .height_ok
        move.w  d5,d6
.height_ok:
        add.w   #VIEW_Y,d1
        move.w  #56,d0
        movem.l d0-d1,-(sp)
        lea     v7_clothes0_p0,a0
        tst.b   v7_clothes_layout
        beq     .cp0
        lea     v7_clothes1_p0,a0
.cp0:   move.l  backbuf0,a1
        move.w  #26,d2
        move.w  d6,d3
        bsr     draw_bitmap_or
        movem.l (sp)+,d0-d1
        movem.l d0-d1,-(sp)
        lea     v7_clothes0_p1,a0
        tst.b   v7_clothes_layout
        beq     .cp1
        lea     v7_clothes1_p1,a0
.cp1:   move.l  backbuf1,a1
        move.w  #26,d2
        move.w  d6,d3
        bsr     draw_bitmap_or
        movem.l (sp)+,d0-d1
        lea     v7_clothes0_p2,a0
        tst.b   v7_clothes_layout
        beq     .cp2
        lea     v7_clothes1_p2,a0
.cp2:   move.l  backbuf2,a1
        move.w  #26,d2
        move.w  d6,d3
        bsr     draw_bitmap_or
.done:  rts

v7_draw_teeth:
        move.w  teeth_y,d1
        bmi   .done
        cmp.w   #168,d1
        bgt   .done                 ; keep entire 32px sprite inside world
        move.b  teeth_color,cur_color
        lea     v7_teeth_closed,a0
        btst    #1,teeth_frame
        beq   .img
        lea     v7_teeth_open,a0
.img:   move.w  teeth_x,d0
        add.w   #32,d0
        add.w   #32,d1
        move.w  #4,d2
        move.w  #32,d3
        bsr     draw_bitmap_color
.done:  rts

v7_draw_eye:
        tst.b   v7_eye_dead
        beq   .normal
        moveq   #0,d6
        move.b  v7_eye_exp_frame,d6
        bsr     v7_draw_explosion_eye
        rts
.normal:
        move.w  eye_y,d1
        bmi   .done
        cmp.w   #160,d1
        bgt   .done
        move.b  eye_color,cur_color
        lea     v7_eye_la,a0
        tst.b   v7_eye_dir
        beq   .left
        lea     v7_eye_ra,a0
        btst    #1,eye_frame
        beq   .sel
        lea     v7_eye_rb,a0
        bra   .sel
.left:  btst    #1,eye_frame
        beq   .sel
        lea     v7_eye_lb,a0
.sel:   move.w  eye_x,d0
        add.w   #32,d0
        add.w   #32,d1
        move.w  #2,d2
        move.w  #32,d3
        bsr     draw_bitmap_color
.done:  rts

v7_draw_player:
        cmp.b   #STATE_DEAD,game_state
        beq   .done
        cmp.b   #STATE_GAMEOVER,game_state
        beq   .done
        move.b  #COL_WHITE,cur_color
        cmp.b   #STATE_ENTER,game_state
        bne   .fall
        cmp.b   #2,v7_entry_phase
        blt   .done
        cmp.b   #5,v7_entry_phase
        bge   .done
        lea     v7_player_entry,a0
        move.w  #2,d2
        move.w  #32,d3
        bra   .draw
.fall:
        lea     v7_player_fall_a,a0
        btst    #1,player_anim
        beq   .draw
        lea     v7_player_fall_b,a0
.draw:  move.w  #2,d2
        move.w  #32,d3
        move.w  player_x,d0
        add.w   #32,d0
        move.w  player_y,d1
        add.w   #32,d1
        bsr     draw_bitmap_color
        cmp.b   #STATE_ENTER,game_state
        bne   .done
        cmp.w   #64,player_x
        blt   .done
        move.b  #COL_CYAN,cur_color
        lea     v7_speed_lines,a0
        move.w  player_x,d0
        sub.w   #40,d0
        add.w   #32,d0
        move.w  player_y,d1
        add.w   #40,d1
        move.w  #4,d2
        move.w  #16,d3
        bsr     draw_bitmap_color
.done:  rts

v7_draw_explosion_player:
        move.w  death_timer,d6
        move.w  player_x,d0
        move.w  player_y,d1
        bra     v7_draw_explosion_at

v7_draw_explosion_eye:
        move.w  v7_eye_ex_x,d0
        move.w  v7_eye_ex_y,d1
        ; d6 already frame
v7_draw_explosion_at:
        cmp.w   #4,d6
        bge   .done
        move.b  #COL_WHITE,cur_color
        cmp.w   #1,d6
        bne   .f2
        move.b  #COL_YELLOW,cur_color
.f2:    cmp.w   #2,d6
        bne   .f3
        move.b  #COL_CYAN,cur_color
.f3:    cmp.w   #3,d6
        bne   .choose
        move.b  #COL_GREEN,cur_color
.choose:
        lea     v7_expl0,a0
        cmp.w   #1,d6
        bne   .e2
        lea     v7_expl1,a0
        bra   .edraw
.e2:    cmp.w   #2,d6
        bne   .e3
        lea     v7_expl2,a0
        bra   .edraw
.e3:    cmp.w   #3,d6
        bne   .edraw
        lea     v7_expl3,a0
.edraw: subq.w  #8,d0
        add.w   #32,d0
        add.w   #32,d1
        move.w  #4,d2
        move.w  #32,d3
        bsr     draw_bitmap_color
.done:  rts

; =============================================================================
; END V7 SOURCE-FIRST GAME ENGINE
; =============================================================================

; -----------------------------------------------------------------------------
; (flat section continues - was "data")

gfxname:        dc.b "graphics.library",0
        even

gfxbase:        dc.l 0
oldview:        dc.l 0
shell_mode:     dc.b 0
        even
frontbuf0:      dc.l 0
frontbuf1:      dc.l 0
frontbuf2:      dc.l 0
backbuf0:       dc.l 0
backbuf1:       dc.l 0
backbuf2:       dc.l 0

game_state:     dc.b 0
lives:          dc.b 3
player_vx:      dc.b 0
player_y_index: dc.b 0
player_anim:    dc.b 0
eye_table_index:dc.b 0
eye_hdir:       dc.b 1
eye_frame:      dc.b 0
eye_color:      dc.b COL_MAGENTA
teeth_vx:       dc.b 1
teeth_frame:    dc.b 0
teeth_color:    dc.b COL_RED
fan_side:       dc.b 0
fan_frame:      dc.b 0
sideobj_side:   dc.b 0
sideobj_frame:  dc.b 0
cur_color:      dc.b 7
        even
score:          dc.w 0
player_x:       dc.w 140
player_y:       dc.w $88
teeth_x:        dc.w 128
teeth_y:        dc.w 185
eye_x:          dc.w 64
eye_y:          dc.w 190
eye_min_column: dc.w 24
eye_max_column: dc.w 56
fan_y:          dc.w 184
sideobj_y:      dc.w 432
world_scroll:   dc.w 0
death_timer:    dc.w 0
entry_timer:    dc.w 0
collision_grace:dc.w 0
high_score:     dc.w 0
high_score_new: dc.b 0          ; set by update_highscore when score beats high_score
hiscore_name:   dc.b 0,0,0      ; three letter-indices (0=A..25=Z), session-only
hiscore_entry_pos: dc.b 0       ; which of the three letters is being edited
; FIX: high_score_new(1) + hiscore_name(3) + hiscore_entry_pos(1) = 5 bytes,
; an odd count with nothing re-aligning afterward. Without this directive
; rng_state below lands on an odd address, and v7_game_new's word write to
; it ("move.w #$1234,rng_state") is a genuine 68000 address-error exception
; on real hardware - the Guru Meditation seen on both KS1.3 and KS2.0 when
; starting a game, independent of Kickstart version. This was introduced
; along with the hi-score-initials feature.
        even
rng_state:      dc.w $1234

; V7 source-first state
v7_player_falling: dc.b 1
v7_player_maxfall: dc.b 96
v7_entry_phase:      dc.b 0
v7_title_fan_ctr:    dc.b 0
v7_title_exit_phase: dc.b 0
v7_title_needfill:   dc.b 0          ; legacy field, no longer used
v7_clothes_layout:   dc.b 0
v7_clothes_visible:  dc.b 0
v7_clothes_waitwrap: dc.b 2
v7_vase_active:      dc.b 0
v7_vase_waitwrap:    dc.b 1
v7_eye_dead:         dc.b 0
v7_eye_exp_frame:    dc.b 0
v7_eye_dir:          dc.b 0

; v7.8 menu / controller / user-audio options.  These persist for the current
; run and are deliberately not reset when a new game starts.
control_mode:          dc.b CONTROL_AUTO
active_control:        dc.b 0
last_ui_control:       dc.b 0
title_menu_item:       dc.b MENU_START
options_menu_item:     dc.b OPT_CONTROL
exit_menu_item:        dc.b 1              ; NO by default
digi_sounds_enabled:   dc.b 1
soundfx_enabled:       dc.b 1
ui_prev_dirs:          dc.b 0
ui_prev_buttons:       dc.b 0
ui_mouse_cooldown:     dc.b 0
auto_joy_dir:          dc.b 0
keyboard_available:    dc.b 0
kbd_sigbit:            dc.b $ff
kbd_io_pending:        dc.b 0
        even
mouse_prev_joy:        dc.w 0
mouse_y_accum:         dc.w 0

; Kickstart 1.3 keyboard.device state.  KBD_READMATRIX on V34 and earlier uses
; exactly thirteen bytes.  The static MsgPort/IOStdReq avoid any dependency on
; later lowlevel.library APIs and make the same binary suitable for A500/A570.
kbd_matrix:            ds.b KBD_MATRIX_LEN,0
        even
keyboard_name:         dc.b "keyboard.device",0
        even
kbd_port:              ds.b 34,0
        even
kbd_io:                ds.b 48,0
        even

; External sample-bank / auxiliary Paula state.
        even
sample_bank_ptr:       dc.l 0
sample_voice_ticks:    dc.w 0
sample_audio_enabled:  dc.b 0
sample_voice_active:   dc.b 0
sample_voice_current:    dc.b SAMPLE_VOICE_NONE
sample_voice_next:       dc.b SAMPLE_VOICE_NONE
sample_wind_wanted:      dc.b 0
sample_wind_playing:     dc.b 0
sample_attract_index:    dc.b 0
sample_attract_tod:      dc.b 0
sample_opening_stage:    dc.b SAMPLE_OPEN_NONE
sample_opening_response: dc.b 0
sample_opening_tod:      dc.b 0
        even
sample_attract_delay:    dc.w 0
sample_opening_delay:    dc.w 0
sample_silence_word:     dc.w 0

; ZX 50 Hz beeper sequencer state (mirrors B514-B5A2 semantics).
zx_audio_enabled:    dc.b 0
zx_start_count:      dc.b 0
zx_music_phase:      dc.b 0
zx_note_index:       dc.b 0
zx_eye_count:        dc.b 0
zx_death_state:      dc.b 0
zx_start_pending:    dc.b 0          ; v7.8b: start ZX music once gameplay runs
        even

; v7.8b 50 Hz time base (VERTB interrupt server) and start-of-game intro clock.
vbl_counter:         dc.l 0
audio_vbl_seen:      dc.l 0
audio_service_left:  dc.w 0
v7_intro_clock:      dc.w 0          ; PAL fields since START was selected
v7_intro_jump_t0:    dc.w 0          ; intro clock when the jump started
v7_intro_active:     dc.b 0          ; 1 = first window exit of a new game
v7_intro_voiced:     dc.b 0          ; 1 = Stefan/Colin exchange is driving it
        even
vbl_interrupt:
        dc.l    0,0                  ; ln_Succ, ln_Pred
        dc.b    NT_INTERRUPT,0       ; ln_Type, ln_Pri
        dc.l    vbl_server_name      ; ln_Name
        dc.l    vbl_counter          ; is_Data
        dc.l    vbl_server           ; is_Code
vbl_server_name:     dc.b "nohzdyve vblank",0
        even
v7_clothes_y:      dc.w 106
v7_title_logo_y:   dc.w 28
v7_window_y:       dc.w 118
v7_eye_prevx:      dc.w 0
v7_eye_ex_x:       dc.w 0
v7_eye_ex_y:       dc.w 0

eye_colors:       dc.b COL_CYAN,COL_GREEN,COL_MAGENTA,COL_YELLOW
hazard_colors:    dc.b COL_RED,COL_YELLOW,COL_CYAN,COL_MAGENTA
explosion_colors: dc.b COL_WHITE,COL_YELLOW,COL_CYAN,COL_MAGENTA
        even

        include "original_motion_tables.i"

fan_ptrs:       dc.l fan0_bitmap,fan1_bitmap,fan2_bitmap,fan3_bitmap
eye_ptrs:       dc.l eye0_bitmap,eye1_bitmap,eye2_bitmap
sideobj_ptrs:   dc.l sideobj0_bitmap,sideobj1_bitmap

; Exact ZX B5A3 32-step normal-game pointer sequence.
zx_note_ptrs:
        dc.l    zx_note_0,zx_note_0,zx_note_1,zx_note_1
        dc.l    zx_note_2,zx_note_2,zx_note_3,zx_note_3
        dc.l    zx_note_5,zx_note_5,zx_note_4,zx_note_4
        dc.l    zx_note_2,zx_note_2,zx_note_0,zx_note_0
        dc.l    zx_note_0,zx_note_0,zx_note_1,zx_note_1
        dc.l    zx_note_2,zx_note_2,zx_note_3,zx_note_3
        dc.l    zx_note_0,zx_note_0,zx_note_1,zx_note_1
        dc.l    zx_note_2,zx_note_2,zx_note_3,zx_note_3

; -----------------------------------------------------------------------------
; CHIP data: Copper, three-bitplane double-buffered framebuffers (8 colors),
; original extracted 1-bpp graphics, and the title logo split into per-color
; column-run pieces (see gfx/title_parts/, generated from gfx/title.1bpp).
; -----------------------------------------------------------------------------
; (flat section continues - was "data_c" chip)

; Two complete, independent Copper lists rather than one list whose pointer
; words get overwritten in place each frame. The hardware reloads the
; Copper's program counter from COP1LCH automatically at every vertical
; blank, on its own schedule, completely independent of CPU instruction
; timing; WaitTOF returning does not guarantee that automatic reload has or
; hasn't already happened for the frame about to display. Patching the
; SAME list's pointer words right after WaitTOF - even inside a
; Disable()/Enable() bracket, which only blocks the CPU side (interrupts),
; never the hardware DMA/Copper side - leaves a genuine hardware race
; between our CPU write and the Copper's own automatic fetch of those exact
; words. Real hardware testing confirmed this: an interrupt-proof
; (Disable/Enable-wrapped) single-list patch cut the glitch rate but did not
; eliminate it. With two lists, present_frame always writes the new
; pointers into whichever list is currently NOT the one COP1LCH points at,
; then switches COP1LCH to it - so the Copper can never be mid-fetch of the
; exact words the CPU is writing, regardless of timing.
copperlistA:
        dc.w    $0100,$3200       ; BPLCON0: 3 lowres bitplanes (8 colors)
        dc.w    $0102,$0000       ; BPLCON1
        dc.w    $0104,$0000       ; BPLCON2
        dc.w    $0108,$0000       ; BPL1MOD
        dc.w    $010a,$0000       ; BPL2MOD
        dc.w    $008e,$2c81       ; DIWSTRT
        dc.w    $0090,$2cc1       ; DIWSTOP
        dc.w    $0092,$0038       ; DDFSTRT
        dc.w    $0094,$00d0       ; DDFSTOP
cop_a_bpl1pth:
        dc.w    $00e0,$0000
cop_a_bpl1ptl:
        dc.w    $00e2,$0000
cop_a_bpl2pth:
        dc.w    $00e4,$0000
cop_a_bpl2ptl:
        dc.w    $00e6,$0000
cop_a_bpl3pth:
        dc.w    $00e8,$0000
cop_a_bpl3ptl:
        dc.w    $00ea,$0000
        ; v7.8b: every sprite points at an empty sprite, so even if the OS
        ; re-enables sprite DMA nothing stray (mouse pointer) can appear.
        dc.w    $0120,(null_sprite>>16)&$ffff,$0122,null_sprite&$ffff ; SPR0PT
        dc.w    $0124,(null_sprite>>16)&$ffff,$0126,null_sprite&$ffff ; SPR1PT
        dc.w    $0128,(null_sprite>>16)&$ffff,$012a,null_sprite&$ffff ; SPR2PT
        dc.w    $012c,(null_sprite>>16)&$ffff,$012e,null_sprite&$ffff ; SPR3PT
        dc.w    $0130,(null_sprite>>16)&$ffff,$0132,null_sprite&$ffff ; SPR4PT
        dc.w    $0134,(null_sprite>>16)&$ffff,$0136,null_sprite&$ffff ; SPR5PT
        dc.w    $0138,(null_sprite>>16)&$ffff,$013a,null_sprite&$ffff ; SPR6PT
        dc.w    $013c,(null_sprite>>16)&$ffff,$013e,null_sprite&$ffff ; SPR7PT
        dc.w    $0180,$0000       ; COLOR0 black
        dc.w    $0182,$000f       ; COLOR1 blue
        dc.w    $0184,$0f00       ; COLOR2 red
        dc.w    $0186,$0f0f       ; COLOR3 magenta
        dc.w    $0188,$00f0       ; COLOR4 green
        dc.w    $018a,$00ff       ; COLOR5 cyan
        dc.w    $018c,$0ff0       ; COLOR6 yellow
        dc.w    $018e,$0fff       ; COLOR7 white
        dc.w    $ffff,$fffe

copperlistB:
        dc.w    $0100,$3200       ; BPLCON0: 3 lowres bitplanes (8 colors)
        dc.w    $0102,$0000       ; BPLCON1
        dc.w    $0104,$0000       ; BPLCON2
        dc.w    $0108,$0000       ; BPL1MOD
        dc.w    $010a,$0000       ; BPL2MOD
        dc.w    $008e,$2c81       ; DIWSTRT
        dc.w    $0090,$2cc1       ; DIWSTOP
        dc.w    $0092,$0038       ; DDFSTRT
        dc.w    $0094,$00d0       ; DDFSTOP
cop_b_bpl1pth:
        dc.w    $00e0,$0000
cop_b_bpl1ptl:
        dc.w    $00e2,$0000
cop_b_bpl2pth:
        dc.w    $00e4,$0000
cop_b_bpl2ptl:
        dc.w    $00e6,$0000
cop_b_bpl3pth:
        dc.w    $00e8,$0000
cop_b_bpl3ptl:
        dc.w    $00ea,$0000
        ; v7.8b: every sprite points at an empty sprite, so even if the OS
        ; re-enables sprite DMA nothing stray (mouse pointer) can appear.
        dc.w    $0120,(null_sprite>>16)&$ffff,$0122,null_sprite&$ffff ; SPR0PT
        dc.w    $0124,(null_sprite>>16)&$ffff,$0126,null_sprite&$ffff ; SPR1PT
        dc.w    $0128,(null_sprite>>16)&$ffff,$012a,null_sprite&$ffff ; SPR2PT
        dc.w    $012c,(null_sprite>>16)&$ffff,$012e,null_sprite&$ffff ; SPR3PT
        dc.w    $0130,(null_sprite>>16)&$ffff,$0132,null_sprite&$ffff ; SPR4PT
        dc.w    $0134,(null_sprite>>16)&$ffff,$0136,null_sprite&$ffff ; SPR5PT
        dc.w    $0138,(null_sprite>>16)&$ffff,$013a,null_sprite&$ffff ; SPR6PT
        dc.w    $013c,(null_sprite>>16)&$ffff,$013e,null_sprite&$ffff ; SPR7PT
        dc.w    $0180,$0000       ; COLOR0 black
        dc.w    $0182,$000f       ; COLOR1 blue
        dc.w    $0184,$0f00       ; COLOR2 red
        dc.w    $0186,$0f0f       ; COLOR3 magenta
        dc.w    $0188,$00f0       ; COLOR4 green
        dc.w    $018a,$00ff       ; COLOR5 cyan
        dc.w    $018c,$0ff0       ; COLOR6 yellow
        dc.w    $018e,$0fff       ; COLOR7 white
        dc.w    $ffff,$fffe

        even
; v7.8b: present_frame only rewrites COP1LCL, so both lists must share the
; same high address word.
        ifne    (copperlistA>>16)-(copperlistB>>16)
        fail    "copperlistA/copperlistB straddle a 64 KiB boundary"
        endc
null_sprite:    dc.l 0              ; empty sprite (control words = 0)
; 0 = copperlistA is the one COP1LCH currently points at (live/being
; scanned), 1 = copperlistB is. present_frame always prepares the OTHER one.
copper_active:  dc.b 0
        even
bitplaneA0:     ds.b PLANESIZE,0
bitplaneA1:     ds.b PLANESIZE,0
bitplaneA2:     ds.b PLANESIZE,0
bitplaneB0:     ds.b PLANESIZE,0
bitplaneB1:     ds.b PLANESIZE,0
bitplaneB2:     ds.b PLANESIZE,0

title_tuckersoft_solid_exact: incbin "gfx/title_parts/tuckersoft_solid_exact.1bpp"
player_fall0_bitmap:    incbin "gfx/player_fall_0.1bpp"
player_fall1_bitmap:    incbin "gfx/player_fall_1.1bpp"
player_jump_bitmap:     incbin "gfx/player_jump.1bpp"
eye0_bitmap:            incbin "gfx/eye_0.1bpp"
eye1_bitmap:            incbin "gfx/eye_1.1bpp"
eye2_bitmap:            incbin "gfx/eye_2.1bpp"
teeth0_bitmap:          incbin "gfx/teeth_0.1bpp"
teeth1_bitmap:          incbin "gfx/teeth_1.1bpp"
fan0_bitmap:            incbin "gfx/side_fan_0.1bpp"
fan1_bitmap:            incbin "gfx/side_fan_1.1bpp"
fan2_bitmap:            incbin "gfx/side_fan_2.1bpp"
fan3_bitmap:            incbin "gfx/side_fan_3.1bpp"
sideobj0_bitmap:        incbin "gfx/side_obj_0.1bpp"
sideobj1_bitmap:        incbin "gfx/side_obj_1.1bpp"
wall_brick_bitmap:      incbin "gfx/wall_brick_24x192.1bpp"
score_label_bitmap:     incbin "gfx/score_label.1bpp"
lives_label_bitmap:     incbin "gfx/lives_label.1bpp"
hiscore_label_bitmap:   incbin "gfx/hiscore_label.1bpp"
heart_bitmap:            incbin "gfx/heart.1bpp"
game_over_bitmap:       incbin "gfx/game_over.1bpp"
v7_game_over_spaced:    incbin "gfx/game_over_spaced.1bpp"
        even                    ; 68000: following title planes are copied with MOVE.L
digits_bitmap:          incbin "gfx/digits.1bpp"

        even
menu_start_bitmap:            incbin "gfx/menu/start.1bpp"
menu_options_bitmap:          incbin "gfx/menu/options.1bpp"
menu_hi_score_bitmap:         incbin "gfx/menu/hi_score.1bpp"
menu_exit_bitmap:             incbin "gfx/menu/exit.1bpp"
menu_control_bitmap:          incbin "gfx/menu/control.1bpp"
menu_auto_bitmap:             incbin "gfx/menu/auto.1bpp"
menu_joystick_bitmap:         incbin "gfx/menu/joystick.1bpp"
menu_mouse_bitmap:            incbin "gfx/menu/mouse.1bpp"
menu_cursor_bitmap:           incbin "gfx/menu/cursor.1bpp"
menu_digi_sounds_bitmap:      incbin "gfx/menu/digi_sounds.1bpp"
menu_soundfx_bitmap:          incbin "gfx/menu/soundfx.1bpp"
menu_on_bitmap:               incbin "gfx/menu/on.1bpp"
menu_off_bitmap:              incbin "gfx/menu/off.1bpp"
menu_back_bitmap:             incbin "gfx/menu/back.1bpp"
menu_session_hi_score_bitmap: incbin "gfx/menu/session_hi_score.1bpp"
menu_fire_to_return_bitmap:   incbin "gfx/menu/fire_to_return.1bpp"
menu_are_you_sure_bitmap:     incbin "gfx/menu/are_you_sure.1bpp"
menu_yes_bitmap:              incbin "gfx/menu/yes.1bpp"
menu_no_bitmap:               incbin "gfx/menu/no.1bpp"
menu_marker_bitmap:           incbin "gfx/menu/marker.1bpp"
menu_credits_bitmap:          incbin "gfx/menu/credits.1bpp"
menu_cr_nohzdyve_bitmap:        incbin "gfx/menu/cr_nohzdyve.1bpp"
menu_cr_tuckersoft_game_bitmap: incbin "gfx/menu/cr_tuckersoft_game.1bpp"
menu_cr_programmed_by_bitmap:   incbin "gfx/menu/cr_programmed_by.1bpp"
menu_cr_colin_ritman_bitmap:    incbin "gfx/menu/cr_colin_ritman.1bpp"
menu_cr_additional_code_bitmap: incbin "gfx/menu/cr_additional_code.1bpp"
menu_cr_stefan_butler_bitmap:   incbin "gfx/menu/cr_stefan_butler.1bpp"
menu_cr_copyright_bitmap:       incbin "gfx/menu/cr_copyright.1bpp"
menu_cr_port_bitmap:            incbin "gfx/menu/cr_port.1bpp"
menu_cr_wintermute_bitmap:      incbin "gfx/menu/cr_wintermute.1bpp"
menu_new_high_score_bitmap:     incbin "gfx/menu/new_high_score.1bpp"
letters_bitmap:                 incbin "gfx/menu/letters.1bpp"


; -----------------------------------------------------------------------------
; Exact title OVERLAYS cropped from the supplied original reference.  The
; background itself is rendered by the game scene, so there is no second title
; wall/fan image and therefore no fan duplication or start-screen jump.
; -----------------------------------------------------------------------------
; Native 200x67 title overlay used by v7.3i.  It is assembled from the
; original component bitmaps without any image scaling.
v7_title_logo_native_p0: incbin "gfx/title_overlay/logo_native_p0.bin"
v7_title_logo_native_p1: incbin "gfx/title_overlay/logo_native_p1.bin"
v7_title_logo_native_p2: incbin "gfx/title_overlay/logo_native_p2.bin"

; -----------------------------------------------------------------------------
; Original ZX Spectrum 1-bit audio rendered for Paula.
; Short buffers are 20 ms source slots plus 20 ms silent guards.  Eye/death
; are complete DMA-timed sweeps so graphics overruns cannot stretch them.
; -----------------------------------------------------------------------------
        even
zx_title_start_sample: incbin "gfx/zx_audio/title_start.raw"
zx_intro_hi_sample:    incbin "gfx/zx_audio/intro_hi.raw"
zx_intro_lo_sample:    incbin "gfx/zx_audio/intro_lo.raw"
zx_note_0:             incbin "gfx/zx_audio/note_0.raw"
zx_note_1:             incbin "gfx/zx_audio/note_1.raw"
zx_note_2:             incbin "gfx/zx_audio/note_2.raw"
zx_note_3:             incbin "gfx/zx_audio/note_3.raw"
zx_note_4:             incbin "gfx/zx_audio/note_4.raw"
zx_note_5:             incbin "gfx/zx_audio/note_5.raw"
zx_eye_full:           incbin "gfx/zx_audio/eye_full.raw"
zx_death_full:         incbin "gfx/zx_audio/death_full.raw"
        even

; -----------------------------------------------------------------------------
; V7 exact source-derived assets
; -----------------------------------------------------------------------------
v7_player_entry:       incbin "gfx/exact/player_entry.1bpp"
v7_player_fall_a:      incbin "gfx/exact/player_fall_a.1bpp"
v7_player_fall_b:      incbin "gfx/exact/player_fall_b.1bpp"
v7_speed_lines:        incbin "gfx/exact/speed.1bpp"
v7_teeth_closed:       incbin "gfx/exact/teeth_closed.1bpp"
v7_teeth_open:         incbin "gfx/exact/teeth_open.1bpp"
v7_eye_la:             incbin "gfx/exact/eye_la.1bpp"
v7_eye_lb:             incbin "gfx/exact/eye_lb.1bpp"
v7_eye_ra:             incbin "gfx/exact/eye_ra.1bpp"
v7_eye_rb:             incbin "gfx/exact/eye_rb.1bpp"
v7_expl0:              incbin "gfx/exact/expl0.1bpp"
v7_expl1:              incbin "gfx/exact/expl1.1bpp"
v7_expl2:              incbin "gfx/exact/expl2.1bpp"
v7_expl3:              incbin "gfx/exact/expl3.1bpp"

v7_window0_p0:         incbin "gfx/exact/window0_p0.bin"
v7_window0_p1:         incbin "gfx/exact/window0_p1.bin"
v7_window0_p2:         incbin "gfx/exact/window0_p2.bin"
v7_window1_p0:         incbin "gfx/exact/window1_p0.bin"
v7_window1_p1:         incbin "gfx/exact/window1_p1.bin"
v7_window1_p2:         incbin "gfx/exact/window1_p2.bin"
v7_window2_p0:         incbin "gfx/exact/window2_p0.bin"
v7_window2_p1:         incbin "gfx/exact/window2_p1.bin"
v7_window2_p2:         incbin "gfx/exact/window2_p2.bin"

v7_aircon_left_0_p0:   incbin "gfx/exact/aircon_left_0_p0.bin"
v7_aircon_left_0_p1:   incbin "gfx/exact/aircon_left_0_p1.bin"
v7_aircon_left_0_p2:   incbin "gfx/exact/aircon_left_0_p2.bin"
v7_aircon_left_1_p0:   incbin "gfx/exact/aircon_left_1_p0.bin"
v7_aircon_left_1_p1:   incbin "gfx/exact/aircon_left_1_p1.bin"
v7_aircon_left_1_p2:   incbin "gfx/exact/aircon_left_1_p2.bin"
v7_aircon_right_0_p0:  incbin "gfx/exact/aircon_right_0_p0.bin"
v7_aircon_right_0_p1:  incbin "gfx/exact/aircon_right_0_p1.bin"
v7_aircon_right_0_p2:  incbin "gfx/exact/aircon_right_0_p2.bin"
v7_aircon_right_1_p0:  incbin "gfx/exact/aircon_right_1_p0.bin"
v7_aircon_right_1_p1:  incbin "gfx/exact/aircon_right_1_p1.bin"
v7_aircon_right_1_p2:  incbin "gfx/exact/aircon_right_1_p2.bin"

v7_vase_left_p0:       incbin "gfx/exact/vase_left_p0.bin"
v7_vase_left_p1:       incbin "gfx/exact/vase_left_p1.bin"
v7_vase_left_p2:       incbin "gfx/exact/vase_left_p2.bin"
v7_vase_right_p0:      incbin "gfx/exact/vase_right_p0.bin"
v7_vase_right_p1:      incbin "gfx/exact/vase_right_p1.bin"
v7_vase_right_p2:      incbin "gfx/exact/vase_right_p2.bin"

v7_clothes0_p0:        incbin "gfx/exact/clothes0_p0.bin"
v7_clothes0_p1:        incbin "gfx/exact/clothes0_p1.bin"
v7_clothes0_p2:        incbin "gfx/exact/clothes0_p2.bin"
v7_clothes1_p0:        incbin "gfx/exact/clothes1_p0.bin"
v7_clothes1_p1:        incbin "gfx/exact/clothes1_p1.bin"
v7_clothes1_p2:        incbin "gfx/exact/clothes1_p2.bin"

v7_wall_left_p0:       incbin "gfx/exact/wall_left_p0.bin"
v7_wall_left_p1:       incbin "gfx/exact/wall_left_p1.bin"
v7_wall_left_p2:       incbin "gfx/exact/wall_left_p2.bin"
v7_wall_right_p0:      incbin "gfx/exact/wall_right_p0.bin"
v7_wall_right_p1:      incbin "gfx/exact/wall_right_p1.bin"
v7_wall_right_p2:      incbin "gfx/exact/wall_right_p2.bin"
