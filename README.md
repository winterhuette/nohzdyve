
                         N O H Z D Y V E
                           Amiga Edition
                              v7.8b

ABOUT
-----
NOHZDYVE is an Amiga 500 / CDTV port of the ZX Spectrum game written 
by Matt Wescott and released as an Easter Egg for Bandersnatch episode of
Black Mirror.  The Amiga version keeps the original gameplay concept while 
adapting the presentation, controls and audio for classic Amiga hardware.

The current build is source-based and targets the Motorola 68000 / OCS
platform.  It has been developed with real Amiga hardware in mind rather
than emulator-only compatibility.

Copyright 2026, Jan C. Kiefer

WHAT'S NEW IN v7.8b
--------------------
v7.8b is a stability and polish pass on v7.8a, driven by testing on real
Amiga 500/A500+ hardware:

  - Fixed intermittent full-screen graphics corruption during gameplay.
    The display now uses double-buffered Copper lists (eliminating a rare
    hardware race between the Copper's automatic per-frame restart and the
    CPU's own frame updates), together with correctly-paired interrupt
    masking around the frame-presentation code.
  - Fixed the opening Stefan/Colin exchange occasionally stalling after
    pressing FIRE to start a new game, requiring a second press to
    continue. The dialogue timer no longer depends on CIA hardware timer
    state that other system activity could leave in an inconsistent state.
  - Fixed EXIT -> YES not reliably returning to a clean title screen on
    real hardware; the soft reset now re-enters Kickstart's own cold-start
    code directly.
  - Reworked the opening Stefan/Colin exchange pacing: the title logo now
    scrolls away continuously for the full exchange instead of finishing
    early and leaving the screen static, so there is no dead pause before
    the window opens.
  - Added three fixed hall-of-fame entries to the HI SCORE table (JAN 200,
    STE 150, COL 100).


QUICK START
-----------
1. Start NOHZDYVE from the title menu.
2. Choose your preferred control method under OPTIONS if required.
3. Press FIRE / the selected action key to begin.
4. Guide the falling player left and right through the shaft.
5. Avoid obstacles and survive for as long as possible.
6. Your score and high score are shown by the game.


TITLE MENU
----------
  START       Begin a game
  OPTIONS     Configure controls and sound
  HI SCORE    View the high score
  EXIT        Leave the game and return to AmigaDOS (Shell build)


CONTROLS
--------
The game supports these control modes:

  AUTO        Automatically use an available supported controller
  JOYSTICK    Joystick on controller port 2
  CURSOR      Keyboard cursor keys

Use the selected left/right controls to steer.
Use FIRE / the corresponding action control to start and confirm.

Sound options are available for digital samples and game sound effects.

NOTE: v7.8b does not use a global mouse-button quit shortcut.  To leave the
Shell build, use EXIT from the title menu.


COMPATIBILITY
-------------
Designed for:

  Commodore Amiga 500
  Commodore CDTV
  Amiga 500 + A570 CD-ROM
  Motorola 68000
  OCS chipset
  PAL display
  Kickstart 1.3
  512 KiB Chip RAM minimum target

The v7.8b input layer supports:

  - controller-port-2 joystick
  - keyboard input through keyboard.device

v7.8b includes an input compatibility fix for the keyboard.device reply-port
setup.  This prevents a stale/invalid reply-port pointer that could stall
input on Kickstart 2.x and could fault on Kickstart 1.3.

The game has also been developed and tested against real Amiga 500-class
hardware during the porting process.


DISPLAY / GAME TIMING
---------------------
  Display:          OCS lores, PAL
  Amiga screen:     320 x 256
  Original field:   256 x 192, centred in the Amiga display
  Game logic:       25 Hz
  Video timing:     PAL 50 Hz

The current renderer is CPU-based rather than blitter-based.  This is an
intentional compatibility-oriented design choice.  Frame presentation uses
double-buffered Copper lists to avoid display tearing.


CDTV / INTERACTIVE DISC USE
---------------------------
NOHZDYVE can also be launched as a hidden Easter egg from the interactive
CDTV project.  The CDTV integration uses a Kickstart-1.3-compatible AmigaDOS
launcher and preserves the normal game files:

  NOHZDYVE
  NOHZDYVE.BIN
  NOHZDYVE.SMP

The interactive-disc launcher has been verified on real CDTV/A570-class
hardware with Kickstart 1.3.


NOTES
-----
- PAL is the primary target.
- The port is intended for original 68000/OCS-class machines.
- No AGA chipset is required.
- No hard disk is required for normal use.
- For the Shell build, keep NOHZDYVE.BIN and NOHZDYVE.SMP in the same
  directory as the NOHZDYVE launcher.


CREDITS / ORIGIN
----------------
Original NOHZDYVE concept/game: associated with Black Mirror: Bandersnatch
and released for the ZX Spectrum.

Amiga port: independent Amiga adaptation for classic 68000 / OCS hardware.

This port is a fan/technical preservation project and is not an official
Netflix or Black Mirror release.

===============================================================================

Screenshots

<img width="605" height="495" alt="start" src="https://github.com/user-attachments/assets/a1f04c69-bad7-43ac-95d6-0f3067f131b3" />

<img width="606" height="489" alt="options" src="https://github.com/user-attachments/assets/219cf299-bb6d-49e6-8601-e48bb52723cd" />

<img width="610" height="493" alt="InGame" src="https://github.com/user-attachments/assets/559553f3-d5a5-46db-b026-1fe162d56d95" />

<img width="606" height="490" alt="hiscore" src="https://github.com/user-attachments/assets/1056d901-22e4-43a6-9e11-1cd32977ceb9" />



