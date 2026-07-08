function p = rfMap_checkerboard_settings
%   p = rfMap_checkerboard_settings
%
% Settings file for rfMap contrast-reversing checkerboard mode.
%
% This is a CELL-CHARACTERIZATION mode -- it does NOT produce an online
% spatial RF (the spatial pattern is fixed; only polarity reverses).
% Online output:
%   (a) per-(channel, checkSize, contrast) temporal kernel via
%       reverse-correlation against the +/-1 polarity sequence.
%   (b) per-(channel, checkSize, contrast) F1/F2 amplitudes from
%       per-trial complex sums of cos/sin at f_rev and 2*f_rev.
% Useful for magno/parvo typing (modulation index F1/(F1+F2)) and
% rough contrast-response curves.
%
% Note: "check size" is a spatial-scale knob, NOT a clean spatial-
% frequency manipulation -- checkerboards are SF-broadband. If clean
% SF tuning is required, use a separate drifting-grating task.
%
% Loads via the PLDAPS GUI: Browse  ->  this file  ->  Initialize  ->  Run.

%% pin stim type FIRST
p = struct;
p.init.stimType = 'checkerboard';

%% common configuration
p = rfMap_commonSettings(p);

%% checkerboard-specific overrides
% Spatial scales (NOT SF -- broadband).
p.trVarsInit.checkSizesDva   = [0.5 1.0 2.0];

% Michelson contrasts in (0, 1]. Each contrast reserves 2 CLUT slots
% (low/high gray pair, gamma-corrected via dkl2rgb at install time).
%p.trVarsInit.checkContrasts  = [0.25 0.5 1.0];
p.trVarsInit.checkContrasts  = [0.25 0.5 1.0];

% Polarity reversal frequency. MUST divide refresh rate evenly AND
% checkReversalHz is the polarity FLIP rate; contrast fundamental F1 =
% checkReversalHz/2, F2 = checkReversalHz. Guard 2*checkReversalHz < Nyquist (conservative).
% (refreshRate / 2). prepareStim_checkerboard validates this and
% prints the legal set if you pick a bad value. Default 5 Hz works at
% 100 Hz (20 fpr, F2=10 Hz<50) and 120 Hz (24 fpr, F2=10 Hz<60).
p.trVarsInit.checkReversalHz = 5;

% Trials per (checkSize, contrast) cell. Plan target is ~80 for stable
% F1/F2; calibrate against bootstrap CIs on first real session.
% Trial count = nCheckSize * nContrast * checkRepsPerCondition.
p.trVarsInit.checkRepsPerCondition = 12;

% Hard cap on pre-rendered texture memory (bytes). Default 512 MB.
p.trVarsInit.checkGpuMemCapBytes = 512 * 1024 * 1024;

% Override common defaults that don't apply or want different values:
% - checkerboard doesn't use noiseFrameHold (it operates at display
%   frame resolution); we pin it to 1 so the dispatcher's per-frame
%   index math doesn't surprise. rfMap_init skips the
%   noiseTargetUpdateHz -> noiseFrameHold derivation for checkerboard.
% - longer trial duration (~4 s) so each trial sees several reversals.
p.trVarsInit.noiseFrameHold = 1;
p.trVarsInit.trialDurationS = 2;

% Number of temporal lags: cover ~one reversal period of lookback so
% the kernel shows the full impulse response. At 5 Hz reversal +
% 100 Hz refresh that's 20 frames; at 120 Hz it's 24. Use 24 to cover
% both common refresh rates.
p.trVarsInit.nSTALags = 24;

%% Pre-compute integer strobe values for per-condition strobing.
% Reversal Hz is constant across the session.
p.init.checkReversalHzStrobe = round(p.trVarsInit.checkReversalHz * 10);

%% strobe additions specific to checkerboard mode
% checkSizeIdx and contrastIdx are per-trial. Their expressions read
% the active condition out of the trial array via the trVars fields
% set by nextParams (p.trVars.checkSizeIdx, p.trVars.contrastIdx).
% reversalHz is fixed across the session.
p.init.strobeList = [p.init.strobeList; { ...
    'rfMapCheckSizeIdx',        'p.trVars.checkSizeIdx'; ...
    'rfMapCheckContrastIdx',    'p.trVars.contrastIdx'; ...
    'rfMapCheckReversalHz_x10', 'p.init.checkReversalHzStrobe'; ...
    }];

%% finalize gui-comm mirror
p.trVarsGuiComm = p.trVarsInit;

end
