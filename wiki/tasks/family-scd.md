---
title: Detection, tokens & utility tasks (scd family and miscellaneous)
type: family
category: Tasks — detection, tokens & utility
summary: scd and nfl (stimulus change detection, shared scd_* files), plus the standalone tokens, human_psychophysical_threshold and reward_calibration tasks
status: legacy
sources:
  - tasks/scd/scd_settings_satInc.m @ 5bad9a710b
  - tasks/scd/scd_run.m @ 417d5bf557
  - tasks/scd/supportFunctions/initTrialStructure.m @ bd4890598a
  - tasks/nfl/scd_run.m @ 96fd513609
  - tasks/nfl/supportFunctions/initTrialStructure.m @ f0095b599a
  - tasks/nfl/supportFunctions/updateTrialsList.m @ e51769a60c
  - tasks/tokens/tokens_settings.m @ 4184994680
  - tasks/human_psychophysical_threshold/human_psychophysical_threshold_settings_hue1.m @ c3cd8df4a8
  - tasks/human_psychophysical_threshold/supportFunctions/initTrialStructure.m @ 5abd61ac13
  - tasks/reward_calibration/reward_calibration_settings.m @ 0a1f8963d4
  - tasks/reward_calibration/supportFunctions/nextParams.m @ 4958c1698c
verified_at: e48934be
updated: 2026-10-15
---

# Detection, tokens & utility tasks

This page groups five task directories. Only two of them form a real family: **scd** and
**nfl** run the same experiment, and nfl reuses the `scd_*` file names. The other three
(**tokens**, **human_psychophysical_threshold**, **reward_calibration**) are separate tasks
filed here because they fit no other family. The only link between them is the code they
inherited: each one started as a copy of the scd task folder (see "Shared ancestry" below).

| Task | Subject | What it does | Status |
|---|---|---|---|
| [scd](scd.md) | monkey | Cued stimulus change detection: release the joystick when the cued patch changes (saturation increase) and ignore changes in the foil patch | legacy |
| [nfl](nfl.md) | monkey | The same scd task (`scd_*` files) with block-wise trial tables (saturation then contrast changes) and repeated conditions | legacy |
| [tokens](tokens.md) | monkey | Pavlovian cue → token outcome → juice, with cues that predict a normal-like or a uniform reward distribution; `tokens_AV` adds audiovisual flicker | active |
| [human_psychophysical_threshold](human_psychophysical_threshold.md) | human | 4-alternative oddity task (hue / orientation / speed / radial frequency) with QUEST threshold estimation, Eyelink and keyboard responses | active |
| [reward_calibration](reward_calibration.md) | none | Delivers `numTrials` identical reward pulses, then turns off the Run button | active |

## scd vs nfl: what differs

Both directories have the same quintet file names (`scd_init.m`, `scd_next.m`, `scd_run.m`,
`scd_finish.m`) and set `p.init.taskName = 'scd'`. Because the names collide, only one of
the two directories should be on the MATLAB path at a time.

| Aspect | `tasks/scd/` | `tasks/nfl/` |
|---|---|---|
| Settings files | `scd_settings_satInc.m` only | 9 variants (`scd_settings.m`, `_nfl`, `_nflNoSgl`, `_nflNoSgl_50`, `_nflNoSgl_shortBlocks`, `_nfl_eachChangeOnce`, `_satInc`, `_satIncNoSgl`, `_fourStimTest`) |
| Rig config | `rigConfig_ramsey_rigF_20190517` | `rigConfig_rigB_20190324` (most variants) |
| Contrast feature name | `cont` (`contDelta`, `contInit`, `p.stim.contArray`) | `generateStimuli` reads `p.stim.ctrstArray`; settings variants use either `ctrst` or `cont` |
| Strobed task code | `uniqueTaskCode_scd` plus session date/time | varies by variant: `uniqueTaskCode_nfl`, `uniqueTaskCode_scd` (`_satIncNoSgl`) or `p.init.taskType` |
| Trials-array column 15 | `'trialCode'` | `'stimcode'` |
| Block regeneration | `updateTrialsList` builds a fresh array each block, no duplication | duplicates every regenerated array (`repmat(…, 2, 1)`) |
| `passJoy` in `makeDecision` | widens the hit window | turns any trial with the joystick held into a hit |
| Online eye trace | `p.trData.onlineEyeX/Y` saved | not saved |
| Extra table | `saturation increase no single cue chg only` | `fourStimTest` (4 patches) |

Both run loops color the experimenter-only fixation window by trial type (orange contrast
change, green cued change, red foil change, black no change), except in `nfl_shortBlocks`,
where contrast trials are not marked orange.

## Shared ancestry

- **tokens**, **human_psychophysical_threshold** and **reward_calibration** all keep scd-style
  support files: `generateStimuli.m`, `updateQuest.m`, `getQuestSuggestedDelta.m`,
  `dkl2rgb.m`/`initmon.m`, and `actions/summarizeBehaviorBasic.m` with its
  `plot_hitP_foilFaP*.m` helpers. human_psychophysical_threshold uses the QUEST files;
  tokens has its own `generateStimuli` (cue-image loading) and does not call the QUEST files;
  reward_calibration's quintet calls none of them.
- `reward_calibration/supportFunctions/nextParams.m` still contains scd's `chooseRow` and
  `trialTypeInfo` subfunctions. `reward_calibration_next.m` never calls `nextParams`.
- `human_psychophysical_threshold/supportFunctions/initTrialStructure.m` uses the scd
  trials-array layout, extended to four stimulus locations. It still has the `nfl`
  branch, and its duplication list includes the nfl experiment types.
- The state names in human_psychophysical_threshold and reward_calibration (`hit`, `cr`,
  `foilFa`, …) come from scd, even though those tasks never enter most of these states.

## Related

- [Quintet and GUI loop](../concepts/quintet-and-gui-loop.md), [trial structure](../concepts/trial-structure.md),
  [color and calibration](../concepts/color-and-calibration.md) (DKL, `initmon`, LUT files),
  [reward](../concepts/reward.md), [strobe codes](../concepts/strobe-codes.md).
- Similar joystick-release detection tasks: [joystick family](family-joystick.md).
