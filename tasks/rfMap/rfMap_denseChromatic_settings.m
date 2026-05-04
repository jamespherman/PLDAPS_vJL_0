function p = rfMap_denseChromatic_settings
%   p = rfMap_denseChromatic_settings
%
% Settings file for rfMap dense chromatic (DKL) noise mode.
%
% PHASE 1 STATUS: STUB. The dispatcher recognizes this stim type, but
% the generator and STA estimator are not implemented yet. Phase 2 of
% rfMap_unified_merge_plan.md adds:
%   - dkl2rgb-based RGB texture generation
%   - per-check DKL drive vector accumulator (3-vector per check)
%   - 3-panel L-M / S / Achromatic spatial map plot
%   - DKL calibration audit gate (Phase 1.5)
%
% Loading this settings file in Phase 1 will succeed up to the point
% where _init.m attempts to dispatch the chromatic generator; that call
% errors with a clear "Phase 2 not yet implemented" message.

%% pin stim type FIRST
p = struct;
p.init.stimType = 'denseChromatic';

%% common configuration
p = rfMap_commonSettings(p);

%% Phase-2 placeholder fields (off by default; documented for the
%% data dictionary).
p.trVarsInit.dklAxes      = [1 2 3];     % 1=L-M, 2=S, 3=Achromatic
p.trVarsInit.dklContrasts = [0.5];       % per-axis contrast
p.trVarsInit.dklHueDeg    = 0;           % azimuthal hue (deg)
p.init.dklCalibrationSource = 'unset';   % 'measured_primaries+...' | 'vendor_primaries+...'

%% strobe additions specific to chromatic mode (Phase 2 will populate
%% these from per-trial state; left here so the schema is reserved).
p.init.strobeList = [p.init.strobeList; { ...
    'rfMapDklAxisIdx',      '1'; ...                                % placeholder
    'rfMapDklContrast_x100','round(p.trVarsInit.dklContrasts(1) * 100)'; ...
    'rfMapDklHue_x10',      'round(p.trVarsInit.dklHueDeg * 10)'; ...
    'rfMapDklCalibSource',  '2'; ...                                % 2 = vendor (Phase-1 default)
    }];

%% finalize gui-comm mirror
p.trVarsGuiComm = p.trVarsInit;

end
