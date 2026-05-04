function p = rfMap_denseAchromatic_settings
%   p = rfMap_denseAchromatic_settings
%
% Settings file for rfMap dense achromatic noise mode. Spatiotemporally
% white binary luminance noise across the full screen. The primary
% RF-mapping mode for cells with small RFs and weak surround drive
% (LGN, V1).
%
% Loads via the PLDAPS GUI: Browse  ->  this file  ->  Initialize  ->  Run.

%% pin stim type FIRST
p = struct;
p.init.stimType = 'denseAchromatic';

%% common configuration
p = rfMap_commonSettings(p);

%% stim-type-specific overrides
% Dense-achromatic uses the common defaults already set in
% rfMap_commonSettings: checkSizeDeg, noiseFrameHold, contrastBinary,
% movieDurationMin, etc. Nothing to override here in Phase 1.

%% finalize gui-comm mirror
p.trVarsGuiComm = p.trVarsInit;

end
