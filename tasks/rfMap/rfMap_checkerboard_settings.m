function p = rfMap_checkerboard_settings
%   p = rfMap_checkerboard_settings
%
% Settings file for rfMap contrast-reversing checkerboard mode.
%
% PHASE 1 STATUS: STUB. The dispatcher recognizes this stim type, but
% the texture pre-render, polarity-reversal scheduling, and online
% F1/F2 estimator are not implemented yet. Phase 3 of
% rfMap_unified_merge_plan.md adds:
%   - prepareStim_checkerboard.m (texture pair  x  N conditions)
%   - per-flip polarity reversal in _run.m
%   - reversal-rate validator (must divide refresh rate evenly;
%     F2 must be below Nyquist)
%   - updateSTA_checkerboard.m: temporal kernel + F1/F2 amplitudes
%   - plotSTA_checkerboard.m: kernel traces + F1/F2 bars
%
% Loading this settings file in Phase 1 succeeds up to the point where
% _init.m attempts to dispatch the checkerboard preparer; that call
% errors with a clear "Phase 3 not yet implemented" message.
%
% Note: checkerboard does NOT produce an online spatial RF. It is a
% cell-characterization mode (magno/parvo typing, contrast response)
% sharing the rfMap architecture (passive fixation, pre-rendered
% textures, Ripple ingestion, online plot window).

%% pin stim type FIRST
p = struct;
p.init.stimType = 'checkerboard';

%% common configuration
p = rfMap_commonSettings(p);

%% Phase-3 placeholder fields (documented for the data dictionary)
p.trVarsInit.checkSizesDva    = [0.5 1.0 2.0]; % spatial-scale knob (NOT SF)
p.trVarsInit.checkContrasts   = [0.25 0.5 1.0];
p.trVarsInit.checkReversalHz  = 5;             % must divide refresh rate evenly,
                                               % and 2*reversalHz must be below
                                               % Nyquist (frame_rate/2).
p.trVarsInit.checkApertureMode = 'fullField';

%% strobe additions specific to checkerboard mode (Phase 3 will populate
%% these per-trial; reserved here for schema continuity).
p.init.strobeList = [p.init.strobeList; { ...
    'rfMapCheckSizeIdx',         '1'; ...                                       % placeholder (per-trial in Phase 3)
    'rfMapCheckContrastIdx',     '1'; ...                                       % placeholder
    'rfMapCheckReversalHz_x10',  'round(p.trVarsInit.checkReversalHz * 10)'; ...
    }];

%% finalize gui-comm mirror
p.trVarsGuiComm = p.trVarsInit;

end
