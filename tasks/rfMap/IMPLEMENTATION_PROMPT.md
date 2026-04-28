# rfMap Task Implementation Prompt

Use the following prompt to start a fresh Claude Code instance for implementation:

---

I need you to implement a new PLDAPS task called `rfMap` -- a dense-noise receptive field mapping task for macaque LGN electrophysiology. A detailed implementation plan has already been written and agreed upon. Please read the following files before doing anything:

1. `tasks/rfMap/IMPLEMENTATION_PLAN.md` -- the complete design document. This is the authoritative specification. Follow it closely.

2. `CLAUDE.md` -- project-wide conventions (quintet pattern, strobe codes, postFlip timing, etc.).

3. Reference PLDAPS task for the quintet pattern and stimulus generation in `_next.m`:
   - `tasks/joystick_release_for_stim_change_and_dim/joystick_release_for_stim_change_and_dim_settings.m`
   - `tasks/joystick_release_for_stim_change_and_dim/joystick_release_for_stim_change_and_dim_init.m`
   - `tasks/joystick_release_for_stim_change_and_dim/joystick_release_for_stim_change_and_dim_next.m`
   - `tasks/joystick_release_for_stim_change_and_dim/joystick_release_for_stim_change_and_dim_run.m`
   - `tasks/joystick_release_for_stim_change_and_dim/joystick_release_for_stim_change_and_dim_finish.m`

4. Reference for passive fixation state machine:
   - `tasks/fixate/fixate_run.m`
   - `tasks/fixate/fixate_settings.m`

5. Existing Ripple/xippmex integration:
   - `+pds/getRippleData.m`
   - `+pds/initRipple.m`

6. Feng LGN reference code (for noise generation patterns, NOT for PLDAPS structure):
   - `/home/herman_lab/Downloads/feng_LGN/generateDenseNoiseMovie.m`
   - `/home/herman_lab/Downloads/feng_LGN/stim_densenoise_color.m`
   - `/home/herman_lab/Downloads/feng_LGN/run_DenseNoise.m`

Follow the implementation order specified in Section 8 of the plan. Start with **Phase 1** (simulation and STA validation -- no hardware needed):

1. `supportFunctions/buildGroundTruthRF.m`
2. `supportFunctions/generateNoiseMovie.m`
3. `supportFunctions/updateSTA.m`
4. `supportFunctions/testSTA.m`
5. `supportFunctions/initSTADisplay.m`
6. `supportFunctions/plotSTA.m`

After completing Phase 1, pause and show me the results of running `testSTA` so we can verify the STA recovery before proceeding to Phase 2 (the PLDAPS task files).

Do not add strobe codes to `+pds/initCodes.m` until Phase 2. Do not create any files outside the `tasks/rfMap/` directory until Phase 2.
