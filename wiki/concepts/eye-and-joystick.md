---
title: Eye and joystick input
type: concept
category: Concepts
summary: How eye position and joystick voltage are read (DataPixx ADC or EyeLink), converted, and tested against windows and thresholds
sources:
  - +pds/getEyeJoy.m @ c1d49fb59f
  - +pds/getMouse.m @ 89f399e626
  - +pds/getEyelink.m @ 196bb05631
  - +pds/initEyelink.m @ d74671240b
  - +pds/eyeInWindow.m @ 7fe8e2ccb5
  - +pds/eyeInWindowEL.m @ 11ee430099
  - +pds/eyelinkInWindow.m @ 5fdeba7cc3
  - +pds/checkEye.m @ 9d33a5ed96
  - +pds/checkJoy.m @ 4fb381dde9
  - +pds/joyHeld.m @ 02109bb580
  - +pds/joyHeld_version1.m @ 82a2f07d34
  - +pds/joyReld.m @ 95a35cd20d
  - +pds/joyRectFillCalc.m @ 350b543cdb
  - +pds/waitForJoystickRelease.m @ 7740aa1360
  - +rigConfigFiles/rigConfig_rig1.m @ 95baf18b31
  - tasks/gSac_4factors/gSac_4factors_run.m @ 9aa849922b
verified_at: e48934be
updated: 2026-10-15
---

# Eye and joystick input

## Reading inputs each loop iteration

`pds.getEyeJoy(p)` runs at the top of every `_run.m` while-loop iteration. It
calls `Datapixx('RegWrRd')` and `Datapixx('GetAdcVoltages')`, then sets:

| Field | Source | Conversion |
|---|---|---|
| `p.trVars.eyeDegX`, `eyeDegY` | ADC ch 0, 1 | `4 * V` (fixed gain of 4 deg/V) |
| `p.trVars.eyePixX`, `eyePixY` | ADC ch 0, 1 | `pds.deg2pix(4*|V|)` with the sign kept. Y is negated because screen pixels count downward. |
| `p.trVars.joyVolt` | ADC ch 3 | raw volts |

The 4 deg/V gain is fixed in `getEyeJoy`. The rig configs hold no eye-calibration
fields. ADC channel 2 (pupil) is not read here. It is captured only in the buffered
trace `p.trData.eyeP` by `pds.readDatapixxBuffers` (see
[DataPixx and timing](datapixx-and-timing.md)). The same 4 deg/V factor is applied
offline to `p.trData.eyeX/eyeY` (for example, in `calcSacParams` in
`gSac_4factors_finish.m`).

**Mouse simulation.** `pds.getMouse(p)` stores the PTB cursor position in
`p.trVars.mouseCursorX/Y`. Tasks with a `mouseEyeSim` trVar (barsweep,
conflict_task, gSac, gSac_4factors, gSac_contrast, numerosity, sacc_to_phosph,
seansFirstTask, SRS_Task_Smooth) overwrite the eye fields with the cursor position
when it is 1. The cursor is taken relative to `p.draw.middleXY` and converted with
`pds.pix2deg`, as in `gSac_4factors_run.m`.

**EyeLink (human rig).** `tasks/human_psychophysical_threshold` uses an EyeLink
instead of ADC eye signals:

- `pds.initEyelink(p)` connects (`EyelinkInit(p.init.elDummyMode)`) and asks for an
  EDF file name of up to 8 characters. It sets up the calibration display (HV9
  calibration, background taken from the experimenter CLUT) and runs
  `EyelinkDoTrackerSetup`.
- `pds.getEyelink(p)` reads the newest float sample into `p.trVars.eyePixX/Y`.

## Window checks

All window functions return true when `p.trVars.passEye` is set, which lets a
task run without an eye signal. The window types are `'fixation'` (the default),
`'target'` and `'image'`. Every test is a rectangle: `|eye − center| < width` and
`|eye − center| < height`, so the width and height fields act as half-sizes.

| Function | Compares | Window fields | Used by |
|---|---|---|---|
| `pds.eyeInWindow(p, which, [targRow])` | `eyeDegX/Y` vs `fixDegX/Y` or `targDegX/Y(targRow)` | `fixWinWidthDeg`, `targWinWidthDeg`, `imageWinWidthDeg` (and Height) | most monkey tasks |
| `pds.eyeInWindowEL(p, which)` | `eyePixX/Y` vs `fixPixX/Y`, `targPixX/Y` | `*WinWidthPix`, `*WinHeightPix` | human_psychophysical_threshold |
| `pds.eyelinkInWindow(p, which)` | `eyePixX/Y` vs `*PixX/Y` | `*WinWidthDeg`, `*WinHeightDeg` | no current caller |
| `pds.checkEye(pass, Eye, WinDim)` | `all(abs(Eye) < WinDim)` around zero | arguments | no current caller |

The optional `targRow` argument of `eyeInWindow` selects a row when `targDegX/Y`
are vectors (several targets).

## Joystick

The rig config defines `p.rig.joyVoltageMin/Rest/Max` and four thresholds,
`p.rig.joyThresh.highVoltPress`, `highVoltRelease`, `lowVoltPress` and
`lowVoltRelease`. Newer configs compute the thresholds as fractions of the
rest→min and rest→max ranges (`rangeFractPress = 4/5`, `rangeFractRels = 1/10`).
Older configs hard-code them. See [rig configs](../library/rig-configs.md).

`[held, joyState] = pds.joyHeld(p)`:

- `p.trVars.joyPressVoltDir` sets the joystick's orientation. With 1 (the default
  if the field is missing), pressing lowers the voltage: the state is pressed below
  `lowVoltPress`, released above `lowVoltRelease`, and in between otherwise. With
  2, pressing raises the voltage: pressed above `highVoltPress`, released below
  `highVoltRelease`.
- `joyState` is 1 (pressed), 0 (released) or NaN (in between). Because the press
  and release thresholds differ, the gap between them gives hysteresis.
- `held` is `p.trVars.passJoy | joyState == 1`.

Older helpers are kept but not called by current tasks:

- `pds.joyHeld_version1` (single `p.rig.joyThreshPress`)
- `pds.joyReld` (uses an old flat `c` struct)
- `pds.checkJoy(pass, Joy, Th)` (`Joy > Th || pass`)

`pds.joyRectFillCalc(p)` maps `joyVolt` onto 0–1 between `joyVoltageMax` and
`joyVoltageMin` in 15 steps. It returns the filled part of `p.draw.joyRect`, which
draws the joystick bar on the experimenter display.

### Waiting for release between trials

`pds.waitForJoystickRelease(p)` is called from `_finish.m`. It loops while either
of these holds:

- the joystick is held, `passJoy` is off, and the GUI Run button
  (`Tag 'runButton'`) is still on;
- a DAC schedule is still running, meaning a reward is still being delivered.

Inside the loop it:

- re-enables ADC free-running if no ADC schedule is active, so `getEyeJoy` keeps
  updating;
- redraws the joystick indicator on each loop iteration (each iteration ends
  with a random wait of about 50 ms);
- once `p.trVars.joyReleaseWaitDur` has passed and `p.trVars.wantEndFlicker` is
  set, flashes the screen white and plays the low tone through the task's own
  `playTone`.

## Related

- [Run-loop state machine](run-loop-state-machine.md), [trial variables and GUI](trial-variables-and-gui.md) (`passEye`, `passJoy`)
- [DataPixx and timing](datapixx-and-timing.md), [rig configs](../library/rig-configs.md), [+pds catalog](../library/pds-functions.md)
- [Joystick task family](../tasks/family-joystick.md)
