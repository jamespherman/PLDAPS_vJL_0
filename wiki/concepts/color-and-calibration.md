---
title: Color, CLUTs and display calibration
type: concept
category: Concepts
summary: Dual subject/experimenter CLUTs in p.draw, DKL-to-RGB conversion via per-rig LUT files, and the i1Pro calibration actions that produce them
sources:
  - +pds/initDataPixx.m @ d2924f59b6
  - +pds/richColors.m @ a0d6c5f323
  - +pds/i1MexFolder.m @ 045af0dc91
  - externalTools/i1/README.md @ 75e3d57f4f
  - tasks/gSac_4factors/supportFunctions/initClut.m @ 29e48fa115
  - tasks/gSac_4factors/supportFunctions/initmon.m @ 4979df0f0c
  - tasks/gSac_4factors/actions/i1CalibrateAndMeasure.m @ 84ba1c84fb
  - tasks/gSac_4factors/actions/dklToRgbFileMaker.m @ 09f808f1d0
  - tasks/gSac_4factors/actions/i1Validate.m @ f3e1ccee94
  - tasks/SRS_Task_Smooth/srsSmooth_settings.m @ 34495a80b8
verified_at: e48934be
updated: 2026-10-15
---

# Color, CLUTs and display calibration

## Indexed color with two CLUTs

On VIEWPixx rigs, `pds.initDataPixx` turns on PsychImaging's
`EnableDataPixxL48Output` and loads `[p.draw.clut.subCLUT; p.draw.clut.expCLUT]`
with `Screen('LoadNormalizedGammaTable', ..., 2)`. Tasks then draw with CLUT
**indices** instead of RGB values. Each index has one color on the subject's
display (`subCLUT`) and possibly a different one on the experimenter's console
(`expCLUT`). This is how the console can show items the monkey cannot see:
fixation windows, the eye-position cursor, the joystick bar and grid lines.

- **Index names.** `p.draw.clutIdx` (defined in the task's settings) names each
  index by both appearances. For example, `expGrey70_subBg` is 70% grey on the
  console and background on the subject screen. `expDkl180_subDkl180` is the same
  DKL hue on both.
- **Building the CLUTs.** Each task builds them in its own
  `supportFunctions/initClut.m`, called before `pds.initDataPixx` in `_init.m`.
  gSac_4factors fills `expCLUT` explicitly, then makes `subCLUT` by copying it and
  setting every `*_subBg` entry to the background color.
- **Exception.** Movie tasks and token tasks skip the L48 mode (see
  [DataPixx and timing](datapixx-and-timing.md)).

`pds.richColors` returns a fixed 16×3 palette (RGB/255, reordered). No current
task calls it.

## DKL colors

Tasks that need colors defined in DKL space use two functions in their own
`supportFunctions/`:

- `initmon(file)`, by Thorsten Hansen, reads `<file>.xyY` (the CIE xyY of each
  phosphor) and `<file>.r/.g/.b` (256-entry gamma tables) into globals and builds
  the DKL↔RGB matrices.
- `dkl2rgb` converts a DKL color to RGB using those matrices.

gSac_4factors `initClut` selects `LUT_VPIXX_rig<N>` from the PC host name
(`p.init.pcName(end-1)`). It then computes the bullseye hues at 0°, 45°, 180° and
225° DKL (luminance −0.495, saturation 0.4) and an isoluminant grey. The LUT files
sit next to `initClut.m`. For example, gSac_4factors has `LUT_VPIXX_rig1.*`,
`LUT_VPIXX_rig2.*` and a generic `LUTvpixx.*`.

For why the conflict task uses hue contrast to create salience, see the
"Conflict Task: Salience via DKL Color Contrast" section of `CLAUDE.md`. That
section is the reference; it is not repeated here.

## i1Pro calibration workflow

The i1 tools live in each task's `actions/` folder, not in `+pdsActions`. Copies
exist in gSac_4factors, gSac_contrast, human_psychophysical_threshold and
SRS_Task_Smooth.

1. **`i1CalibrateAndMeasure(p)`** (GUI action):
   - Calibrates the i1Pro in its cradle.
   - Fills the screen with each of 256 levels per gun, measuring tristimulus
     values with `I1('GetTriStimulus')` each time.
   - Saves `colorData` (3 × 256 × 3) to
     `<outputFolder>/<sessionId>_x1Data.mat`.
2. **`dklToRgbFileMaker`** (a script with hard-coded input and output paths and a
   display name):
   - Turns `colorData` into the 256-entry inverse look-up tables.
   - Writes `LUT<display>.xyY/.r/.g/.b`, the files `initmon` reads.
3. **`i1Validate(p)`** (GUI action):
   - Measures an 11×11 grid on the DKL isoluminant plane, plus a luminance series.
   - Stores the results in `p.rig.displayCal`.

SRS_Task_Smooth also has photometry actions for its dark-red stimuli:
`i1FindGrayBackgroundLum`, `i1LivePhotometer`, `i1MeasureSrsRedLumRamp`,
`i1ScanDklRedLumAxis`, `i1ScanRedRgbDirect` and `i1ScanRedRgbDkl`.
`srsSmooth_settings.m` lists all of these except `i1ScanDklRedLumAxis` in
`p.init.taskActions` by bare name (see
[pdsActions](../library/pdsActions.md) for how bare and `pdsActions.` names are
resolved).

**The i1 MEX.** `I1.mexa64` lives in `externalTools/i1/`, outside any package,
because the actions call the bare name `I1(...)`. `pds.i1MexFolder()` returns that
folder's absolute path relative to the repo. SRS_Task_Smooth's i1 actions add it to
the path with `-begin`. The README says to keep that folder to the MEX alone,
because anything else in it would shadow repo files. An older external copy once
shadowed SRS_Task_Smooth's `initClut.m`.

## Related

- [Drawing and postFlip](drawing-and-postflip.md), [DataPixx and timing](datapixx-and-timing.md)
- [SRS family](../tasks/family-srs.md), [gSac family](../tasks/family-gsac.md)
- [+pds catalog](../library/pds-functions.md)
