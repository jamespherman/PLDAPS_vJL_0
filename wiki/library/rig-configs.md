---
title: Rig config files
type: library
category: Library
summary: What a +rigConfigFiles function sets in p.rig, which file is which rig/era, and how tasks pick one (hostname → rigConfig_rigN)
sources:
  - +rigConfigFiles/ @ c77a7f756b
  - +pds/initRigConfigFile.m @ f32e98b29d
  - tasks/gSac_4factors/gSac_4factors_settings.m @ 132bc9eff2
  - tasks/human_psychophysical_threshold/human_psychophysical_threshold_settings_hue3.m @ e15c5be812
verified_at: e48934be
updated: 2026-10-15
---

# Rig config files

A rig config is a function `p = <name>(p)` in `+rigConfigFiles/`. It holds the
details specific to one rig (and, in older files, one subject): screen geometry,
joystick voltages, reward calibration and DataPixx memory layout.

## How a task picks and loads one

1. **Settings** (`_settings.m`) stores the full path in `p.init.rigConfigFile`. The
   current convention, used since commit 23c0509a (2023-05-17), picks the file from
   the PC's host name:

   ```matlab
   [~, p.init.pcName] = unix('hostname');
   p.init.rigConfigFile = which(['rigConfigFiles.rigConfig_rig' p.init.pcName(end-1)]);
   ```

   `pcName(end-1)` is the last character of the host name, since `hostname` output
   ends in a newline. A host such as `pldaps1` therefore loads
   `rigConfig_rig1`. The same character also selects per-rig color LUT files (see
   [color and calibration](../concepts/color-and-calibration.md)). The settings
   files of these tasks use this convention:
   - barsweep, conflict_task, fixate, gSac_4factors, gSac_contrast, gSac_jph;
   - joystick_press_and_fixate, all joystick_release_* tasks, joystickPress,
     joystickPress_playMovie;
   - numerosity, reward_calibration, rfMap, sacc_to_phosph, seansFirstTask,
     SRS_Task_Smooth, tokens.

   barsweep asserts that the lookup found a file.

   The same commit and 9b069254 also moved `p.init.useDataPixxBool` into
   settings. The rig config is not run until `_init`, but the settings stage already
   needs to know whether to use the DataPixx. `rigConfig_rig1/2` copy it into
   `p.rig.dp.useDataPixxBool`.
2. **Init** (`_init.m`) calls `pds.initRigConfigFile(p)`. That function:
   - errors if `p.init.rigConfigFile` is empty;
   - `eval`s `rigConfigFiles.<file name>(p)`;
   - if the config defines `p.rig.baseReward`, copies it into
     `p.trVarsInit.rewardDurationMs` and `p.trVars.rewardDurationMs` (see
     [reward](../concepts/reward.md)).

Other ways settings files pick a config:

- **human_psychophysical_threshold.** Some settings variants use
  `rigConfig_human`. Others switch on the host name, using
  `rigConfig_human_Mercy` for `mayolab-thinkpad-p16s-gen-2` and `rigConfig_human`
  otherwise.
- **Older tasks name a fixed file.** nfl's `scd_settings_*` use
  `rigConfig_rigB_20190324`. The scd task's `scd_settings_satInc` uses
  `rigConfig_ramsey_rigF_20190517`. `gSac_settings` uses `rigB_2019016_porter`.

## Fields a config sets (as in `rigConfig_rig1`)

| Group | Fields |
|---|---|
| Geometry | `viewdist` (mm), `screenhpix`, `screenh` (mm), `deg2PixConstant`. `pds.deg2pix` and `pds.pix2deg` use the first three. |
| Screen | `screen_name`, `screen_number`, `refreshRate`, `frameDuration`, `magicNumber` (flip-timing allowance). `refreshRate` and `frameDuration` are overwritten at init by `pds.measureRefresh`. |
| Reward | `baseReward` (ms) |
| Joystick | `joyVoltageMin/Rest/Max`; `joyThresh.rangeFractPress` (4/5) and `rangeFractRels` (1/10); the derived `joyThresh.highVoltPress`, `highVoltRelease`, `lowVoltPress`, `lowVoltRelease` |
| DataPixx (`p.rig.dp`) | `useDataPixxBool`, `adcRate` (1000 Hz), `maxDurADC` (15 s), `adcBuffAddr` (4e6), `dacRate` (1000 Hz), `dacPadDur` (0.01 s), `dacBuffAddr` (10e6), `dacChannelOut` (0) |
| Omniplex | `connectToOmniplex` (false); if true, calls `pds.openPortToServer` |

How these fields are used is covered in [eye and joystick](../concepts/eye-and-joystick.md)
(joystick thresholds), [DataPixx and timing](../concepts/datapixx-and-timing.md)
(`p.rig.dp`, refresh) and [ephys integration](../concepts/ephys-integration.md)
(Omniplex).

## Files

| File | Rig / era | Notable differences from `rigConfig_rig1` | Last changed |
|---|---|---|---|
| `rigConfig_rig1.m` | Current rig 1 (host ending in 1) | 120 Hz predicted, `magicNumber` 0.008, `baseReward` 189, joystick 0.9 / 2.79 / 4.61 V | 2026-05-12 |
| `rigConfig_rig2.m` | Current rig 2 | 100 Hz predicted, `baseReward` 200, `joyVoltageMin` 0.854 | 2023-05-17 |
| `rigConfig_human.m` | Human psychophysics (BENQ monitor) | `viewdist` 610 mm, `screenh` 300 mm, `useDataPixxBool = false`, no `baseReward` | 2024-08-12 |
| `rigConfig_human_Mercy.m` | Human psychophysics laptop setup | Like `rigConfig_human` but `viewdist` 540 mm | 2024-08-13 |
| `rigConfig_rigB_20190324.m` | Rig B, 2019 | 100 Hz, hard-coded joystick thresholds (4 / 2.5 / 0.7 / 2 V) | initial import |
| `rigConfig_rigF_20190328.m` | Rig F, 2019 | 100 Hz, `magicNumber` 0, `connectPLX` flag | initial import |
| `rigConfig_ramsey_rigF_20190517.m` | Rig F, subject "ramsey", 2019 | 100 Hz, joystick 0.5 / 2.5 / 4.5 V | initial import |
| `rigConfig_rigF_20180717.m` | Rig F, 2018 (28 lines) | Geometry plus `omniplexIP`; no joystick or DataPixx block | initial import |
| `rigB_20190527.m` | Rig B, 2019 | Adds `latencyStrobeToScreen` and `latencyScreenTopToBottom` (8 ms each) | initial import |
| `rigB_20190316_porter.m`, `rigB_2019016_porter.m` | Rig B, subject "porter", 2019 | Hard-coded joystick thresholds; the function inside is named `rigB_20190116_porter` | initial import |
| `rigA_20200203.m` | Rig A, 2020 | Same content as `rigConfig_rigF_20190328`, including the function name | initial import |

"Initial import" means the file has not changed since the repository's first
commits (2022-08-04). Only `rigConfig_rig1`, `rigConfig_rig2` and the two human
configs are loaded by current settings files through the conventions above. The
dated files are loaded only by the older settings files listed earlier.

## Related

- [p struct](../concepts/p-struct.md) (`p.rig`), [+pds catalog](pds-functions.md), [GUI](gui.md)
